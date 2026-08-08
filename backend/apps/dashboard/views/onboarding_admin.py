"""
Dashboard — Admin Onboarding Center
===================================
متابعة التجار الجدد من اختيار الخطة حتى تفعيل الاشتراك.

الفكرة: **الطابور لا الجدول.** الإدارة لا تحتاج قائمة بكل من سجّل، بل
من ينتظرها هي الآن. المعطّل عن التقدم بسبب الإدارة (دفع مرسل بلا تأكيد)
يظهر أولًا، ومن يتأخر بسببه هو يظهر بعده.
"""

from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone

from apps.subscriptions.models import MerchantOnboarding
from apps.subscriptions.onboarding import build_onboarding_state

#: الطوابير كما تراها الإدارة. كل واحد سؤال مختلف.
QUEUES = {
    'needs_us': {
        'label': 'محتاج تدخّلنا',
        'hint': 'دفع مرسل بانتظار تأكيد، أو نشاط بانتظار مراجعة',
        'tone': 'danger',
    },
    'needs_them': {
        'label': 'محتاج التاجر',
        'hint': 'اختار خطة بس لسه مكمّلش',
        'tone': 'warning',
    },
    'active': {
        'label': 'مفعّل',
        'hint': 'اشتراك شغّال والنشاط ظاهر',
        'tone': 'success',
    },
    'all': {'label': 'الكل', 'hint': '', 'tone': 'secondary'},
}

_NEEDS_US = Q(payment_status='submitted') | Q(status='admin_review')
_ACTIVE = Q(status__in=['subscription_active', 'completed'])


def _queryset(queue: str):
    base = MerchantOnboarding.objects.select_related(
        'user', 'business', 'selected_plan'
    )
    if queue == 'needs_us':
        return base.filter(_NEEDS_US).exclude(_ACTIVE)
    if queue == 'needs_them':
        return base.exclude(_NEEDS_US).exclude(_ACTIVE)
    if queue == 'active':
        return base.filter(_ACTIVE)
    return base


def admin_onboarding_list(request):
    queue = request.GET.get('queue', 'needs_us')
    if queue not in QUEUES:
        queue = 'needs_us'

    rows = _queryset(queue)

    search = (request.GET.get('q') or '').strip()
    if search:
        rows = rows.filter(
            Q(user__username__icontains=search)
            | Q(user__phone__icontains=search)
            | Q(business__name_ar__icontains=search)
            | Q(payment_reference__icontains=search)
        )

    # الأقدم أولًا في طابور العمل: من ينتظر منذ ثلاثة أيام قبل من أرسل
    # منذ ساعة. الترتيب بالأحدث يجعل المنتظر الأقدم يغرق للأسفل ويُنسى.
    rows = rows.order_by(
        'updated_at' if queue == 'needs_us' else '-updated_at'
    )

    page = Paginator(rows, 25).get_page(request.GET.get('page'))

    return render(
        request,
        'dashboard/admin/onboarding/list.html',
        {
            'page_obj': page,
            'queue': queue,
            'queues': QUEUES,
            'search': search,
            'counts': {
                key: _queryset(key).count()
                for key in ('needs_us', 'needs_them', 'active')
            },
        },
    )


def admin_onboarding_detail(request, pk):
    onboarding = get_object_or_404(
        MerchantOnboarding.objects.select_related(
            'user', 'business', 'selected_plan'
        ),
        pk=pk,
    )

    state = None
    try:
        state = build_onboarding_state(onboarding)
    except Exception:  # noqa: BLE001
        import logging

        logging.getLogger('dashboard.onboarding').exception(
            'تعذّر بناء حالة التجهيز للسجل %s', pk
        )

    return render(
        request,
        'dashboard/admin/onboarding/detail.html',
        {'onboarding': onboarding, 'state': state},
    )


def admin_onboarding_confirm_payment(request, pk):
    """
    يؤكد الدفع ويفعّل الاشتراك.

    خطوة واحدة لا اثنتان: تأكيد الدفع بلا تفعيل يترك التاجر في نفس
    المكان بالضبط — دفع، وانتظار، ولا شيء تغيّر عنده. الموظف الذي
    أكّد الدفع قصد أن يمضي التاجر قدمًا.
    """
    if request.method != 'POST':
        return redirect('dashboard:admin_onboarding_detail', pk=pk)

    onboarding = get_object_or_404(MerchantOnboarding, pk=pk)

    if onboarding.payment_status == 'confirmed':
        messages.info(request, 'الدفع مؤكد بالفعل.')
        return redirect('dashboard:admin_onboarding_detail', pk=pk)

    onboarding.payment_status = 'confirmed'
    onboarding.admin_notes = (
        f'{onboarding.admin_notes}\n'
        f'أكّد الدفع: {request.user} — {timezone.now():%Y-%m-%d %H:%M}'
    ).strip()
    onboarding.save(update_fields=['payment_status', 'admin_notes', 'updated_at'])

    activated = _activate_subscription(onboarding, request.user)

    from apps.administration import services
    from apps.administration.models import AuditLog

    services.record(
        actor=request.user,
        action=AuditLog.Action.APPROVE,
        target=onboarding,
        target_label=f'تأكيد دفع — {onboarding.user}',
        changes={'payment_status': {'to': 'confirmed'},
                 'subscription_activated': activated},
        request=request,
    )

    messages.success(
        request,
        'اتأكد الدفع واتفعّل الاشتراك.'
        if activated
        else 'اتأكد الدفع. الاشتراك محتاج تفعيل يدوي.',
    )
    return redirect('dashboard:admin_onboarding_detail', pk=pk)


def admin_onboarding_reject_payment(request, pk):
    if request.method != 'POST':
        return redirect('dashboard:admin_onboarding_detail', pk=pk)

    reason = (request.POST.get('reason') or '').strip()
    if not reason:
        messages.error(request, 'سبب الرفض مطلوب — التاجر لازم يعرف يصلّح إيه.')
        return redirect('dashboard:admin_onboarding_detail', pk=pk)

    onboarding = get_object_or_404(MerchantOnboarding, pk=pk)
    onboarding.payment_status = 'rejected'
    onboarding.admin_notes = (
        f'{onboarding.admin_notes}\n'
        f'رُفض الدفع: {request.user} — {timezone.now():%Y-%m-%d %H:%M}\n'
        f'السبب: {reason}'
    ).strip()
    onboarding.save(update_fields=['payment_status', 'admin_notes', 'updated_at'])

    from apps.administration import services
    from apps.administration.models import AuditLog

    services.record(
        actor=request.user,
        action=AuditLog.Action.REJECT,
        target=onboarding,
        target_label=f'رفض دفع — {onboarding.user}',
        changes={'payment_status': {'to': 'rejected'}},
        reason=reason,
        request=request,
    )

    messages.warning(request, 'اترفض الدفع واتسجّل السبب.')
    return redirect('dashboard:admin_onboarding_detail', pk=pk)


def _activate_subscription(onboarding, actor) -> bool:
    """
    يفعّل اشتراك التاجر بعد تأكيد الدفع.

    يُرجع False بدل أن يرمي: فشل التفعيل لا يجوز أن يُلغي تأكيد الدفع
    الذي حدث فعلًا. الموظف يرى رسالة تطلب تفعيلًا يدويًا.
    """
    try:
        from apps.subscriptions.services import activate_subscription_for

        activate_subscription_for(onboarding)
        return True
    except ImportError:
        pass
    except Exception:  # noqa: BLE001
        import logging

        logging.getLogger('dashboard.onboarding').exception(
            'تعذّر تفعيل الاشتراك للسجل %s', onboarding.pk
        )
        return False

    # لا دالة جاهزة: ننشئ الاشتراك مباشرة من الخطة المختارة.
    try:
        from datetime import timedelta

        from apps.subscriptions.models import Subscription

        plan = onboarding.selected_plan
        if plan is None or onboarding.business_id is None:
            return False

        days = 365 if onboarding.billing_period == 'yearly' else 30
        if onboarding.billing_period == 'quarterly':
            days = 90

        Subscription.objects.get_or_create(
            business_id=onboarding.business_id,
            status='active',
            defaults={
                'plan': plan,
                'start_date': timezone.now(),
                'end_date': timezone.now() + timedelta(days=days),
            },
        )
        return True
    except Exception:  # noqa: BLE001
        import logging

        logging.getLogger('dashboard.onboarding').exception(
            'تعذّر إنشاء الاشتراك للسجل %s', onboarding.pk
        )
        return False
