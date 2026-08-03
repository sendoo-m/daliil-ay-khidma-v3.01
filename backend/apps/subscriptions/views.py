from datetime import timedelta

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone
from django.utils.translation import get_language
from django.views.decorators.http import require_POST

from apps.directory.models import Business
from .models import Subscription, SubscriptionPlan


def _user_business(user):
    """Return one deterministic business instead of raising MultipleObjectsReturned."""
    return Business.objects.filter(owner=user).order_by('id').first()


def _message(ar, en):
    return ar if (get_language() or '').startswith('ar') else en


def plans_list(request):
    plans = SubscriptionPlan.objects.filter(is_active=True).order_by('order', 'price_monthly')
    return render(request, 'subscriptions/plans_list.html', {'plans': plans})


def plan_detail(request, plan_name):
    plan = get_object_or_404(SubscriptionPlan, name=plan_name, is_active=True)
    other_plans = SubscriptionPlan.objects.filter(is_active=True).exclude(name=plan_name).order_by('order')
    return render(request, 'subscriptions/plan_detail.html', {'plan': plan, 'other_plans': other_plans})


def pricing_comparison(request):
    plans = SubscriptionPlan.objects.filter(is_active=True).order_by('order', 'price_monthly')
    return render(request, 'subscriptions/pricing_comparison.html', {'plans': plans})


@login_required
def my_subscription(request):
    business = _user_business(request.user)
    subscription = None
    if business:
        subscription = Subscription.objects.select_related('plan').filter(business=business).first()
    plans = SubscriptionPlan.objects.filter(is_active=True).order_by('order')
    return render(request, 'subscriptions/my_subscription.html', {
        'business': business,
        'subscription': subscription,
        'plans': plans,
    })


@login_required
def subscribe(request, plan_name):
    business = _user_business(request.user)
    if not business:
        messages.error(request, _message('يجب إنشاء نشاط تجاري أولاً قبل الاشتراك.', 'Create a business before subscribing.'))
        return redirect('dashboard:dashboard')

    plan = get_object_or_404(SubscriptionPlan, name=plan_name, is_active=True)
    existing_sub = Subscription.objects.filter(business=business).first()

    if request.method == 'POST':
        duration = request.POST.get('duration', 'monthly')
        duration_days = {'monthly': 30, 'quarterly': 90, 'semi_annual': 180, 'annual': 365}
        start_date = timezone.now()
        end_date = start_date + timedelta(days=duration_days.get(duration, 30))
        amount = plan.get_price(duration)

        if existing_sub:
            subscription = existing_sub
            subscription.plan = plan
            subscription.start_date = start_date
            subscription.end_date = end_date
            subscription.amount_paid = amount
            subscription.status = 'pending'
            subscription.save()
        else:
            subscription = Subscription.objects.create(
                business=business,
                plan=plan,
                start_date=start_date,
                end_date=end_date,
                amount_paid=amount,
                status='pending',
            )

        messages.success(request, _message(
            f'تم إنشاء طلب الاشتراك في {plan.display_name_ar}. يرجى إتمام الدفع.',
            f'Your request for {plan.display_name_en} was created. Please complete payment.',
        ))
        return redirect('subscriptions:payment', subscription_id=subscription.id)

    return render(request, 'subscriptions/subscribe.html', {
        'plan': plan,
        'business': business,
        'existing_sub': existing_sub,
    })


@login_required
def payment(request, subscription_id):
    subscription = get_object_or_404(
        Subscription.objects.select_related('plan', 'business'),
        id=subscription_id,
        business__owner=request.user,
    )

    if request.method == 'POST':
        payment_method = request.POST.get('payment_method')
        transaction_id = request.POST.get('transaction_id', '')
        if subscription.amount_paid == 0:
            subscription.status = 'active'
            subscription.payment_method = 'free'
            subscription.save()
            messages.success(request, _message('تم تفعيل اشتراكك بنجاح.', 'Your subscription was activated successfully.'))
        else:
            subscription.payment_method = payment_method
            subscription.transaction_id = transaction_id
            subscription.save()
            messages.info(request, _message(
                'تم إرسال بيانات الدفع وسيتم التفعيل بعد المراجعة.',
                'Payment details were submitted and activation will follow review.',
            ))
        return redirect('subscriptions:my_subscription')

    return render(request, 'subscriptions/payment.html', {'subscription': subscription})


@login_required
@require_POST
def cancel_subscription(request):
    business = _user_business(request.user)
    subscription = Subscription.objects.filter(business=business).first() if business else None
    if subscription:
        subscription.cancel()
        messages.success(request, _message('تم إلغاء الاشتراك بنجاح.', 'Subscription cancelled successfully.'))
    else:
        messages.error(request, _message('لم يتم العثور على اشتراك.', 'No subscription was found.'))
    return redirect('subscriptions:my_subscription')


@login_required
@require_POST
def toggle_auto_renew(request):
    business = _user_business(request.user)
    subscription = Subscription.objects.filter(business=business).first() if business else None
    if subscription:
        subscription.auto_renew = not subscription.auto_renew
        subscription.save(update_fields=['auto_renew', 'updated_at'])
        messages.success(request, _message(
            'تم تحديث التجديد التلقائي.',
            'Automatic renewal was updated.',
        ))
        if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
            return JsonResponse({'success': True, 'auto_renew': subscription.auto_renew})
    else:
        messages.error(request, _message('لم يتم العثور على اشتراك.', 'No subscription was found.'))
    return redirect('subscriptions:my_subscription')


@login_required
def upgrade_subscription(request, plan_name):
    business = _user_business(request.user)
    current_sub = Subscription.objects.filter(business=business).select_related('plan').first() if business else None
    if not current_sub:
        messages.error(request, _message('يجب أن يكون لديك اشتراك حالي.', 'You need a current subscription.'))
        return redirect('subscriptions:plans_list')

    new_plan = get_object_or_404(SubscriptionPlan, name=plan_name, is_active=True)
    if new_plan.price_monthly <= current_sub.plan.price_monthly:
        messages.warning(request, _message('يرجى اختيار خطة أعلى.', 'Please choose a higher plan.'))
        return redirect('subscriptions:plans_list')

    if request.method == 'POST':
        current_sub.plan = new_plan
        current_sub.save(update_fields=['plan', 'updated_at'])
        messages.success(request, _message(
            f'تمت الترقية إلى {new_plan.display_name_ar}.',
            f'Your subscription was upgraded to {new_plan.display_name_en}.',
        ))
        return redirect('subscriptions:my_subscription')

    return render(request, 'subscriptions/upgrade.html', {'current_sub': current_sub, 'new_plan': new_plan})


def get_plan_price(request, plan_name, duration):
    try:
        plan = SubscriptionPlan.objects.get(name=plan_name)
    except SubscriptionPlan.DoesNotExist:
        return JsonResponse({'success': False}, status=404)
    return JsonResponse({
        'success': True,
        'price': float(plan.get_price(duration)),
        'plan_name': plan.display_name,
    })
