"""
Products Views
==============
عرض وإدارة المنتجات والخدمات
"""

from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q, Avg, Count
from django.http import JsonResponse
from django.views.decorators.http import require_POST

from .models import Product, ProductImage
from apps.directory.models import Business


# ========================================
# Public Views
# ========================================

def product_list(request):
    """
    قائمة جميع المنتجات والخدمات المتاحة
    """
    products = Product.objects.filter(
        is_available=True,
        business__is_active=True,
        business__is_verified=True
    ).select_related(
        'business',
        'business__district',
        'business__district__city',
        'business__district__city__governorate'
    ).prefetch_related('images')
    
    # Filters
    product_type = request.GET.get('type')
    if product_type in ['product', 'service']:
        products = products.filter(product_type=product_type)
    
    business_id = request.GET.get('business')
    if business_id:
        products = products.filter(business_id=business_id)
    
    # Search
    search_query = request.GET.get('q')
    if search_query:
        products = products.filter(
            Q(name_en__icontains=search_query) |
            Q(name_ar__icontains=search_query) |
            Q(description_en__icontains=search_query) |
            Q(description_ar__icontains=search_query)
        )
    
    # Sorting
    sort_by = request.GET.get('sort', '-created_at')
    if sort_by in ['price', '-price', '-view_count', '-created_at', 'name_en']:
        products = products.order_by(sort_by)
    
    # Featured first
    products = products.order_by('-is_featured', sort_by)
    
    # Pagination
    paginator = Paginator(products, 12)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'total_count': paginator.count,
        'search_query': search_query,
        'product_type': product_type,
    }
    
    return render(request, 'products/product_list.html', context)


def product_detail(request, slug):
    """
    تفاصيل منتج/خدمة محددة
    """
    product = get_object_or_404(
        Product.objects.select_related(
            'business',
            'business__district',
            'business__district__city',
            'business__district__city__governorate'
        ).prefetch_related('images'),
        slug=slug
    )
    
    # Increment view count
    product.increment_view_count()
    
    # Related products from same business
    related_products = Product.objects.filter(
        business=product.business,
        is_available=True
    ).exclude(id=product.id)[:4]
    
    # Similar products from same category
    similar_products = Product.objects.filter(
        business__category=product.business.category,
        is_available=True
    ).exclude(
        business=product.business
    ).select_related('business')[:6]
    
    context = {
        'product': product,
        'related_products': related_products,
        'similar_products': similar_products,
    }
    
    return render(request, 'products/product_detail.html', context)


def products_by_business(request, business_slug):
    """
    منتجات محل معين
    """
    business = get_object_or_404(
        Business.objects.select_related(
            'district__city__governorate'
        ),
        slug=business_slug,
        is_active=True
    )
    
    products = Product.objects.filter(
        business=business,
        is_available=True
    ).prefetch_related('images')
    
    # Filter by type
    product_type = request.GET.get('type')
    if product_type in ['product', 'service']:
        products = products.filter(product_type=product_type)
    
    # Sorting
    sort_by = request.GET.get('sort', '-is_featured')
    products = products.order_by(sort_by, '-created_at')
    
    # Pagination
    paginator = Paginator(products, 12)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'business': business,
        'page_obj': page_obj,
        'total_count': paginator.count,
        'product_type': product_type,
    }
    
    return render(request, 'products/products_by_business.html', context)


# ========================================
# Owner/Dashboard Views
# ========================================

@login_required
def my_products(request):
    """
    منتجات المستخدم (صاحب المحل)
    """
    # Get user's business
    try:
        business = Business.objects.get(owner=request.user)
    except Business.DoesNotExist:
        messages.warning(request, 'يجب إنشاء محل أولاً قبل إضافة المنتجات')
        return redirect('dashboard:dashboard')
    
    products = Product.objects.filter(
        business=business
    ).prefetch_related('images').order_by('-created_at')
    
    # Stats
    stats = {
        'total': products.count(),
        'available': products.filter(is_available=True).count(),
        'unavailable': products.filter(is_available=False).count(),
        'featured': products.filter(is_featured=True).count(),
        'total_views': sum(p.view_count for p in products),
    }
    
    # Pagination
    paginator = Paginator(products, 10)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)
    
    context = {
        'business': business,
        'page_obj': page_obj,
        'stats': stats,
    }
    
    return render(request, 'products/my_products.html', context)


@login_required
def product_create(request):
    """
    إنشاء منتج جديد
    """
    # Check if user has business
    try:
        business = Business.objects.get(owner=request.user)
    except Business.DoesNotExist:
        messages.error(request, 'يجب إنشاء محل أولاً')
        return redirect('dashboard:dashboard')
    
    # Check subscription limits (if implemented)
    # ...
    
    if request.method == 'POST':
        # Process form data
        # This is a placeholder - you'll use Django forms here
        messages.success(request, 'تم إضافة المنتج بنجاح')
        return redirect('products:my_products')
    
    context = {
        'business': business,
    }
    
    return render(request, 'products/product_form.html', context)


@login_required
def product_edit(request, slug):
    """
    تعديل منتج
    """
    product = get_object_or_404(
        Product,
        slug=slug,
        business__owner=request.user
    )
    
    if request.method == 'POST':
        # Process form data
        messages.success(request, 'تم تحديث المنتج بنجاح')
        return redirect('products:my_products')
    
    context = {
        'product': product,
        'business': product.business,
    }
    
    return render(request, 'products/product_form.html', context)


@login_required
@require_POST
def product_delete(request, slug):
    """
    حذف منتج
    """
    product = get_object_or_404(
        Product,
        slug=slug,
        business__owner=request.user
    )
    
    product.delete()
    messages.success(request, 'تم حذف المنتج بنجاح')
    
    return redirect('products:my_products')


@login_required
@require_POST
def product_toggle_availability(request, slug):
    """
    تبديل حالة التوفر
    """
    product = get_object_or_404(
        Product,
        slug=slug,
        business__owner=request.user
    )
    
    product.is_available = not product.is_available
    product.save()
    
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return JsonResponse({
            'success': True,
            'is_available': product.is_available
        })
    
    messages.success(request, 'تم تحديث حالة التوفر')
    return redirect('products:my_products')


# ========================================
# AJAX Views
# ========================================

@require_POST
def increment_product_view(request, product_id):
    """
    زيادة عداد المشاهدات (AJAX)
    """
    try:
        product = Product.objects.get(id=product_id)
        product.increment_view_count()
        return JsonResponse({'success': True, 'views': product.view_count})
    except Product.DoesNotExist:
        return JsonResponse({'success': False}, status=404)
