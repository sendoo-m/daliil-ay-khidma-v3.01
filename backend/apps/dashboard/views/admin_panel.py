"""
Admin Dashboard Views
=====================
لوحة تحكم الإدارة - CRUD كامل للنظام
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib import messages
from django.db.models import Count, Sum, Avg, Q
from django.core.paginator import Paginator
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta

from apps.directory.models import (
    Governorate, City, District, Category,
    Business, BusinessImage
)
from apps.products.models import Product, ProductImage
from apps.deals.models import Deal

User = get_user_model()


def is_admin(user):
    """Check if user is admin/staff"""
    return user.is_staff or user.is_superuser


# ==========================================
# Dashboard Home
# ==========================================
@login_required
@user_passes_test(is_admin)
def admin_dashboard(request):
    """الصفحة الرئيسية للوحة الإدارة"""
    
    # Overall statistics
    total_users = User.objects.count()
    total_businesses = Business.objects.count()
    total_products = Product.objects.count()
    total_deals = Deal.objects.count()
    
    # Active statistics
    active_businesses = Business.objects.filter(is_active=True).count()
    verified_businesses = Business.objects.filter(is_verified=True).count()
    active_deals = Deal.objects.filter(
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now(),
        is_active=True
    ).count()
    
    # Recent activity
    recent_businesses = Business.objects.order_by('-created_at')[:5]
    recent_users = User.objects.order_by('-date_joined')[:5]
    recent_products = Product.objects.order_by('-created_at')[:5]
    
    # Pending verifications
    pending_businesses = Business.objects.filter(
        is_verified=False,
        is_active=True
    ).count()
    
    # Reviews statistics
    try:
        from apps.reviews.models import Review
        pending_reviews = Review.objects.filter(is_approved=False).count()
        total_reviews = Review.objects.count()
    except ImportError:
        pending_reviews = 0
        total_reviews = 0
    
    # Location statistics
    total_governorates = Governorate.objects.count()
    total_cities = City.objects.count()
    total_districts = District.objects.count()
    total_categories = Category.objects.count()
    
    context = {
        'total_users': total_users,
        'total_businesses': total_businesses,
        'total_products': total_products,
        'total_deals': total_deals,
        'active_businesses': active_businesses,
        'verified_businesses': verified_businesses,
        'active_deals': active_deals,
        'pending_businesses': pending_businesses,
        'pending_reviews': pending_reviews,
        'total_reviews': total_reviews,
        'total_governorates': total_governorates,
        'total_cities': total_cities,
        'total_districts': total_districts,
        'total_categories': total_categories,
        'recent_businesses': recent_businesses,
        'recent_users': recent_users,
        'recent_products': recent_products,
    }
    
    return render(request, 'dashboard/admin/index.html', context)


# ==========================================
# User Management
# ==========================================
@login_required
@user_passes_test(is_admin)
def user_list(request):
    """قائمة المستخدمين"""
    users = User.objects.all().order_by('-date_joined')
    
    # Search
    search = request.GET.get('search')
    if search:
        users = users.filter(
            Q(email__icontains=search) |
            Q(first_name__icontains=search) |
            Q(last_name__icontains=search)
        )
    
    # Filter by status
    status = request.GET.get('status')
    if status == 'active':
        users = users.filter(is_active=True)
    elif status == 'inactive':
        users = users.filter(is_active=False)
    elif status == 'staff':
        users = users.filter(is_staff=True)
    
    # Pagination
    paginator = Paginator(users, 20)
    page = request.GET.get('page')
    users = paginator.get_page(page)
    
    context = {
        'users': users,
        'search': search,
        'status': status,
    }
    return render(request, 'dashboard/admin/users/list.html', context)


@login_required
@user_passes_test(is_admin)
def user_create(request):
    """إضافة مستخدم جديد"""
    if request.method == 'POST':
        # Will be implemented with forms
        messages.success(request, 'تم إضافة المستخدم بنجاح!')
        return redirect('dashboard:admin:user_list')
    
    return render(request, 'dashboard/admin/users/create.html')


@login_required
@user_passes_test(is_admin)
def user_edit(request, pk):
    """تعديل مستخدم"""
    user = get_object_or_404(User, pk=pk)
    
    if request.method == 'POST':
        # Will be implemented with forms
        messages.success(request, 'تم تحديث المستخدم بنجاح!')
        return redirect('dashboard:admin:user_list')
    
    context = {'user_obj': user}
    return render(request, 'dashboard/admin/users/edit.html', context)


@login_required
@user_passes_test(is_admin)
def user_delete(request, pk):
    """حذف مستخدم"""
    user = get_object_or_404(User, pk=pk)
    
    # Prevent deleting yourself
    if user == request.user:
        messages.error(request, 'لا يمكنك حذف حسابك الخاص!')
        return redirect('dashboard:admin:user_list')
    
    if request.method == 'POST':
        user.delete()
        messages.success(request, 'تم حذف المستخدم بنجاح!')
        return redirect('dashboard:admin:user_list')
    
    context = {'user_obj': user}
    return render(request, 'dashboard/admin/users/delete.html', context)


# ==========================================
# Business Management (Admin)
# ==========================================
@login_required
@user_passes_test(is_admin)
def admin_business_list(request):
    """قائمة جميع المحلات"""
    businesses = Business.objects.select_related(
        'owner', 'category', 'district'
    ).order_by('-created_at')
    
    # Search
    search = request.GET.get('search')
    if search:
        businesses = businesses.filter(
            Q(name_en__icontains=search) |
            Q(name_ar__icontains=search) |
            Q(owner__email__icontains=search)
        )
    
    # Filters
    status = request.GET.get('status')
    if status == 'active':
        businesses = businesses.filter(is_active=True)
    elif status == 'inactive':
        businesses = businesses.filter(is_active=False)
    elif status == 'verified':
        businesses = businesses.filter(is_verified=True)
    elif status == 'pending':
        businesses = businesses.filter(is_verified=False)
    
    business_type = request.GET.get('type')
    if business_type:
        businesses = businesses.filter(business_type=business_type)
    
    # Pagination
    paginator = Paginator(businesses, 20)
    page = request.GET.get('page')
    businesses = paginator.get_page(page)
    
    context = {
        'businesses': businesses,
        'search': search,
        'status': status,
        'business_type': business_type,
    }
    return render(request, 'dashboard/admin/businesses/list.html', context)


@login_required
@user_passes_test(is_admin)
def admin_business_edit(request, slug):
    """تعديل محل (إداري)"""
    business = get_object_or_404(Business, slug=slug)
    
    if request.method == 'POST':
        # Will be implemented with forms
        messages.success(request, 'تم تحديث المحل بنجاح!')
        return redirect('dashboard:admin:business_list')
    
    context = {'business': business}
    return render(request, 'dashboard/admin/businesses/edit.html', context)


@login_required
@user_passes_test(is_admin)
def admin_business_verify(request, slug):
    """اعتماد محل"""
    business = get_object_or_404(Business, slug=slug)
    
    if request.method == 'POST':
        business.is_verified = True
        business.verified_at = timezone.now()
        business.save()
        messages.success(request, f'تم اعتماد {business.name_ar} بنجاح!')
        return redirect('dashboard:admin:business_list')
    
    context = {'business': business}
    return render(request, 'dashboard/admin/businesses/verify.html', context)


# ==========================================
# Product Management (Admin)
# ==========================================
@login_required
@user_passes_test(is_admin)
def admin_product_list(request):
    """قائمة جميع المنتجات"""
    products = Product.objects.select_related(
        'business', 'category'
    ).order_by('-created_at')
    
    # Search
    search = request.GET.get('search')
    if search:
        products = products.filter(
            Q(name_en__icontains=search) |
            Q(name_ar__icontains=search)
        )
    
    # Filters
    product_type = request.GET.get('type')
    if product_type:
        products = products.filter(product_type=product_type)
    
    # Pagination
    paginator = Paginator(products, 20)
    page = request.GET.get('page')
    products = paginator.get_page(page)
    
    context = {
        'products': products,
        'search': search,
        'product_type': product_type,
    }
    return render(request, 'dashboard/admin/products/list.html', context)


# ==========================================
# Location Management (Admin)
# ==========================================
@login_required
@user_passes_test(is_admin)
def governorate_list(request):
    """قائمة المحافظات"""
    governorates = Governorate.objects.annotate(
        cities_count=Count('cities')
    ).order_by('order', 'name_en')
    
    context = {'governorates': governorates}
    return render(request, 'dashboard/admin/locations/governorates.html', context)


@login_required
@user_passes_test(is_admin)
def city_list(request):
    """قائمة المدن"""
    cities = City.objects.select_related('governorate').annotate(
        districts_count=Count('districts')
    ).order_by('governorate__order', 'order', 'name_en')
    
    context = {'cities': cities}
    return render(request, 'dashboard/admin/locations/cities.html', context)


@login_required
@user_passes_test(is_admin)
def district_list(request):
    """قائمة الأحياء"""
    districts = District.objects.select_related(
        'city__governorate'
    ).annotate(
        businesses_count=Count('businesses')
    ).order_by('city__governorate__order', 'city__order', 'order', 'name_en')
    
    # Filter by city
    city_id = request.GET.get('city')
    if city_id:
        districts = districts.filter(city_id=city_id)
    
    # Pagination
    paginator = Paginator(districts, 50)
    page = request.GET.get('page')
    districts = paginator.get_page(page)
    
    # Get all cities for filter
    cities = City.objects.all().order_by('name_en')
    
    context = {
        'districts': districts,
        'cities': cities,
        'selected_city': city_id,
    }
    return render(request, 'dashboard/admin/locations/districts.html', context)


# ==========================================
# Category Management (Admin)
# ==========================================
@login_required
@user_passes_test(is_admin)
def category_list(request):
    """قائمة التصنيفات"""
    categories = Category.objects.annotate(
        businesses_count=Count('businesses')
    ).order_by('order', 'name_en')
    
    context = {'categories': categories}
    return render(request, 'dashboard/admin/categories/list.html', context)


# ==========================================
# Deal Management (Admin)
# ==========================================
@login_required
@user_passes_test(is_admin)
def admin_deal_list(request):
    """قائمة جميع العروض"""
    deals = Deal.objects.select_related('business').order_by('-created_at')
    
    # Filters
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
    paginator = Paginator(deals, 20)
    page = request.GET.get('page')
    deals = paginator.get_page(page)
    
    context = {
        'deals': deals,
        'status': status,
    }
    return render(request, 'dashboard/admin/deals/list.html', context)
