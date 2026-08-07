from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.core.paginator import Paginator
from django.db.models import Count, Q, Sum
from django.shortcuts import get_object_or_404, redirect, render
from django.utils.translation import get_language
from django.views.decorators.http import require_POST

from apps.administration.constants import Perm
from apps.directory.models import Business
from apps.products.models import Product
from apps.subscriptions.forms import SubscriptionPlanForm
from apps.subscriptions.models import (
    Subscription,
    SubscriptionChangeRequest,
    SubscriptionPlan,
)
from apps.subscriptions.services import apply_change_request, reject_change_request


def _message(ar, en):
    return ar if (get_language() or '').startswith('ar') else en


def _can_manage_subscriptions(user):
    if user.is_superuser:
        return True
    admin_can = getattr(user, 'admin_can', None)
    return bool(admin_can and admin_can(Perm.SUBSCRIPTION_MANAGE))


@staff_member_required
def subscription_dashboard(request):
    subscriptions = Subscription.objects.select_related('business', 'plan')
    plans = SubscriptionPlan.objects.annotate(subscription_count=Count('subscription'))
    change_requests = SubscriptionChangeRequest.objects.all()

    stats = {
        'total_subscriptions': subscriptions.count(),
        'active_subscriptions': subscriptions.filter(status='active').count(),
        'pending_subscriptions': subscriptions.filter(status='pending').count(),
        'expired_subscriptions': subscriptions.filter(status='expired').count(),
        'revenue': subscriptions.filter(status='active').aggregate(total=Sum('amount_paid'))['total'] or 0,
        'active_plans': plans.filter(is_active=True).count(),
        'pending_change_requests': change_requests.filter(status='pending').count(),
    }

    return render(request, 'dashboard/admin/subscriptions/home.html', {
        'stats': stats,
        'recent_subscriptions': subscriptions.order_by('-created_at')[:8],
        'plans': plans.order_by('order', 'price_monthly'),
        'recent_change_requests': change_requests.select_related(
            'owner', 'current_plan', 'target_plan', 'subscription__business'
        ).order_by('-created_at')[:6],
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


@staff_member_required
def subscription_change_request_list(request):
    queryset = SubscriptionChangeRequest.objects.select_related(
        'owner',
        'subscription__business',
        'current_plan',
        'target_plan',
        'reviewed_by',
    ).order_by('-created_at')

    search = request.GET.get('search', '').strip()
    status = request.GET.get('status', '').strip()
    change_type = request.GET.get('change_type', '').strip()

    if search:
        queryset = queryset.filter(
            Q(owner__username__icontains=search)
            | Q(owner__email__icontains=search)
            | Q(subscription__business__name_ar__icontains=search)
            | Q(subscription__business__name_en__icontains=search)
            | Q(transaction_id__icontains=search)
        )
    if status:
        queryset = queryset.filter(status=status)
    if change_type:
        queryset = queryset.filter(change_type=change_type)

    page = Paginator(queryset, 25).get_page(request.GET.get('page'))
    all_requests = SubscriptionChangeRequest.objects.all()
    stats = {
        'pending': all_requests.filter(status='pending').count(),
        'applied': all_requests.filter(status='applied').count(),
        'rejected': all_requests.filter(status='rejected').count(),
        'total': all_requests.count(),
    }

    return render(request, 'dashboard/admin/subscriptions/change_requests.html', {
        'change_requests': page,
        'search': search,
        'status': status,
        'change_type': change_type,
        'status_choices': SubscriptionChangeRequest.STATUS_CHOICES,
        'change_choices': SubscriptionChangeRequest.CHANGE_CHOICES,
        'stats': stats,
        'can_manage': _can_manage_subscriptions(request.user),
    })


@staff_member_required
def subscription_change_request_detail(request, request_id):
    change_request = get_object_or_404(
        SubscriptionChangeRequest.objects.select_related(
            'owner',
            'subscription__business',
            'current_plan',
            'target_plan',
            'reviewed_by',
        ),
        id=request_id,
    )

    selected_businesses = Business.objects.filter(
        owner=change_request.owner,
        id__in=change_request.keep_business_ids,
    ).order_by('id')
    selected_products = Product.objects.filter(
        business__owner=change_request.owner,
        id__in=change_request.keep_product_ids,
    ).select_related('business').order_by('business_id', 'id')

    preview = change_request.preview if isinstance(change_request.preview, dict) else {}
    impact = preview.get('impact', {}) if isinstance(preview.get('impact', {}), dict) else {}
    disabled_features = impact.get('disabled_features', [])

    return render(request, 'dashboard/admin/subscriptions/change_request_detail.html', {
        'change_request': change_request,
        'selected_businesses': selected_businesses,
        'selected_products': selected_products,
        'impact': impact,
        'disabled_features': disabled_features,
        'applied_changes': change_request.applied_changes or {},
        'can_manage': _can_manage_subscriptions(request.user),
    })


@staff_member_required
@require_POST
def subscription_change_request_approve(request, request_id):
    change_request = get_object_or_404(
        SubscriptionChangeRequest.objects.select_related('target_plan'),
        id=request_id,
    )
    if change_request.status != 'pending':
        messages.warning(
            request,
            _message('هذا الطلب لم يعد بانتظار المراجعة.', 'This request is no longer pending.'),
        )
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)

    payment_confirmed = request.POST.get('payment_confirmed') == 'on'
    payment_method = request.POST.get('payment_method', '').strip()
    transaction_id = request.POST.get('transaction_id', '').strip()
    admin_notes = request.POST.get('admin_notes', '').strip()

    if change_request.requested_amount > 0 and not payment_confirmed:
        messages.error(
            request,
            _message(
                'يجب تأكيد استلام الدفع قبل تطبيق الخطة المدفوعة.',
                'Payment must be confirmed before applying a paid plan.',
            ),
        )
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)
    if payment_confirmed and not payment_method:
        messages.error(
            request,
            _message('اختر أو اكتب وسيلة الدفع.', 'Please provide the payment method.'),
        )
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)

    change_request.payment_confirmed = payment_confirmed
    change_request.payment_method = payment_method
    change_request.transaction_id = transaction_id
    change_request.admin_notes = admin_notes
    change_request.save(update_fields=[
        'payment_confirmed', 'payment_method', 'transaction_id', 'admin_notes', 'updated_at'
    ])

    try:
        apply_change_request(change_request, reviewer=request.user)
    except ValueError as exc:
        messages.error(request, str(exc))
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)

    messages.success(
        request,
        _message(
            'تمت الموافقة وتطبيق الخطة الجديدة وحدودها بنجاح.',
            'The new plan and its limits were approved and applied successfully.',
        ),
    )
    return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)


@staff_member_required
@require_POST
def subscription_change_request_reject(request, request_id):
    change_request = get_object_or_404(SubscriptionChangeRequest, id=request_id)
    reason = request.POST.get('reason', '').strip()
    if not reason:
        messages.error(
            request,
            _message('سبب الرفض مطلوب.', 'A rejection reason is required.'),
        )
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)

    try:
        reject_change_request(change_request, reviewer=request.user, reason=reason)
    except ValueError as exc:
        messages.error(request, str(exc))
        return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)

    messages.success(
        request,
        _message('تم رفض الطلب وإشعار صاحب النشاط.', 'The request was rejected and the merchant was notified.'),
    )
    return redirect('dashboard:admin_subscription_change_request_detail', request_id=request_id)
