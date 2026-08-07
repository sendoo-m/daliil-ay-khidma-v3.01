from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.notifications.models import Notification
from apps.products.models import Product

from .models import SubscriptionChangeRequest, SubscriptionPlan


_PERIOD_DAYS = {
    'monthly': 30,
    'quarterly': 90,
    'semi_annual': 180,
    'annual': 365,
}

_FEATURE_FIELDS = (
    'can_upload_images',
    'can_show_prices',
    'has_delivery_options',
    'has_analytics',
    'featured_in_search',
    'can_create_deals',
    'has_social_media_links',
    'has_verified_badge',
)

_LIMIT_FIELDS = (
    'max_businesses',
    'max_products',
    'max_images_per_product',
    'max_business_images',
)


def _limit_reduced(current_value: int, target_value: int) -> bool:
    """Return True when target is more restrictive. Zero means unlimited."""
    if current_value == target_value:
        return False
    if current_value == 0:
        return target_value > 0
    if target_value == 0:
        return False
    return target_value < current_value


def _limit_increased(current_value: int, target_value: int) -> bool:
    """Return True when target expands capacity. Zero means unlimited."""
    if current_value == target_value:
        return False
    if target_value == 0:
        return current_value > 0
    if current_value == 0:
        return False
    return target_value > current_value


def change_type(current: SubscriptionPlan, target: SubscriptionPlan) -> str:
    """Classify by capabilities/limits first, not by price or plan name.

    A plan is a downgrade if *any* hard capacity or feature is removed. This
    prevents a higher-priced but more restrictive plan from being treated as
    an upgrade. Only when nothing is reduced can additional capacity/features
    make the change an upgrade. Price is used only as a final tie-breaker.
    """
    has_reduction = any(
        _limit_reduced(getattr(current, field), getattr(target, field))
        for field in _LIMIT_FIELDS
    ) or any(
        getattr(current, field) and not getattr(target, field)
        for field in _FEATURE_FIELDS
    )
    if has_reduction:
        return 'downgrade'

    has_increase = any(
        _limit_increased(getattr(current, field), getattr(target, field))
        for field in _LIMIT_FIELDS
    ) or any(
        not getattr(current, field) and getattr(target, field)
        for field in _FEATURE_FIELDS
    )
    if has_increase:
        return 'upgrade'

    if target.price_monthly > current.price_monthly:
        return 'upgrade'
    if target.price_monthly < current.price_monthly:
        return 'downgrade'
    return 'same'


def build_change_preview(*, owner, subscription, target_plan, billing_period='monthly'):
    businesses = list(
        Business.objects.filter(owner=owner).order_by('-is_active', 'id')
    )
    active_businesses = [business for business in businesses if business.is_active]
    products = list(
        Product.objects.filter(business__owner=owner)
        .select_related('business')
        .order_by('-is_available', 'business_id', 'id')
    )
    active_products = [
        product
        for product in products
        if product.is_available and product.business.is_active
    ]

    current_plan = subscription.plan
    direction = change_type(current_plan, target_plan)
    max_businesses = target_plan.max_businesses
    max_products = target_plan.max_products

    # Limits are maxima, never quotas. Selection is only needed for a real
    # downgrade where current active data exceeds the new maximum.
    businesses_to_suspend = 0
    products_to_suspend = 0
    if direction == 'downgrade':
        if max_businesses > 0:
            businesses_to_suspend = max(0, len(active_businesses) - max_businesses)
        if max_products > 0:
            products_to_suspend = max(0, len(active_products) - max_products)

    disabled_features = []
    feature_map = {
        'can_upload_images': ('رفع الصور', 'Image uploads'),
        'can_show_prices': ('إظهار الأسعار', 'Price display'),
        'has_delivery_options': ('خيارات التوصيل', 'Delivery options'),
        'has_analytics': ('التحليلات', 'Analytics'),
        'featured_in_search': ('أولوية البحث', 'Search priority'),
        'can_create_deals': ('إنشاء العروض', 'Deals'),
        'has_social_media_links': ('روابط التواصل', 'Social links'),
        'has_verified_badge': ('شارة التوثيق', 'Verified badge'),
    }
    if direction == 'downgrade':
        for field, labels in feature_map.items():
            if getattr(current_plan, field) and not getattr(target_plan, field):
                disabled_features.append({'key': field, 'ar': labels[0], 'en': labels[1]})

    business_selection_required = (
        direction == 'downgrade'
        and max_businesses > 0
        and len(active_businesses) > max_businesses
    )
    product_selection_may_be_required = (
        direction == 'downgrade'
        and max_products > 0
        and len(active_products) > max_products
    )

    return {
        'change_type': direction,
        'current_plan_id': current_plan.id,
        'target_plan_id': target_plan.id,
        'billing_period': billing_period,
        'price': float(target_plan.get_price(billing_period)),
        'limits': {
            'max_businesses': max_businesses,
            'max_products': max_products,
            'max_images_per_product': target_plan.max_images_per_product,
            'max_business_images': target_plan.max_business_images,
        },
        'selection': {
            'business_selection_required': business_selection_required,
            'business_keep_count': (
                min(len(active_businesses), max_businesses)
                if max_businesses > 0
                else len(active_businesses)
            ),
            # Product selection is evaluated again after the owner chooses
            # businesses because available products depend on those choices.
            'product_selection_may_be_required': product_selection_may_be_required,
            'product_keep_limit': max_products,
        },
        'impact': {
            'active_businesses': len(active_businesses),
            'active_products': len(active_products),
            'businesses_to_suspend': businesses_to_suspend,
            'products_to_suspend': products_to_suspend,
            'disabled_features': disabled_features,
        },
        'businesses': [
            {
                'id': item.id,
                'name_ar': item.name_ar,
                'name_en': item.name_en,
                'is_active': item.is_active,
            }
            for item in businesses
        ],
        'products': [
            {
                'id': item.id,
                'business_id': item.business_id,
                'name_ar': item.name_ar,
                'name_en': item.name_en,
                'is_available': item.is_available,
            }
            for item in products
        ],
    }


def validate_keep_selection(*, owner, target_plan, keep_business_ids, keep_product_ids):
    """Validate ownership and upper bounds only.

    Plan limits are maximums, not required quotas. Selecting fewer items than
    the target maximum is valid; apply_change_request decides whether more
    selection is necessary based on the actually kept businesses.
    """
    business_ids = set(
        Business.objects.filter(owner=owner, id__in=keep_business_ids)
        .values_list('id', flat=True)
    )
    product_ids = set(
        Product.objects.filter(
            business__owner=owner,
            id__in=keep_product_ids,
        ).values_list('id', flat=True)
    )

    if len(business_ids) != len(set(keep_business_ids)):
        raise ValueError('One or more selected businesses do not belong to this account.')
    if len(product_ids) != len(set(keep_product_ids)):
        raise ValueError('One or more selected products do not belong to this account.')
    if target_plan.max_businesses > 0 and len(business_ids) > target_plan.max_businesses:
        raise ValueError('Selected businesses exceed the target plan limit.')
    if target_plan.max_products > 0 and len(product_ids) > target_plan.max_products:
        raise ValueError('Selected products exceed the target plan limit.')

    product_business_ids = set(
        Product.objects.filter(id__in=product_ids).values_list('business_id', flat=True)
    )
    if business_ids and not product_business_ids.issubset(business_ids):
        raise ValueError('Selected products must belong to businesses kept active.')

    return sorted(business_ids), sorted(product_ids)


def _restore_suspended_by_previous_changes(owner):
    """أعد فقط السجلات التي عطّلها محرك الاشتراك في طلبات سابقة."""
    business_ids = set()
    product_ids = set()
    deal_ids = set()
    for changes in SubscriptionChangeRequest.objects.filter(
        owner=owner,
        status='applied',
    ).values_list('applied_changes', flat=True):
        if not isinstance(changes, dict):
            continue
        business_ids.update(changes.get('suspended_business_ids', []))
        product_ids.update(changes.get('suspended_product_ids', []))
        deal_ids.update(changes.get('suspended_deal_ids', []))

    if business_ids:
        Business.objects.filter(owner=owner, id__in=business_ids).update(is_active=True)
    if product_ids:
        Product.objects.filter(
            business__owner=owner,
            id__in=product_ids,
        ).update(is_available=True)
    if deal_ids:
        Deal.objects.filter(
            business__owner=owner,
            id__in=deal_ids,
        ).update(is_active=True)


def _notify_owner(change_request, *, approved):
    if approved:
        Notification.objects.create(
            user=change_request.owner,
            notification_type='system',
            title_ar='تم اعتماد تغيير الاشتراك',
            title_en='Subscription change approved',
            body_ar=(
                f'تم تطبيق خطة {change_request.target_plan.display_name_ar}. '
                'العناصر التي تتجاوز حدود الخطة تم إيقافها بدون حذف بياناتها.'
            ),
            body_en=(
                f'{change_request.target_plan.display_name_en} is now active. '
                'Items above the plan limits were suspended without deleting data.'
            ),
            data={
                'target': 'subscription',
                'change_request_id': change_request.id,
            },
        )
    else:
        Notification.objects.create(
            user=change_request.owner,
            notification_type='system',
            title_ar='تم رفض طلب تغيير الاشتراك',
            title_en='Subscription change rejected',
            body_ar=change_request.rejection_reason or 'تم رفض الطلب من الإدارة.',
            body_en=change_request.rejection_reason or 'The request was rejected by administration.',
            data={
                'target': 'subscription',
                'change_request_id': change_request.id,
            },
        )


def notify_staff_new_request(change_request):
    staff_users = change_request.owner.__class__.objects.filter(
        is_staff=True,
        is_active=True,
    ).exclude(pk=change_request.owner_id)
    notifications = [
        Notification(
            user=user,
            notification_type='system',
            title_ar='طلب تغيير اشتراك جديد',
            title_en='New subscription change request',
            body_ar=(
                f'{change_request.owner} يطلب الانتقال من '
                f'{change_request.current_plan.display_name_ar} إلى '
                f'{change_request.target_plan.display_name_ar}.'
            ),
            body_en=(
                f'{change_request.owner} requested a change from '
                f'{change_request.current_plan.display_name_en} to '
                f'{change_request.target_plan.display_name_en}.'
            ),
            data={
                'target': 'subscription_admin',
                'change_request_id': change_request.id,
            },
        )
        for user in staff_users
    ]
    if notifications:
        Notification.objects.bulk_create(notifications)


@transaction.atomic
def apply_change_request(change_request, *, reviewer):
    request = (
        SubscriptionChangeRequest.objects.select_for_update()
        .select_related('subscription', 'target_plan', 'current_plan', 'owner')
        .get(pk=change_request.pk)
    )
    if request.status not in {'pending', 'approved'}:
        raise ValueError('Only pending or approved requests can be applied.')

    owner = request.owner
    target_plan = request.target_plan
    direction = change_type(request.current_plan, target_plan)
    _restore_suspended_by_previous_changes(owner)

    active_businesses = list(
        Business.objects.filter(owner=owner, is_active=True).order_by('id')
    )
    active_business_ids = {item.id for item in active_businesses}
    keep_business_ids = set(request.keep_business_ids)

    if direction != 'downgrade' or target_plan.max_businesses == 0:
        keep_business_ids = active_business_ids
    elif len(active_business_ids) > target_plan.max_businesses:
        required_businesses = target_plan.max_businesses
        if len(keep_business_ids) != required_businesses:
            raise ValueError(
                f'Owner must select exactly {required_businesses} business(es) '
                'to keep active for the target plan.'
            )
        if not keep_business_ids.issubset(active_business_ids):
            raise ValueError('Selected businesses are not currently active.')
    else:
        # The owner has fewer/equal businesses than the plan allows: keep all.
        keep_business_ids = active_business_ids

    suspended_business_ids = sorted(active_business_ids - keep_business_ids)
    if suspended_business_ids:
        Business.objects.filter(
            owner=owner,
            id__in=suspended_business_ids,
        ).update(is_active=False)

    available_products = list(
        Product.objects.filter(
            business__owner=owner,
            business_id__in=keep_business_ids,
            is_available=True,
        ).order_by('id')
    )
    available_product_ids = {item.id for item in available_products}
    keep_product_ids = set(request.keep_product_ids)

    if direction != 'downgrade' or target_plan.max_products == 0:
        keep_product_ids = available_product_ids
    elif len(available_product_ids) > target_plan.max_products:
        # The limit is a maximum. Exact selection is required only because
        # there are actually more available products than the new plan allows.
        required_products = target_plan.max_products
        if len(keep_product_ids) != required_products:
            raise ValueError(
                f'Owner must select exactly {required_products} product(s) '
                'to keep visible for the target plan.'
            )
        if not keep_product_ids.issubset(available_product_ids):
            raise ValueError('Selected products are not available in kept businesses.')
    else:
        # Example: target allows 3 but kept business has only 2 -> keep both.
        keep_product_ids = available_product_ids

    suspended_product_ids = sorted(available_product_ids - keep_product_ids)
    if suspended_product_ids:
        Product.objects.filter(
            business__owner=owner,
            id__in=suspended_product_ids,
        ).update(is_available=False)

    suspended_deal_ids = []
    if not target_plan.can_create_deals:
        suspended_deal_ids = list(
            Deal.objects.filter(
                business__owner=owner,
                business__is_active=True,
                is_active=True,
            ).values_list('id', flat=True)
        )
        if suspended_deal_ids:
            Deal.objects.filter(id__in=suspended_deal_ids).update(is_active=False)

    subscription = request.subscription
    subscription.plan = target_plan
    subscription.status = 'active'
    subscription.start_date = timezone.now()
    subscription.end_date = timezone.now() + timedelta(
        days=_PERIOD_DAYS.get(request.billing_period, 30)
    )
    if request.payment_confirmed:
        subscription.amount_paid = request.requested_amount
        subscription.payment_method = request.payment_method
        subscription.transaction_id = request.transaction_id
    subscription.save()

    request.status = 'applied'
    request.change_type = direction
    request.reviewed_by = reviewer
    request.reviewed_at = request.reviewed_at or timezone.now()
    request.applied_at = timezone.now()
    request.applied_changes = {
        'suspended_business_ids': suspended_business_ids,
        'suspended_product_ids': suspended_product_ids,
        'suspended_deal_ids': suspended_deal_ids,
        'kept_business_ids': sorted(keep_business_ids),
        'kept_product_ids': sorted(keep_product_ids),
        'target_plan_id': target_plan.id,
    }
    request.save()
    _notify_owner(request, approved=True)
    return request


def reject_change_request(change_request, *, reviewer, reason):
    if change_request.status != 'pending':
        raise ValueError('Only pending requests can be rejected.')
    change_request.status = 'rejected'
    change_request.rejection_reason = reason
    change_request.reviewed_by = reviewer
    change_request.reviewed_at = timezone.now()
    change_request.save(
        update_fields=[
            'status',
            'rejection_reason',
            'reviewed_by',
            'reviewed_at',
            'updated_at',
        ]
    )
    _notify_owner(change_request, approved=False)
    return change_request
