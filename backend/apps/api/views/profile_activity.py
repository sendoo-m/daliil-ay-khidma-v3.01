"""My recent activity — a lightweight merge of the user's own reviews,
favorites and claimed deals, sorted by recency. No dedicated audit-log
model exists for end users (only the admin-only AuditLog), so this
view composes the feed on read from the three tables that already
track a `user` + timestamp, instead of introducing new write paths.
"""
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema

from apps.reviews.models import Review
from apps.directory.models import Favorite
from apps.deals.models import DealClaim

RECENT_ACTIVITY_LIMIT = 20


def _absolute_logo(business, request):
    logo = getattr(business, 'logo', None)
    if not logo:
        return None
    try:
        url = logo.url
    except ValueError:
        return None
    return request.build_absolute_uri(url) if request else url


@extend_schema(responses=OpenApiTypes.OBJECT)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def recent_activity(request):
    """آخر أنشطتي: تقييمات كتبتها، محلات أضفتها للمفضلة، عروض استخدمتها."""
    user = request.user
    per_source_limit = RECENT_ACTIVITY_LIMIT

    reviews = (
        Review.objects.filter(user=user)
        .select_related('business')
        .order_by('-created_at')[:per_source_limit]
    )
    favorites = (
        Favorite.objects.filter(user=user)
        .select_related('business')
        .order_by('-created_at')[:per_source_limit]
    )
    deal_claims = (
        DealClaim.objects.filter(user=user)
        .select_related('deal', 'deal__business')
        .order_by('-claimed_at')[:per_source_limit]
    )

    items = []
    for review in reviews:
        items.append({
            'type': 'review',
            'created_at': review.created_at,
            'business_name': review.business.name_ar,
            'business_slug': review.business.slug,
            'business_logo': _absolute_logo(review.business, request),
            'rating': review.rating,
            'deal_title': None,
            'deal_slug': None,
        })
    for favorite in favorites:
        items.append({
            'type': 'favorite',
            'created_at': favorite.created_at,
            'business_name': favorite.business.name_ar,
            'business_slug': favorite.business.slug,
            'business_logo': _absolute_logo(favorite.business, request),
            'rating': None,
            'deal_title': None,
            'deal_slug': None,
        })
    for claim in deal_claims:
        items.append({
            'type': 'deal_claim',
            'created_at': claim.claimed_at,
            'business_name': claim.deal.business.name_ar,
            'business_slug': claim.deal.business.slug,
            'business_logo': _absolute_logo(claim.deal.business, request),
            'rating': None,
            'deal_title': claim.deal.title_ar,
            'deal_slug': claim.deal.slug,
        })

    items.sort(key=lambda item: item['created_at'], reverse=True)
    return Response({'results': items[:RECENT_ACTIVITY_LIMIT]})
