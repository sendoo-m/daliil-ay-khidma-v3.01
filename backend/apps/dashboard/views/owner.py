"""
Owner Dashboard Views
=====================
لوحة تحكم أصحاب المحلات
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.db.models import Count, Sum, Avg, Q
from django.core.paginator import Paginator
from django.http import JsonResponse
from django.utils import timezone
from datetime import timedelta

from apps.directory.models import Business, BusinessImage
from apps.products.models import Product, ProductImage
from apps.deals.models import Deal


# ==========================================
# Dashboard Home
# ==========================================
@login_required
def owner_dashboard(request):
    """الصفحة الرئيسية للوحة التحكم"""
    
    # Get user's businesses
    businesses = Business.objects.filter(owner=request.user)
    
    # Statistics
    total_businesses = businesses.count()
    active_businesses = businesses.filter(is_active=True).count()
    verified_businesses = businesses.filter(is_verified=True).count()
    
    # Products count
    total_products = Product.objects.filter(
        business__owner=request.user
    ).count()
    
    # Active deals
    active_deals = Deal.objects.filter(
        business__owner=request.user,
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now(),
        is_active=True
    ).count()
    
    # Recent views (last 30 days)
    total_views = businesses.aggregate(Sum('view_count'))['view_count__sum'] or 0
    total_clicks = businesses.aggregate(Sum('click_count'))['click_count__sum'] or 0
    
    # Recent reviews
    try:
        from apps.reviews.models import Review
        pending_reviews = Review.objects.filter(
            business__owner=request.user,
            owner_response__isnull=True
        ).count()
        avg_rating = Review.objects.filter(
            business__owner=request.user,
            is_approved=True
        ).aggregate(Avg('rating'))['rating__avg'] or 0
    except ImportError:
        pending_reviews = 0
        avg_rating = 0
    
    context = {
        'businesses': businesses[:5],  # Latest 5
        'total_businesses': total_businesses,
        'active_businesses': active_businesses,
        'verified_businesses': verified_businesses,
        'total_products': total_products,
        'active_deals': active_deals,
        'total_views': total_views,
        'total_clicks': total_clicks,
        'pending_reviews': pending_reviews,
        'avg_rating': round(avg_rating, 1) if avg_rating else 0,
    }
    
    return render(request, 'dashboard/owner/index.html', context)


# ==========================================
# Business Management
# ==========================================
@login_required
def business_list(request):
    """قائمة محلات المستخدم"""
    businesses = Business.objects.filter(owner=request.user).order_by('-created_at')
    
    # Filtering
    status = request.GET.get('status')
    if status == 'active':
        businesses = businesses.filter(is_active=True)
    elif status == 'inactive':
        businesses = businesses.filter(is_active=False)
    elif status == 'verified':
        businesses = businesses.filter(is_verified=True)
    
    business_type = request.GET.get('type')
    if business_type:
        businesses = businesses.filter(business_type=business_type)
    
    # Pagination
    paginator = Paginator(businesses, 10)
    page = request.GET.get('page')
    businesses = paginator.get_page(page)
    
    context = {
        'businesses': businesses,
        'status': status,
        'business_type': business_type,
    }
    return render(request, 'dashboard/owner/businesses/list.html', context)


@login_required
def business_create(request):
    """إضافة محل جديد"""
    if request.method == 'POST':
        # Handle form submission (will be implemented with forms)
        messages.success(request, 'تم إضافة المحل بنجاح!')
        return redirect('dashboard:owner:business_list')
    
    context = {}
    return render(request, 'dashboard/owner/businesses/create.html', context)


@login_required
def business_edit(request, slug):
    """تعديل محل"""
    business = get_object_or_404(Business, slug=slug, owner=request.user)
    
    if request.method == 'POST':
        # Handle form submission
        messages.success(request, 'تم تحديث المحل بنجاح!')
        return redirect('dashboard:owner:business_list')
    
    context = {
        'business': business,
    }
    return render(request, 'dashboard/owner/businesses/edit.html', context)


@login_required
def business_delete(request, slug):
    """حذف محل"""
    business = get_object_or_404(Business, slug=slug, owner=request.user)
    
    if request.method == 'POST':
        business.delete()
        messages.success(request, 'تم حذف المحل بنجاح!')
        return redirect('dashboard:owner:business_list')
    
    context = {
        'business': business,
    }
    return render(request, 'dashboard/owner/businesses/delete.html', context)


# ==========================================
# Product Management
# ==========================================
@login_required
def product_list(request):
    """قائمة منتجات المستخدم"""
    products = Product.objects.filter(
        business__owner=request.user
    ).select_related('business', 'category').order_by('-created_at')
    
    # Filtering
    business_id = request.GET.get('business')
    if business_id:
        products = products.filter(business_id=business_id)
    
    product_type = request.GET.get('type')
    if product_type:
        products = products.filter(product_type=product_type)
    
    # Pagination
    paginator = Paginator(products, 20)
    page = request.GET.get('page')
    products = paginator.get_page(page)
    
    # User's businesses for filter
    businesses = Business.objects.filter(owner=request.user)
    
    context = {
        'products': products,
        'businesses': businesses,
        'selected_business': business_id,
        'selected_type': product_type,
    }
    return render(request, 'dashboard/owner/products/list.html', context)


@login_required
def product_create(request):
    """إضافة منتج جديد"""
    # Get user's businesses
    businesses = Business.objects.filter(owner=request.user)
    
    if request.method == 'POST':
        # Handle form submission
        messages.success(request, 'تم إضافة المنتج بنجاح!')
        return redirect('dashboard:owner:product_list')
    
    context = {
        'businesses': businesses,
    }
    return render(request, 'dashboard/owner/products/create.html', context)


@login_required
def product_edit(request, slug):
    """تعديل منتج"""
    product = get_object_or_404(
        Product,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        # Handle form submission
        messages.success(request, 'تم تحديث المنتج بنجاح!')
        return redirect('dashboard:owner:product_list')
    
    context = {
        'product': product,
    }
    return render(request, 'dashboard/owner/products/edit.html', context)


@login_required
def product_delete(request, slug):
    """حذف منتج"""
    product = get_object_or_404(
        Product,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        product.delete()
        messages.success(request, 'تم حذف المنتج بنجاح!')
        return redirect('dashboard:owner:product_list')
    
    context = {
        'product': product,
    }
    return render(request, 'dashboard/owner/products/delete.html', context)


# ==========================================
# Deal Management
# ==========================================
@login_required
def deal_list(request):
    """قائمة العروض"""
    deals = Deal.objects.filter(
        business__owner=request.user
    ).select_related('business').order_by('-created_at')
    
    # Filtering
    status = request.GET.get('status')
    if status == 'active':
        deals = deals.filter(
            start_date__lte=timezone.now(),
            end_date__gte=timezone.now(),
            is_active=True
        )
    elif status == 'expired':
        deals = deals.filter(end_date__lt=timezone.now())
    
    # Pagination
    paginator = Paginator(deals, 10)
    page = request.GET.get('page')
    deals = paginator.get_page(page)
    
    context = {
        'deals': deals,
        'status': status,
    }
    return render(request, 'dashboard/owner/deals/list.html', context)


@login_required
def deal_create(request):
    """إضافة عرض جديد"""
    businesses = Business.objects.filter(owner=request.user)
    
    if request.method == 'POST':
        # Handle form submission
        messages.success(request, 'تم إضافة العرض بنجاح!')
        return redirect('dashboard:owner:deal_list')
    
    context = {
        'businesses': businesses,
    }
    return render(request, 'dashboard/owner/deals/create.html', context)


@login_required
def deal_edit(request, slug):
    """تعديل عرض"""
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        # Handle form submission
        messages.success(request, 'تم تحديث العرض بنجاح!')
        return redirect('dashboard:owner:deal_list')
    
    context = {
        'deal': deal,
    }
    return render(request, 'dashboard/owner/deals/edit.html', context)


@login_required
def deal_delete(request, slug):
    """حذف عرض"""
    deal = get_object_or_404(
        Deal,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        deal.delete()
        messages.success(request, 'تم حذف العرض بنجاح!')
        return redirect('dashboard:owner:deal_list')
    
    context = {
        'deal': deal,
    }
    return render(request, 'dashboard/owner/deals/delete.html', context)


# ==========================================
# Reviews Management
# ==========================================
@login_required
def review_list(request):
    """قائمة التعليقات"""
    try:
        from apps.reviews.models import Review
        
        reviews = Review.objects.filter(
            business__owner=request.user
        ).select_related('business', 'user').order_by('-created_at')
        
        # Filtering
        responded = request.GET.get('responded')
        if responded == 'yes':
            reviews = reviews.filter(owner_response__isnull=False)
        elif responded == 'no':
            reviews = reviews.filter(owner_response__isnull=True)
        
        # Pagination
        paginator = Paginator(reviews, 20)
        page = request.GET.get('page')
        reviews = paginator.get_page(page)
        
        context = {
            'reviews': reviews,
            'responded': responded,
        }
    except ImportError:
        context = {
            'reviews': [],
            'error': 'Reviews app not installed',
        }
    
    return render(request, 'dashboard/owner/reviews/list.html', context)


@login_required
def review_respond(request, pk):
    """الرد على تعليق"""
    try:
        from apps.reviews.models import Review
        
        review = get_object_or_404(
            Review,
            pk=pk,
            business__owner=request.user
        )
        
        if request.method == 'POST':
            response = request.POST.get('response')
            if response:
                review.owner_response = response
                review.response_date = timezone.now()
                review.save()
                messages.success(request, 'تم إضافة ردك بنجاح!')
                return redirect('dashboard:owner:review_list')
        
        context = {
            'review': review,
        }
        return render(request, 'dashboard/owner/reviews/respond.html', context)
    
    except ImportError:
        messages.error(request, 'Reviews app not installed')
        return redirect('dashboard:owner:dashboard')
