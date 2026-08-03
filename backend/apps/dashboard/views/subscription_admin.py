from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.core.paginator import Paginator
from django.db.models import Count, Q, Sum
from django.shortcuts import get_object_or_404, redirect, render
from django.utils.translation import get_language
from django.views.decorators.http import require_POST

from apps.subscriptions.forms import SubscriptionPlanForm
from apps.subscriptions.models import Subscription, SubscriptionPlan


def _message(ar, en):
    return ar if (get_language() or '').startswith('ar') else en


@staff_member_required
def subscription_dashboard(request):
    subscriptions = Subscription.objects.select_related('business', 'plan')
    # Subscription.plan defines related_query_name='subscription'. Using
    # 'subscriptions' here raises FieldError and caused the production 500.
    plans = SubscriptionPlan.objects.annotate(subscription_count=Count('subscription'))

    stats = {
        'total_subscriptions': subscriptions.count(),
        'active_subscriptions': subscriptions.filter(status='active').count(),
        'pending_subscriptions': subscriptions.filter(status='pending').count(),
        'expired_subscriptions': subscriptions.filter(status='expired').count(),
        'revenue': subscriptions.filter(status='active').aggregate(total=Sum('amount_paid'))['total'] or 0,
        'active_plans': plans.filter(is_active=True).count(),
    }

    return render(request, 'dashboard/admin/subscriptions/home.html', {
        'stats': stats,
        'recent_subscriptions': subscriptions.order_by('-created_at')[:8],
        'plans': plans.order_by('order', 'price_monthly'),
    })


@staff_member_required
def subscription_list(request):
    queryset = Subscription.objects.select_related('business', 'business__owner', 'plan').order_by('-created_at')
    search = request.GET.get('search', '').strip()
    status = request.GET.get('status', '').strip()
    plan = request.GET.get('plan', '').strip()

    if search:
        queryset = queryset.filter(
            Q(business__name_ar__icontains=search)
            | Q(business__name_en__icontains=search)
            | Q(business__owner__username__icontains=search)
            | Q(transaction_id__icontains=search)
        )
    if status:
        queryset = queryset.filter(status=status)
    if plan:
        queryset = queryset.filter(plan__name=plan)

    page = Paginator(queryset, 25).get_page(request.GET.get('page'))
    return render(request, 'dashboard/admin/subscriptions/list.html', {
        'subscriptions': page,
        'plans': SubscriptionPlan.objects.filter(is_active=True).order_by('order'),
        'search': search,
        'status': status,
        'selected_plan': plan,
        'status_choices': Subscription.STATUS_CHOICES,
    })


@staff_member_required
def subscription_detail(request, subscription_id):
    subscription = get_object_or_404(
        Subscription.objects.select_related('business', 'business__owner', 'plan'),
        id=subscription_id,
    )
    return render(request, 'dashboard/admin/subscriptions/detail.html', {'subscription': subscription})


@staff_member_required
@require_POST
def subscription_activate(request, subscription_id):
    subscription = get_object_or_404(Subscription, id=subscription_id)
    subscription.activate()
    messages.success(request, _message('تم تفعيل الاشتراك بنجاح.', 'Subscription activated successfully.'))
    return redirect('dashboard:admin_subscription_detail', subscription_id=subscription.id)


@staff_member_required
@require_POST
def subscription_cancel(request, subscription_id):
    subscription = get_object_or_404(Subscription, id=subscription_id)
    subscription.cancel()
    messages.success(request, _message('تم إلغاء الاشتراك بنجاح.', 'Subscription cancelled successfully.'))
    return redirect('dashboard:admin_subscription_detail', subscription_id=subscription.id)


@staff_member_required
def subscription_plan_list(request):
    plans = SubscriptionPlan.objects.annotate(
        subscription_count=Count('subscription')
    ).order_by('order', 'price_monthly')
    return render(request, 'dashboard/admin/subscriptions/plans.html', {'plans': plans})


@staff_member_required
def subscription_plan_edit(request, plan_id):
    plan = get_object_or_404(SubscriptionPlan, id=plan_id)

    if request.method == 'POST':
        form = SubscriptionPlanForm(request.POST, instance=plan)
        if form.is_valid():
            form.save()
            messages.success(
                request,
                _message('تم تحديث خطة الاشتراك بنجاح.', 'Subscription plan updated successfully.'),
            )
            return redirect('dashboard:admin_subscription_plans')
        messages.error(
            request,
            _message('يرجى تصحيح الأخطاء الموضحة أدناه.', 'Please correct the errors shown below.'),
        )
    else:
        form = SubscriptionPlanForm(instance=plan)

    return render(request, 'dashboard/admin/subscriptions/plan_edit.html', {
        'form': form,
        'plan': plan,
    })
