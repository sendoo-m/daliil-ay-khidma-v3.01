"""
Directory App Views
===================
جميع عرض وعمليات الدليل
"""

from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.db.models import Q, Count
from django.core.paginator import Paginator
from django.views.decorators.http import require_POST
from django.shortcuts import render
from django.db.models import Q
from apps.directory.models import Business, Governorate
from apps.categories.models import Category
import json
from apps.directory.models.favorites import Favorite

from .models import (
    Governorate,
    City,
    District,
    Category,
    Business
    )


# ========================================
# Home Page
# ========================================
def home(request):
    """الصفحة الرئيسية"""
    context = {
        'featured_businesses': Business.objects.filter(
            is_active=True,
            is_verified=True,
            is_featured=True
        )[:6],
        'promoted_businesses': Business.objects.filter(
            is_active=True,
            is_verified=True,
            is_promoted=True
        )[:3],
        'governorates': Governorate.objects.filter(is_active=True)[:8],
        'categories': Category.objects.filter(
            is_active=True,
            parent__isnull=True
        )[:8],
        'recent_businesses': Business.objects.filter(
            is_active=True,
            is_verified=True
        )[:6],
    }
    return render(request, 'directory/home.html', context)


# ========================================
# Governorate Views
# ========================================
def governorate_list(request):
    governorates = Governorate.objects.filter(is_active=True).prefetch_related('cities')

    from apps.directory.models import Business
    from apps.directory.models.location import City

    context = {
        'governorates': governorates,
        'total_count': governorates.count(),
        'total_cities': City.objects.filter(is_active=True).count(),
        'total_businesses': Business.objects.filter(is_active=True).count(),
    }
    return render(request, 'directory/governorate_list.html', context)


def governorate_detail(request, slug):
    governorate = get_object_or_404(Governorate, slug=slug, is_active=True)

    cities = governorate.cities.filter(is_active=True).order_by('order', 'name_en')
    businesses = Business.objects.filter(
        district__city__governorate=governorate,
        is_active=True,
        is_verified=True
    ).select_related('category', 'district').order_by('-is_featured', '-view_count')

    other_governorates = Governorate.objects.filter(
        is_active=True
    ).exclude(id=governorate.id).order_by('order')[:6]

    context = {
        'governorate': governorate,
        'cities': cities,
        'businesses': businesses[:12],
        'total_businesses': businesses.count(),
        'other_governorates': other_governorates,
    }
    return render(request, 'directory/governorate_detail.html', context)


# ========================================
# City Views
# ========================================

def city_detail(request, slug):
    city = get_object_or_404(City, slug=slug, is_active=True)

    districts = city.districts.filter(is_active=True).order_by('order', 'name_en')
    businesses = Business.objects.filter(
        district__city=city,
        is_active=True,
        is_verified=True
    ).select_related('category', 'district').order_by('-is_featured', '-view_count')

    context = {
        'city': city,
        'districts': districts,
        'businesses': businesses[:12],
        'total_businesses': businesses.count(),
    }
    return render(request, 'directory/city_detail.html', context)

# ========================================
# District Views
# ========================================

def district_detail(request, slug):
    district = get_object_or_404(District, slug=slug, is_active=True)

    businesses = Business.objects.filter(
        district=district,
        is_active=True,
        is_verified=True
    ).select_related('category').order_by('-is_featured', '-view_count')

    paginator = Paginator(businesses, 20)
    page = request.GET.get('page')
    businesses_page = paginator.get_page(page)

    context = {
        'district': district,
        'businesses': businesses_page,
        'total_businesses': businesses.count(),
    }
    return render(request, 'directory/district_detail.html', context)

# ========================================
# Business Views
# ========================================
def business_list(request):
    """قائمة جميع المحلات"""
    businesses = Business.objects.filter(
        is_active=True,
        is_verified=True
    )
    
    # Filters
    category_slug = request.GET.get('category')
    governorate_slug = request.GET.get('governorate')
    city_slug = request.GET.get('city')
    search = request.GET.get('q')
    
    if category_slug:
        businesses = businesses.filter(category__slug=category_slug)
    
    if governorate_slug:
        businesses = businesses.filter(
            district__city__governorate__slug=governorate_slug
        )
    
    if city_slug:
        businesses = businesses.filter(district__city__slug=city_slug)
    
    if search:
        businesses = businesses.filter(
            Q(name_en__icontains=search) |
            Q(name_ar__icontains=search) |
            Q(description_en__icontains=search) |
            Q(description_ar__icontains=search)
        )
    
    # Sorting
    sort = request.GET.get('sort', '-created_at')
    if sort == 'popular':
        businesses = businesses.order_by('-view_count')
    elif sort == 'rating':
        # This will be implemented when reviews are added
        businesses = businesses.order_by('-created_at')
    else:
        businesses = businesses.order_by(sort)
    
    # Pagination
    paginator = Paginator(businesses, 20)
    page = request.GET.get('page')
    businesses_page = paginator.get_page(page)
    
    context = {
        'businesses': businesses_page,
        'total_count': businesses.count(),
        'categories': Category.objects.filter(is_active=True, parent__isnull=True),
        'governorates': Governorate.objects.filter(is_active=True),
    }
    return render(request, 'directory/business_list.html', context)


def business_detail(request, slug):
    """تفاصيل محل معين"""
    business = get_object_or_404(
        Business.objects.select_related(
            'category',
            'district__city__governorate',
            'owner'
        ),
        slug=slug
    )
    
    # Increment view count
    business.increment_view_count()
    
    # Get business images
    images = business.images.filter(is_active=True)
    
    # Get products
    from apps.products.models import Product
    products = Product.objects.filter(
        business=business,
        is_available=True
    ).prefetch_related('images').order_by('-is_featured', 'order', '-created_at')
    
    # Get reviews
    reviews = None
    average_rating = 0
    total_reviews = 0
    try:
        from apps.reviews.models import Review
        from django.db.models import Avg
        
        reviews = Review.objects.filter(
            business=business,
            is_approved=True
        ).select_related('user').order_by('-created_at')[:5]
        
        if reviews.exists():
            avg = Review.objects.filter(
                business=business,
                is_approved=True
            ).aggregate(Avg('rating'))['rating__avg']
            average_rating = round(avg, 1) if avg else 0
            total_reviews = Review.objects.filter(
                business=business,
                is_approved=True
            ).count()
    except ImportError:
        pass
    
    # Check if user favorited
    is_favorited = False
    if request.user.is_authenticated:
        is_favorited = Favorite.objects.filter(
            user=request.user,
            business=business
        ).exists()
    
    # Related businesses
    related_businesses = Business.objects.filter(
        category=business.category,
        is_active=True,
        is_verified=True
    ).exclude(id=business.id).order_by('-is_featured', '-view_count')[:5]

    # ← الإضافة الوحيدة: تحويل الإحداثيات لـ float صريح
    # business_lat = float(business.latitude) if business.latitude else None
    # business_lng = float(business.longitude) if business.longitude else None
    # ✅ صح
    business_lat = str(float(business.latitude)) if business.latitude else None
    business_lng = str(float(business.longitude)) if business.longitude else None

    context = {
        'business': business,
        'images': images,
        'products': products,
        'reviews': reviews,
        'average_rating': average_rating,
        'total_reviews': total_reviews,
        'is_favorited': is_favorited,
        'related_businesses': related_businesses,
        # ← أضفهم للـ context
        'business_lat': business_lat,
        'business_lng': business_lng,
    }
    
    return render(request, 'directory/business_detail.html', context)

# ========================================
# Business CRUD (Owner)
# ========================================
@login_required
def business_create(request):
    """إضافة محل جديد"""
    # This will be implemented with forms
    return render(request, 'directory/business_form.html')


@login_required
def business_update(request, slug):
    """تعديل محل"""
    business = get_object_or_404(
        Business,
        slug=slug,
        owner=request.user
    )
    # This will be implemented with forms
    return render(request, 'directory/business_form.html', {'business': business})


@login_required
def business_delete(request, slug):
    """حذف محل"""
    business = get_object_or_404(
        Business,
        slug=slug,
        owner=request.user
    )
    if request.method == 'POST':
        business.delete()
        messages.success(request, 'Business deleted successfully!')
        return redirect('directory:my_businesses')
    
    return render(request, 'directory/business_confirm_delete.html', {'business': business})


# ========================================
# User Dashboard
# ========================================
@login_required
def my_businesses(request):
    """محلاتي"""
    businesses = Business.objects.filter(owner=request.user)
    
    context = {
        'businesses': businesses,
        'total_count': businesses.count()
    }
    return render(request, 'directory/my_businesses.html', context)


@login_required
def my_favorites(request):
    """مفضلاتي"""
    favorites = Favorite.objects.filter(
        user=request.user
    ).select_related('business')
    
    context = {
        'favorites': favorites,
        'total_count': favorites.count()
    }
    return render(request, 'directory/my_favorites.html', context)


# ========================================
# Favorite Toggle
# ========================================
@login_required
@require_POST
def favorite_toggle(request, slug):
    """إضافة/إزالة من المفضلة"""
    business = get_object_or_404(Business, slug=slug)
    
    favorite, created = Favorite.objects.get_or_create(
        user=request.user,
        business=business
    )
    
    if not created:
        favorite.delete()
        message = 'Removed from favorites'
        is_favorited = False
    else:
        message = 'Added to favorites'
        is_favorited = True
    
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return JsonResponse({
            'success': True,
            'message': message,
            'is_favorited': is_favorited
        })
    
    messages.success(request, message)
    return redirect('directory:business_detail', slug=slug)


# ========================================
# AJAX Endpoints
# ========================================
@require_POST
def increment_view(request, slug):
    """زيادة عداد المشاهدات"""
    business = get_object_or_404(Business, slug=slug)
    business.increment_view_count()
    
    return JsonResponse({
        'success': True,
        'view_count': business.view_count
    })


@require_POST
def increment_click(request, slug):
    """زيادة عداد النقرات"""
    business = get_object_or_404(Business, slug=slug)
    business.increment_click_count()
    
    return JsonResponse({
        'success': True,
        'click_count': business.click_count
    })


# ========================================
# Search View
# ========================================
def business_search(request):
    """بحث موحد في المنتجات والخدمات والمحلات."""
    from apps.products.models import Product

    query = request.GET.get('q', '').strip()
    businesses = Business.objects.filter(
        is_active=True,
        is_verified=True
    ).select_related('category', 'district__city__governorate')

    products = Product.objects.none()
    if query:
        businesses = businesses.filter(
            Q(name_en__icontains=query) |
            Q(name_ar__icontains=query) |
            Q(description_en__icontains=query) |
            Q(description_ar__icontains=query) |
            Q(category__name_en__icontains=query) |
            Q(category__name_ar__icontains=query)
        ).distinct()

        products = Product.objects.filter(
            Q(name_en__icontains=query)
            | Q(name_ar__icontains=query)
            | Q(description_en__icontains=query)
            | Q(description_ar__icontains=query)
            | Q(business__name_en__icontains=query)
            | Q(business__name_ar__icontains=query)
            | Q(business__category__name_en__icontains=query)
            | Q(business__category__name_ar__icontains=query),
            is_available=True,
            business__is_active=True,
            business__is_verified=True,
        ).select_related(
            'business',
            'business__category',
            'business__district__city',
        ).prefetch_related('images').order_by('price', 'name_ar')[:24]

    # Pagination
    paginator = Paginator(businesses, 12)
    page = request.GET.get('page')
    businesses_page = paginator.get_page(page)
    
    context = {
        'businesses': businesses_page,
        'products': products,
        'query': query,
        'business_count': paginator.count,
        'product_count': len(products),
        'total_results': paginator.count + len(products),
        'page_title': f'Search: {query}' if query else 'Search',
    }
    
    return render(request, 'directory/business_search.html', context)


def map_view(request):
    businesses = Business.objects.filter(
        is_active=True,
        is_verified=True,
        latitude__isnull=False,
        longitude__isnull=False
    ).select_related(
        'category',
        'district__city__governorate'
    )

    businesses_data = []
    for b in businesses:
        businesses_data.append({
            'id': b.id,
            'name_en': b.name_en,
            'name_ar': b.name_ar,
            'slug': b.slug,
            'latitude': float(b.latitude),
            'longitude': float(b.longitude),
            'logo': b.logo.url if b.logo else '',
            'business_type': b.business_type,
            'category_name_en': b.category.name_en,
            'category_name_ar': b.category.name_ar,
            'category_icon': b.category.icon if hasattr(b.category, 'icon') else '',
            'district_name_en': b.district.name_en,
            'district_name_ar': b.district.name_ar,
            'city_name_en': b.district.city.name_en,
            'city_name_ar': b.district.city.name_ar,
            'governorate_name_en': b.district.city.governorate.name_en,
            'governorate_name_ar': b.district.city.governorate.name_ar,
            'phone': b.phone,
            'is_featured': b.is_featured,
        })

    categories = Category.objects.filter(
        is_active=True,
        parent__isnull=True
    ).order_by('order')

    governorates = Governorate.objects.filter(
        is_active=True
    ).order_by('order')

    context = {
        'businesses_json': json.dumps(businesses_data, ensure_ascii=False),
        'categories': categories,
        'governorates': governorates,
        'total_businesses': len(businesses_data),
    }

    return render(request, 'directory/map.html', context)


# ========================================
# Shops / Crafts / Services Views
# ========================================

def shops_list(request):
    """قائمة المحلات التجارية"""
    businesses = Business.objects.filter(
        is_active=True,
        business_type='shop'
    ).select_related('category', 'district__city__governorate')

    # Filters
    category_slug   = request.GET.get('category')
    governorate_slug = request.GET.get('governorate')
    city_slug       = request.GET.get('city')
    search          = request.GET.get('q')
    sort            = request.GET.get('sort', '-created_at')

    if category_slug:
        businesses = businesses.filter(category__slug=category_slug)
    if governorate_slug:
        businesses = businesses.filter(
            district__city__governorate__slug=governorate_slug)
    if city_slug:
        businesses = businesses.filter(district__city__slug=city_slug)
    if search:
        businesses = businesses.filter(
            Q(name_ar__icontains=search) |
            Q(name_en__icontains=search) |
            Q(description_ar__icontains=search)
        )

    allowed_sorts = ['-created_at', '-view_count', '-average_rating', 'name_ar']
    if sort in allowed_sorts:
        businesses = businesses.order_by(sort)
    else:
        businesses = businesses.order_by('-created_at')

    paginator = Paginator(businesses, 12)
    page_obj  = paginator.get_page(request.GET.get('page'))

    # Cities لو اختار محافظة
    cities = []
    if governorate_slug:
        from apps.directory.models.location import City
        gov = Governorate.objects.filter(slug=governorate_slug).first()
        if gov:
            cities = City.objects.filter(
                governorate=gov, is_active=True).order_by('name_ar')

    context = {
        'page_obj'    : page_obj,
        'total_count' : businesses.count(),
        'categories'  : Category.objects.filter(
            is_active=True, parent__isnull=True),
        'governorates': Governorate.objects.filter(is_active=True),
        'cities'      : cities,
    }
    return render(request, 'directory/shops/list.html', context)


def crafts_list(request):
    """قائمة الحرف والمهن"""
    businesses = Business.objects.filter(
        is_active=True,
        business_type='craft'
    ).select_related('category', 'district__city__governorate')

    category_slug    = request.GET.get('category')
    governorate_slug = request.GET.get('governorate')
    city_slug        = request.GET.get('city')
    search           = request.GET.get('q')
    sort             = request.GET.get('sort', '-created_at')

    if category_slug:
        businesses = businesses.filter(category__slug=category_slug)
    if governorate_slug:
        businesses = businesses.filter(
            district__city__governorate__slug=governorate_slug)
    if city_slug:
        businesses = businesses.filter(district__city__slug=city_slug)
    if search:
        businesses = businesses.filter(
            Q(name_ar__icontains=search) |
            Q(name_en__icontains=search) |
            Q(description_ar__icontains=search)
        )

    allowed_sorts = ['-created_at', '-view_count', '-average_rating', 'name_ar']
    if sort in allowed_sorts:
        businesses = businesses.order_by(sort)
    else:
        businesses = businesses.order_by('-created_at')

    paginator = Paginator(businesses, 12)
    page_obj  = paginator.get_page(request.GET.get('page'))

    cities = []
    if governorate_slug:
        from apps.directory.models.location import City
        gov = Governorate.objects.filter(slug=governorate_slug).first()
        if gov:
            cities = City.objects.filter(
                governorate=gov, is_active=True).order_by('name_ar')

    context = {
        'page_obj'    : page_obj,
        'total_count' : businesses.count(),
        'categories'  : Category.objects.filter(
            is_active=True, parent__isnull=True),
        'governorates': Governorate.objects.filter(is_active=True),
        'cities'      : cities,
    }
    return render(request, 'directory/crafts/list.html', context)


def services_list(request):
    """قائمة الخدمات العامة"""
    businesses = Business.objects.filter(
        is_active=True,
        business_type='public'
    ).select_related('category', 'district__city__governorate')

    governorate_slug = request.GET.get('governorate')
    city_slug        = request.GET.get('city')
    service_type     = request.GET.get('service_type')
    search           = request.GET.get('q')
    sort             = request.GET.get('sort', '-created_at')

    if governorate_slug:
        businesses = businesses.filter(
            district__city__governorate__slug=governorate_slug)
    if city_slug:
        businesses = businesses.filter(district__city__slug=city_slug)
    if service_type:
        businesses = businesses.filter(category__slug=service_type)
    if search:
        businesses = businesses.filter(
            Q(name_ar__icontains=search) |
            Q(name_en__icontains=search) |
            Q(description_ar__icontains=search)
        )

    allowed_sorts = ['-created_at', '-view_count', '-average_rating', 'name_ar']
    if sort in allowed_sorts:
        businesses = businesses.order_by(sort)
    else:
        businesses = businesses.order_by('-created_at')

    paginator = Paginator(businesses, 12)
    page_obj  = paginator.get_page(request.GET.get('page'))

    cities = []
    if governorate_slug:
        from apps.directory.models.location import City
        gov = Governorate.objects.filter(slug=governorate_slug).first()
        if gov:
            cities = City.objects.filter(
                governorate=gov, is_active=True).order_by('name_ar')

    context = {
        'page_obj'    : page_obj,
        'total_count' : businesses.count(),
        'governorates': Governorate.objects.filter(is_active=True),
        'cities'      : cities,
    }
    return render(request, 'directory/services/list.html', context)


def shop_detail(request, slug):
    """تفاصيل المحل"""
    business = get_object_or_404(
        Business.objects.select_related(
            'category', 'district__city__governorate', 'owner'
        ),
        slug=slug, business_type='shop'
    )
    business.increment_view_count()
    return _business_detail_context(
        request, business, 'directory/shops/detail.html')


def craft_detail(request, slug):
    """تفاصيل الحرفي"""
    business = get_object_or_404(
        Business.objects.select_related(
            'category', 'district__city__governorate', 'owner'
        ),
        slug=slug, business_type='craft'
    )
    business.increment_view_count()
    return _business_detail_context(
        request, business, 'directory/crafts/detail.html')


def service_detail(request, slug):
    """تفاصيل الخدمة العامة"""
    business = get_object_or_404(
        Business.objects.select_related(
            'category', 'district__city__governorate', 'owner'
        ),
        slug=slug, business_type='public'
    )
    business.increment_view_count()

    # خدمات مشابهة
    similar_services = Business.objects.filter(
        category=business.category,
        business_type='public',
        is_active=True
    ).exclude(id=business.id).order_by('-view_count')[:4]

    ctx = _get_detail_context(request, business)
    ctx['similar_services'] = similar_services
    return render(request, 'directory/services/detail.html', ctx)


# ========================================
# Helper مشترك للـ detail views
# ========================================
def _get_detail_context(request, business):
    from apps.products.models import Product
    from apps.reviews.models import Review
    from django.db.models import Avg

    images   = business.images.filter(is_active=True)
    products = Product.objects.filter(
        business=business, is_available=True
    ).order_by('-is_featured', 'order', '-created_at')

    reviews        = Review.objects.filter(
        business=business, is_approved=True
    ).select_related('user').order_by('-created_at')[:5]
    total_reviews  = Review.objects.filter(
        business=business, is_approved=True).count()
    avg            = Review.objects.filter(
        business=business, is_approved=True
    ).aggregate(Avg('rating'))['rating__avg']
    average_rating = round(avg, 1) if avg else 0

    is_favorited = False
    if request.user.is_authenticated:
        is_favorited = Favorite.objects.filter(
            user=request.user, business=business).exists()

    return {
        'business'      : business,
        'images'        : images,
        'products'      : products,
        'reviews'       : reviews,
        'average_rating': average_rating,
        'total_reviews' : total_reviews,
        'is_favorited'  : is_favorited,
        'business_lat'  : str(float(business.latitude))  if business.latitude  else None,
        'business_lng'  : str(float(business.longitude)) if business.longitude else None,
    }


def _business_detail_context(request, business, template):
    ctx = _get_detail_context(request, business)
    return render(request, template, ctx)
