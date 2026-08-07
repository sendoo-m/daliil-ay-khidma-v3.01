"""Owner dashboard home view."""

from django.contrib.auth.decorators import login_required
from django.db.models import Avg, Sum
from django.shortcuts import render
from django.utils import timezone

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product
from apps.reviews.models import Review


@login_required
def owner_dashboard(request):
    """Render the business-owner dashboard using the current data model."""
    businesses = Business.objects.filter(owner=request.user).select_related('category')

    total_businesses = businesses.count()
    active_businesses = businesses.filter(is_active=True).count()
    verified_businesses = businesses.filter(is_verified=True).count()

    total_products = Product.objects.filter(
        business__owner=request.user,
    ).count()

    active_deals = Deal.objects.filter(
        business__owner=request.user,
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now(),
        is_active=True,
    ).count()

    totals = businesses.aggregate(
        total_views=Sum('view_count'),
        total_clicks=Sum('click_count'),
    )

    owner_reviews = Review.objects.filter(business__owner=request.user)
    pending_reviews = owner_reviews.filter(reply__isnull=True).count()
    avg_rating = owner_reviews.filter(is_approved=True).aggregate(
        average=Avg('rating'),
    )['average'] or 0

    context = {
        'businesses': businesses.order_by('-created_at')[:5],
        'total_businesses': total_businesses,
        'active_businesses': active_businesses,
        'verified_businesses': verified_businesses,
        'total_products': total_products,
        'active_deals': active_deals,
        'total_views': totals['total_views'] or 0,
        'total_clicks': totals['total_clicks'] or 0,
        'pending_reviews': pending_reviews,
        'avg_rating': round(avg_rating, 1) if avg_rating else 0,
    }
    return render(request, 'dashboard/owner/index.html', context)
