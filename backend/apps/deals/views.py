"""
Deals Views
===========
عرض وإدارة العروض والخصومات
"""

from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.utils import timezone

from .models import Deal, DealClaim
from apps.directory.models import Business


# ========================================
# Public Views
# ========================================

def deal_list(request):
    now = timezone.now()

    deals = Deal.objects.filter(
        is_active=True,
        start_date__lte=now,
        end_date__gte=now,
        business__is_active=True,
        business__is_verified=True
    ).select_related(
        'business',
        'business__district',
        'business__district__city',
        'business__district__city__governorate'
    )

    # Filters
    deal_type = request.GET.get('type')
    if deal_type in ['percentage', 'fixed', 'bogo', 'bundle', 'special']:
        deals = deals.filter(deal_type=deal_type)

    business_id = request.GET.get('business')
    if business_id:
        deals = deals.filter(business_id=business_id)

    category_slug = request.GET.get('category')
    if category_slug:
        deals = deals.filter(business__category__slug=category_slug)

    search_query = request.GET.get('q')
    if search_query:
        deals = deals.filter(
            Q(title_en__icontains=search_query) |
            Q(title_ar__icontains=search_query) |
            Q(description_en__icontains=search_query) |
            Q(description_ar__icontains=search_query)
        )

    deals = deals.order_by('-is_featured', 'order', '-created_at')

    # Stats قبل الـ pagination
    stats = {
        'active_deals': deals.count(),
        'featured_deals': deals.filter(is_featured=True).count(),
        'ending_soon': deals.filter(end_date__lte=now + timezone.timedelta(days=3)).count(),
    }

    # Pagination
    paginator = Paginator(deals, 12)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)

    # Categories للفلتر
    from apps.categories.models import Category
    categories = Category.objects.filter(
        is_active=True,
        parent__isnull=True
    ).order_by('order')

    context = {
        'deals': page_obj,        # ✅ اسمه deals عشان الـ template يشتغل
        'total_count': paginator.count,
        'search_query': search_query,
        'deal_type': deal_type,
        'stats': stats,
        'categories': categories,  # ✅ أضفنا categories
    }

    return render(request, 'deals/deal_list.html', context)


def deal_detail(request, slug):
    """
    تفاصيل عرض محدد
    """
    deal = get_object_or_404(
        Deal.objects.select_related(
            'business',
            'business__district',
            'business__district__city',
            'business__district__city__governorate'
        ),
        slug=slug
    )
    
    # Increment view count
    deal.increment_view_count()
    
    # Check if user has claimed this deal
    user_claimed = False
    user_claims_count = 0
    if request.user.is_authenticated:
        user_claims_count = DealClaim.objects.filter(
            deal=deal,
            user=request.user
        ).count()
        user_claimed = user_claims_count > 0
    
    # Related deals from same business
    related_deals = Deal.objects.filter(
        business=deal.business,
        is_active=True,
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now()
    ).exclude(id=deal.id)[:3]
    
    # Similar deals from same category
    similar_deals = Deal.objects.filter(
        business__category=deal.business.category,
        is_active=True,
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now()
    ).exclude(
        business=deal.business
    ).select_related('business')[:6]
    
    context = {
        'deal': deal,
        'user_claimed': user_claimed,
        'user_claims_count': user_claims_count,
        'can_claim': deal.is_valid and (not user_claimed or user_claims_count < deal.max_uses_per_user),
        'related_deals': related_deals,
        'similar_deals': similar_deals,
    }
    
    return render(request, 'deals/deal_detail.html', context)


def deals_by_business(request, business_slug):
    """
    عروض محل معين
    """
    business = get_object_or_404(
        Business.objects.select_related(
            'district__city__governorate'
        ),
        slug=business_slug,
        is_active=True
    )
    
    now = timezone.now()
    deals = Deal.objects.filter(
        business=business,
        is_active=True,
        start_date__lte=now,
        end_date__gte=now
    )
    
    # Filter by type
    deal_type = request.GET.get('type')
    if deal_type:
        deals = deals.filter(deal_type=deal_type)
    
    # Sorting
    deals = deals.order_by('-is_featured', 'order', '-created_at')
    
    # Pagination
    paginator = Paginator(deals, 12)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'business': business,
        'page_obj': page_obj,
        'total_count': paginator.count,
        'deal_type': deal_type,
    }
    
    return render(request, 'deals/deals_by_business.html', context)


# ========================================
# User Actions
# ========================================

@login_required
@require_POST
def claim_deal(request, slug):
    """
    طلب عرض (استخدام العرض)
    """
    deal = get_object_or_404(Deal, slug=slug)
    
    # Check if deal is valid
    if not deal.is_valid:
        messages.error(request, 'هذا العرض غير متاح حالياً')
        return redirect('deals:deal_detail', slug=slug)
    
    # Check user claims count
    user_claims = DealClaim.objects.filter(
        deal=deal,
        user=request.user
    ).count()
    
    if user_claims >= deal.max_uses_per_user:
        messages.error(request, f'لقد استخدمت هذا العرض {deal.max_uses_per_user} مرة/مرات بالفعل')
        return redirect('deals:deal_detail', slug=slug)
    
    # Create claim
    claim = DealClaim.objects.create(
        deal=deal,
        user=request.user
    )
    
    # Increment deal uses
    if deal.increment_uses():
        messages.success(request, 'تم طلب العرض بنجاح! سيظهر في قسم "عروضي"، قم بإظهاره في المحل')
    else:
        claim.delete()
        messages.error(request, 'عذراً، لقد وصل العرض للحد الأقصى من الاستخدامات')
    
    return redirect('deals:deal_detail', slug=slug)


@login_required
def my_deals(request):
    """
    عروض المستخدم المطلوبة
    """
    claims = DealClaim.objects.filter(
        user=request.user
    ).select_related(
        'deal',
        'deal__business'
    ).order_by('-claimed_at')
    
    # Filter by status
    status = request.GET.get('status')
    if status == 'active':
        claims = claims.filter(deal__end_date__gte=timezone.now(), is_used=False)
    elif status == 'used':
        claims = claims.filter(is_used=True)
    elif status == 'expired':
        claims = claims.filter(deal__end_date__lt=timezone.now(), is_used=False)
    
    # Pagination
    paginator = Paginator(claims, 10)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    # Stats
    stats = {
        'total': claims.count(),
        'active': claims.filter(deal__end_date__gte=timezone.now(), is_used=False).count(),
        'used': claims.filter(is_used=True).count(),
        'expired': claims.filter(deal__end_date__lt=timezone.now(), is_used=False).count(),
    }
    
    context = {
        'page_obj': page_obj,
        'stats': stats,
        'status': status,
    }
    
    return render(request, 'deals/my_deals.html', context)


# ========================================
# Business Owner Views
# ========================================

@login_required
def business_deals(request):
    """
    عروض محل المستخدم
    """
    try:
        business = Business.objects.get(owner=request.user)
    except Business.DoesNotExist:
        messages.warning(request, 'يجب إنشاء محل أولاً')
        return redirect('dashboard:dashboard')
    
    deals = Deal.objects.filter(
        business=business
    ).order_by('-created_at')
    
    # Stats
    now = timezone.now()
    stats = {
        'total': deals.count(),
        'active': deals.filter(is_active=True, start_date__lte=now, end_date__gte=now).count(),
        'upcoming': deals.filter(start_date__gt=now).count(),
        'expired': deals.filter(end_date__lt=now).count(),
        'total_claims': sum(d.current_uses for d in deals),
        'total_views': sum(d.view_count for d in deals),
    }
    
    # Pagination
    paginator = Paginator(deals, 10)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'business': business,
        'page_obj': page_obj,
        'stats': stats,
    }
    
    return render(request, 'deals/business_deals.html', context)


@login_required
def deal_create(request):
    """
    إنشاء عرض جديد
    """
    try:
        business = Business.objects.get(owner=request.user)
    except Business.DoesNotExist:
        messages.error(request, 'يجب إنشاء محل أولاً')
        return redirect('dashboard:dashboard')
    
    # Check subscription permissions (if implemented)
    # ...
    
    if request.method == 'POST':
        # Process form
        messages.success(request, 'تم إضافة العرض بنجاح')
        return redirect('deals:business_deals')
    
    context = {
        'business': business,
    }
    
    return render(request, 'deals/deal_form.html', context)


@login_required
def deal_edit(request, slug):
    """
    تعديل عرض
    """
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        # Process form
        messages.success(request, 'تم تحديث العرض بنجاح')
        return redirect('deals:business_deals')
    
    context = {
        'deal': deal,
        'business': deal.business,
    }
    
    return render(request, 'deals/deal_form.html', context)


@login_required
@require_POST
def deal_delete(request, slug):
    """
    حذف عرض
    """
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    deal.delete()
    messages.success(request, 'تم حذف العرض بنجاح')
    
    return redirect('deals:business_deals')


@login_required
@require_POST
def deal_toggle_active(request, slug):
    """
    تفعيل/تعطيل عرض
    """
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    deal.is_active = not deal.is_active
    deal.save()
    
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return JsonResponse({
            'success': True,
            'is_active': deal.is_active
        })
    
    messages.success(request, 'تم تحديث حالة العرض')
    return redirect('deals:business_deals')


@login_required
def deal_claims_list(request, slug):
    """
    قائمة استخدامات عرض معين
    """
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    claims = DealClaim.objects.filter(
        deal=deal
    ).select_related('user').order_by('-claimed_at')
    
    # Pagination
    paginator = Paginator(claims, 20)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'deal': deal,
        'page_obj': page_obj,
    }
    
    return render(request, 'deals/deal_claims.html', context)
