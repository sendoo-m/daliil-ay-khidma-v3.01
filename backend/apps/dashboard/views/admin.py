"""
Admin Dashboard Views
====================
Complete administrative dashboard for managing the entire system
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth import get_user_model
from django.contrib import messages
from django.db.models import Count, Q, Avg, Sum
from django.views.decorators.http import require_POST
from django.utils import timezone
from datetime import timedelta

from apps.directory.models import (
    Governorate, City, District, Category,
    Business, BusinessImage
)
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.subscriptions.models import Subscription, SubscriptionPlan
from apps.dashboard.decorators import admin_required

User = get_user_model()


# ========================================
# Admin Dashboard Home
# ========================================
@admin_required
def admin_dashboard(request):
    """لوحة تحكم الإدارة الرئيسية"""
    
    # إحصائيات عامة
    total_users = User.objects.count()
    total_businesses = Business.objects.count()
    total_products = Product.objects.count()
    total_deals = Deal.objects.count()
    total_reviews = Review.objects.count()
    
    # إحصائيات المحلات حسب النوع
    shops_count = Business.objects.filter(business_type='shop').count()
    crafts_count = Business.objects.filter(business_type='craft').count()
    public_services_count = Business.objects.filter(business_type='public').count()
    
    # المحلات المنتظرة (بحاجة لموافقة)
    pending_businesses = Business.objects.filter(
        is_active=False,
        is_verified=False
    ).count()
    
    # التعليقات المنتظرة
    pending_reviews = Review.objects.filter(is_approved=False).count()
    
    # المستخدمين النشطين (آخر 30 يوم)
    thirty_days_ago = timezone.now() - timedelta(days=30)
    active_users = User.objects.filter(
        last_login__gte=thirty_days_ago
    ).count()
    
    # الاشتراكات النشطة
    active_subscriptions = Subscription.objects.filter(
        status='active'
    ).count()
    
    # آخر المحلات
    recent_businesses = Business.objects.all().select_related(
        'category', 'district', 'owner'
    ).order_by('-created_at')[:10]
    
    # آخر المستخدمين
    recent_users = User.objects.all().order_by('-date_joined')[:10]
    
    # أعلى التصنيفات (حسب عدد المحلات)
    top_categories = Category.objects.annotate(
        business_count=Count('businesses')
    ).order_by('-business_count')[:5]
    
    # إحصائيات المشاهدات
    total_views = Business.objects.aggregate(
        total=Sum('view_count')
    )['total'] or 0
    
    context = {
        'total_users': total_users,
        'total_businesses': total_businesses,
        'total_products': total_products,
        'total_deals': total_deals,
        'total_reviews': total_reviews,
        'shops_count': shops_count,
        'crafts_count': crafts_count,
        'public_services_count': public_services_count,
        'pending_businesses': pending_businesses,
        'pending_reviews': pending_reviews,
        'active_users': active_users,
        'active_subscriptions': active_subscriptions,
        'recent_businesses': recent_businesses,
        'recent_users': recent_users,
        'top_categories': top_categories,
        'total_views': total_views,
    }
    
    return render(request, 'dashboard/admin/dashboard.html', context)


# ========================================
# User Management
# ========================================
@admin_required
def admin_user_list(request):
    """قائمة المستخدمين"""
    users = User.objects.all().annotate(
        businesses_count=Count('businesses')
    ).order_by('-date_joined')
    
    # بحث
    search = request.GET.get('search')
    if search:
        users = users.filter(
            Q(email__icontains=search) |
            Q(first_name__icontains=search) |
            Q(last_name__icontains=search)
        )
    
    # فلتر حسب الحالة
    status = request.GET.get('status')
    if status == 'staff':
        users = users.filter(is_staff=True)
    elif status == 'active':
        users = users.filter(is_active=True)
    elif status == 'inactive':
        users = users.filter(is_active=False)
    
    context = {
        'users': users,
        'search': search,
        'status': status,
    }
    
    return render(request, 'dashboard/admin/user_list.html', context)


@admin_required
def admin_user_detail(request, pk):
    """تفاصيل المستخدم"""
    user = get_object_or_404(User, pk=pk)
    
    # إحصائيات المستخدم
    businesses = user.businesses.all()
    products = Product.objects.filter(business__owner=user)
    deals = Deal.objects.filter(business__owner=user)
    reviews_given = Review.objects.filter(user=user)
    
    context = {
        'user_obj': user,
        'businesses': businesses,
        'products_count': products.count(),
        'deals_count': deals.count(),
        'reviews_count': reviews_given.count(),
    }
    
    return render(request, 'dashboard/admin/user_detail.html', context)


@require_POST
@admin_required
def admin_user_toggle_active(request, pk):
    """تفعيل/تعطيل مستخدم"""
    user = get_object_or_404(User, pk=pk)
    user.is_active = not user.is_active
    user.save()
    
    status = 'تفعيل' if user.is_active else 'تعطيل'
    messages.success(request, f'تم {status} المستخدم بنجاح')
    return redirect('dashboard:admin_user_detail', pk=pk)


@require_POST
@admin_required
def admin_user_delete(request, pk):
    """حذف مستخدم"""
    user = get_object_or_404(User, pk=pk)
    
    if user.is_superuser:
        messages.error(request, 'لا يمكن حذف مدير النظام')
        return redirect('dashboard:admin_user_detail', pk=pk)
    
    user.delete()
    messages.success(request, 'تم حذف المستخدم بنجاح')
    return redirect('dashboard:admin_user_list')


# ========================================
# Business Management
# ========================================
@admin_required
def admin_business_list(request):
    """قائمة كل المحلات"""
    businesses = Business.objects.all().select_related(
        'category', 'district', 'owner'
    ).order_by('-created_at')
    
    # فلتر حسب النوع
    business_type = request.GET.get('type')
    if business_type:
        businesses = businesses.filter(business_type=business_type)
    
    # فلتر حسب الحالة
    status = request.GET.get('status')
    if status == 'pending':
        businesses = businesses.filter(is_active=False, is_verified=False)
    elif status == 'active':
        businesses = businesses.filter(is_active=True)
    elif status == 'verified':
        businesses = businesses.filter(is_verified=True)
    
    # بحث
    search = request.GET.get('search')
    if search:
        businesses = businesses.filter(
            Q(name_en__icontains=search) |
            Q(name_ar__icontains=search) |
            Q(owner__email__icontains=search)
        )
    
    context = {
        'businesses': businesses,
        'business_type': business_type,
        'status': status,
        'search': search,
    }
    
    return render(request, 'dashboard/admin/business_list.html', context)


@require_POST
@admin_required
def admin_business_verify(request, slug):
    """اعتماد محل"""
    business = get_object_or_404(Business, slug=slug)
    business.is_verified = True
    business.is_active = True
    business.save()
    
    messages.success(request, f'تم اعتماد محل {business.name_ar} بنجاح')
    return redirect('dashboard:admin_business_list')


@require_POST
@admin_required
def admin_business_toggle_active(request, slug):
    """تفعيل/تعطيل محل"""
    business = get_object_or_404(Business, slug=slug)
    business.is_active = not business.is_active
    business.save()
    
    status = 'تفعيل' if business.is_active else 'تعطيل'
    messages.success(request, f'تم {status} المحل بنجاح')
    return redirect('dashboard:admin_business_list')


@require_POST
@admin_required
def admin_business_delete(request, slug):
    """حذف محل"""
    business = get_object_or_404(Business, slug=slug)
    business.delete()
    
    messages.success(request, 'تم حذف المحل بنجاح')
    return redirect('dashboard:admin_business_list')


# ========================================
# Category Management
# ========================================
@admin_required
def admin_category_list(request):
    """قائمة التصنيفات"""
    categories = Category.objects.all().annotate(
        businesses_count=Count('businesses')
    ).order_by('order', 'name_en')
    
    context = {
        'categories': categories,
    }
    
    return render(request, 'dashboard/admin/category_list.html', context)


# ========================================
# Location Management
# ========================================
@admin_required
def admin_location_list(request):
    """قائمة المحافظات والمدن والأحياء"""
    governorates = Governorate.objects.all().annotate(
        cities_count=Count('cities')
    ).order_by('order', 'name_en')
    
    cities = City.objects.all().select_related('governorate').annotate(
        districts_count=Count('districts')
    ).order_by('governorate__order', 'order', 'name_en')
    
    districts = District.objects.all().select_related(
        'city__governorate'
    ).annotate(
        businesses_count=Count('businesses')
    ).order_by('city__governorate__order', 'city__order', 'order', 'name_en')
    
    context = {
        'governorates': governorates,
        'cities': cities,
        'districts': districts,
    }
    
    return render(request, 'dashboard/admin/location_list.html', context)


# ========================================
# Review Management
# ========================================
@admin_required
def admin_review_list(request):
    """قائمة التعليقات"""
    reviews = Review.objects.all().select_related(
        'business', 'user'
    ).order_by('-created_at')
    
    # فلتر حسب الحالة
    status = request.GET.get('status')
    if status == 'pending':
        reviews = reviews.filter(is_approved=False)
    elif status == 'approved':
        reviews = reviews.filter(is_approved=True)
    
    context = {
        'reviews': reviews,
        'status': status,
    }
    
    return render(request, 'dashboard/admin/review_list.html', context)


@require_POST
@admin_required
def admin_review_approve(request, pk):
    """اعتماد تعليق"""
    review = get_object_or_404(Review, pk=pk)
    review.is_approved = True
    review.save()
    
    messages.success(request, 'تم اعتماد التعليق بنجاح')
    return redirect('dashboard:admin_review_list')


@require_POST
@admin_required
def admin_review_delete(request, pk):
    """حذف تعليق"""
    review = get_object_or_404(Review, pk=pk)
    review.delete()
    
    messages.success(request, 'تم حذف التعليق بنجاح')
    return redirect('dashboard:admin_review_list')


# ========================================
# Product Management
# ========================================
@admin_required
def admin_product_list(request):
    """قائمة كل المنتجات"""
    products = Product.objects.all().select_related(
        'business__owner'
    ).order_by('-created_at')
    
    # فلتر حسب النوع
    product_type = request.GET.get('type')
    if product_type:
        products = products.filter(product_type=product_type)
    
    # بحث
    search = request.GET.get('search')
    if search:
        products = products.filter(
            Q(name_en__icontains=search) |
            Q(name_ar__icontains=search)
        )
    
    context = {
        'products': products,
        'product_type': product_type,
        'search': search,
    }
    
    return render(request, 'dashboard/admin/product_list.html', context)


@require_POST
@admin_required
def admin_product_delete(request, slug):
    """حذف منتج"""
    product = get_object_or_404(Product, slug=slug)
    product.delete()
    
    messages.success(request, 'تم حذف المنتج بنجاح')
    return redirect('dashboard:admin_product_list')


# ========================================
# Deal Management
# ========================================
@admin_required
def admin_deal_list(request):
    """قائمة كل العروض"""
    deals = Deal.objects.all().select_related(
        'business__owner'
    ).order_by('-created_at')
    
    context = {
        'deals': deals,
    }
    
    return render(request, 'dashboard/admin/deal_list.html', context)


@require_POST
@admin_required
def admin_deal_toggle_featured(request, slug):
    """تمييز/إلغاء تمييز عرض"""
    deal = get_object_or_404(Deal, slug=slug)
    deal.is_featured = not deal.is_featured
    deal.save()
    
    status = 'تمييز' if deal.is_featured else 'إلغاء تمييز'
    messages.success(request, f'تم {status} العرض بنجاح')
    return redirect('dashboard:admin_deal_list')


@require_POST
@admin_required
def admin_deal_delete(request, slug):
    """حذف عرض"""
    deal = get_object_or_404(Deal, slug=slug)
    deal.delete()
    
    messages.success(request, 'تم حذف العرض بنجاح')
    return redirect('dashboard:admin_deal_list')
