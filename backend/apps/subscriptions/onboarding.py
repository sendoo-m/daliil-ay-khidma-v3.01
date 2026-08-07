"""Merchant onboarding journey and progress engine."""

from decimal import Decimal

from django.utils import timezone

from apps.subscriptions.models import MerchantOnboarding, Subscription


CHECKLIST_DEFINITIONS = (
    ('account_created', 5, 'Account created', 'تم إنشاء الحساب'),
    ('plan_selected', 10, 'Plan selected', 'تم اختيار الخطة'),
    ('business_created', 20, 'Business created', 'تم إنشاء النشاط'),
    ('payment_submitted', 10, 'Payment submitted', 'تم إرسال بيانات الدفع'),
    ('subscription_active', 15, 'Subscription active', 'الاشتراك مفعل'),
    ('logo_added', 5, 'Business logo', 'شعار النشاط'),
    ('cover_added', 5, 'Cover image', 'صورة الغلاف'),
    ('location_added', 5, 'Business location', 'موقع النشاط'),
    ('working_hours_added', 5, 'Working hours', 'ساعات العمل'),
    ('contact_added', 5, 'Contact details', 'بيانات التواصل'),
    ('first_product', 10, 'First product or service', 'أول منتج أو خدمة'),
    ('first_deal', 5, 'First deal', 'أول عرض'),
)


def get_or_create_onboarding(user):
    onboarding, created = MerchantOnboarding.objects.select_related(
        'selected_plan', 'business'
    ).get_or_create(user=user)
    if created:
        active = (
            Subscription.objects.select_related('plan', 'business')
            .filter(
                business__owner=user,
                status='active',
                end_date__gt=timezone.now(),
            )
            .order_by('-end_date')
            .first()
        )
        if active:
            onboarding.selected_plan = active.plan
            onboarding.business = active.business
            onboarding.payment_status = 'confirmed'
            onboarding.payment_method = active.payment_method
            onboarding.payment_reference = active.transaction_id
            onboarding.status = 'subscription_active'
            onboarding.save()
    return onboarding


def _active_subscription(onboarding):
    if not onboarding.business_id:
        return None
    return (
        Subscription.objects.select_related('plan')
        .filter(
            business_id=onboarding.business_id,
            status='active',
            end_date__gt=timezone.now(),
        )
        .first()
    )


def _contact_complete(business):
    if not business:
        return False
    return bool(business.phone or business.whatsapp or business.email or business.website)


def _location_complete(business):
    if not business:
        return False
    return bool(
        business.location_url
        or (business.latitude is not None and business.longitude is not None)
    )


def _checklist_state(onboarding):
    business = onboarding.business
    plan = onboarding.selected_plan
    subscription = _active_subscription(onboarding)
    payment_required = onboarding.payment_required
    deal_applicable = bool(plan and plan.can_create_deals)

    completed = {
        'account_created': True,
        'plan_selected': bool(plan),
        'business_created': bool(business),
        'payment_submitted': (
            not payment_required
            or onboarding.payment_status in {'submitted', 'confirmed'}
        ),
        'subscription_active': bool(subscription),
        'logo_added': bool(business and business.logo),
        'cover_added': bool(business and business.cover_image),
        'location_added': _location_complete(business),
        'working_hours_added': bool(
            business and (business.working_hours_ar or business.working_hours_en)
        ),
        'contact_added': _contact_complete(business),
        'first_product': bool(business and business.products.exists()),
        'first_deal': bool(business and business.deals.exists()),
    }
    applicable = {key: True for key, _, _, _ in CHECKLIST_DEFINITIONS}
    applicable['payment_submitted'] = payment_required
    applicable['first_deal'] = deal_applicable

    rows = []
    for key, weight, label_en, label_ar in CHECKLIST_DEFINITIONS:
        is_applicable = applicable[key]
        rows.append(
            {
                'key': key,
                'label_en': label_en,
                'label_ar': label_ar,
                'weight': weight,
                'applicable': is_applicable,
                'completed': completed[key] if is_applicable else True,
                'state': (
                    'done'
                    if is_applicable and completed[key]
                    else 'pending'
                    if is_applicable
                    else 'not_applicable'
                ),
            }
        )
    return rows, subscription


def _progress_percent(checklist):
    applicable = [item for item in checklist if item['applicable']]
    total = sum(item['weight'] for item in applicable)
    if total <= 0:
        return 0
    done = sum(item['weight'] for item in applicable if item['completed'])
    return round((done / total) * 100)


def _next_action(onboarding, checklist, active_subscription):
    by_key = {item['key']: item for item in checklist}
    if not onboarding.selected_plan_id:
        return 'select_plan'
    if not onboarding.business_id:
        return 'create_business'
    if onboarding.payment_required and onboarding.payment_status not in {'submitted', 'confirmed'}:
        return 'submit_payment'
    if not active_subscription:
        return 'await_admin_review'

    action_map = (
        ('logo_added', 'add_logo'),
        ('cover_added', 'add_cover'),
        ('location_added', 'add_location'),
        ('working_hours_added', 'add_working_hours'),
        ('contact_added', 'add_contact'),
        ('first_product', 'add_product'),
        ('first_deal', 'add_deal'),
    )
    for key, action in action_map:
        item = by_key[key]
        if item['applicable'] and not item['completed']:
            return action
    return 'complete'


def _derived_status(onboarding, progress, active_subscription):
    if progress == 100 and active_subscription:
        return 'completed'
    if active_subscription:
        return 'subscription_active'
    if onboarding.payment_required and onboarding.payment_status in {'submitted', 'confirmed'}:
        return 'admin_review'
    if onboarding.business_id:
        if onboarding.payment_required:
            return 'payment_pending'
        return 'admin_review'
    if onboarding.selected_plan_id:
        return 'plan_selected'
    return 'draft'


def sync_onboarding_status(onboarding, progress, active_subscription):
    status = _derived_status(onboarding, progress, active_subscription)
    changed_fields = []
    if onboarding.status != status:
        onboarding.status = status
        changed_fields.append('status')
    if status == 'completed' and onboarding.completed_at is None:
        onboarding.completed_at = timezone.now()
        changed_fields.append('completed_at')
    elif status != 'completed' and onboarding.completed_at is not None:
        onboarding.completed_at = None
        changed_fields.append('completed_at')
    if changed_fields:
        changed_fields.append('updated_at')
        onboarding.save(update_fields=changed_fields)
    return status


def build_onboarding_state(onboarding):
    checklist, active_subscription = _checklist_state(onboarding)
    progress = _progress_percent(checklist)
    status = sync_onboarding_status(onboarding, progress, active_subscription)
    next_action = _next_action(onboarding, checklist, active_subscription)
    plan = onboarding.selected_plan
    business = onboarding.business

    return {
        'id': onboarding.id,
        'status': status,
        'progress': progress,
        'current_step': next_action,
        'next_action': next_action,
        'payment_required': onboarding.payment_required,
        'payment_status': onboarding.payment_status,
        'payment_method': onboarding.payment_method,
        'payment_reference': onboarding.payment_reference,
        'payment_receipt': (
            onboarding.payment_receipt.url if onboarding.payment_receipt else None
        ),
        'billing_period': onboarding.billing_period,
        'selected_price': float(onboarding.selected_price or Decimal('0')),
        'selected_plan': (
            {
                'id': plan.id,
                'name': plan.name,
                'display_name_ar': plan.display_name_ar,
                'display_name_en': plan.display_name_en,
                'can_create_deals': plan.can_create_deals,
                'max_businesses': plan.max_businesses,
                'max_products': plan.max_products,
            }
            if plan
            else None
        ),
        'business': (
            {
                'id': business.id,
                'slug': business.slug,
                'name_ar': business.name_ar,
                'name_en': business.name_en,
                'is_active': business.is_active,
                'is_verified': business.is_verified,
            }
            if business
            else None
        ),
        'subscription': (
            {
                'id': active_subscription.id,
                'status': active_subscription.status,
                'plan_id': active_subscription.plan_id,
                'end_date': active_subscription.end_date,
            }
            if active_subscription
            else None
        ),
        'checklist': checklist,
        'updated_at': onboarding.updated_at,
    }
