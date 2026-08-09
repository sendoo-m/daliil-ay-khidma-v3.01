"""
Admin Dashboard Views
=====================
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib import messages
from django.db.models import Count, Sum, Avg, Q
from django.utils import timezone
from django.core.paginator import Paginator
from datetime import timedelta

from apps.accounts.models import User
from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.categories.models import Category
from apps.directory.models.location import Governorate, City, District
from django.db import models


# ========================================
# ADMIN DASHBOARD HOME
# ========================================
@staff_member_required
def admin_dashboard_home(request):
    today       = timezone.now()
    last_7_days = today - timedelta(days=7)

    stats = {
        'total_users':          User.objects.count(),
        'active_users':         User.objects.filter(is_active=True).count(),
        'new_users_today':      User.objects.filter(date_joined__date=today.date()).count(),
        'new_users_week':       User.objects.filter(date_joined__gte=last_7_days).count(),

        'total_businesses':     Business.objects.count(),
        'verified_businesses':  Business.objects.filter(is_verified=True).count(),
        'pending_verification': Business.objects.filter(is_verified=False, is_active=True).count(),
        'new_businesses_week':  Business.objects.filter(created_at__gte=last_7_days).count(),

        'total_products':       Product.objects.count(),
        'active_products':      Product.objects.filter(is_available=True).count(),
        'featured_products':    Product.objects.filter(is_featured=True).count(),
        'new_products_week':    Product.objects.filter(created_at__gte=last_7_days).count(),

        'total_deals':          Deal.objects.count(),
        'active_deals':         Deal.objects.filter(
            start_date__lte=today, end_date__gte=today, is_active=True
        ).count(),
        'total_deal_claims':    Deal.objects.aggregate(
            Sum('current_uses'))['current_uses__sum'] or 0,

        'total_reviews':        Review.objects.count(),
        'pending_reviews':      Review.objects.filter(is_approved=False).count(),
        'average_rating':       Review.objects.filter(is_approved=True).aggregate(
            Avg('rating'))['rating__avg'] or 0,
        'new_reviews_week':     Review.objects.filter(created_at__gte=last_7_days).count(),

        'total_views':          Business.objects.aggregate(
            Sum('view_count'))['view_count__sum'] or 0,
        'total_clicks':         Business.objects.aggregate(
            Sum('click_count'))['click_count__sum'] or 0,
    }

    recent_users       = User.objects.order_by('-date_joined')[:5]
    recent_businesses  = Business.objects.select_related(
        'owner', 'category').order_by('-created_at')[:5]
    pending_reviews    = Review.objects.filter(
        is_approved=False).select_related('business', 'user').order_by('-created_at')[:5]
    pending_businesses = Business.objects.filter(
        is_verified=False, is_active=True).select_related('owner', 'category')[:5]

    top_businesses = Business.objects.order_by('-view_count')[:5]
    top_categories = Category.objects.annotate(
        business_count=Count('business')
    ).order_by('-business_count')[:5]

    return render(request, 'dashboard/admin/home.html', {
        'stats': stats,
        'recent_users': recent_users,
        'recent_businesses': recent_businesses,
        'pending_reviews': pending_reviews,
        'pending_businesses': pending_businesses,
        'top_businesses': top_businesses,
        'top_categories': top_categories,
    })


# ========================================
# ANALYTICS & REPORTS
# ========================================
from django.db.models import Count, Avg
from django.db.models.functions import TruncMonth
import json


@staff_member_required
def admin_analytics(request):
    now      = timezone.now()
    year_ago = now - timezone.timedelta(days=365)

    stats = {
        'total_users':       User.objects.count(),
        'total_businesses':  Business.objects.count(),
        'total_products':    Product.objects.count(),
        'total_deals':       Deal.objects.count(),
        'active_businesses': Business.objects.filter(is_active=True).count(),
        'avg_rating':        Business.objects.aggregate(a=Avg('average_rating'))['a'] or 0,
    }

    users_monthly = (
        User.objects
        .filter(date_joined__gte=year_ago)
        .annotate(month=TruncMonth('date_joined'))
        .values('month').annotate(count=Count('id')).order_by('month')
    )
    users_chart = {
        'labels': [item['month'].strftime('%b %Y') for item in users_monthly],
        'data':   [item['count'] for item in users_monthly],
    }

    by_category = (
        Category.objects.annotate(count=Count('business'))
        .filter(count__gt=0).order_by('-count')[:8]
    )
    category_chart = {
        'labels': [c.name_ar for c in by_category],
        'data':   [c.count for c in by_category],
    }

    by_gov = (
        Governorate.objects
        .annotate(count=Count('cities__districts__business'))
        .filter(count__gt=0).order_by('-count')[:10]
    )
    gov_chart = {
        'labels': [g.name_ar for g in by_gov],
        'data':   [g.count for g in by_gov],
    }

    businesses_monthly = (
        Business.objects
        .filter(created_at__gte=year_ago)
        .annotate(month=TruncMonth('created_at'))
        .values('month').annotate(count=Count('id')).order_by('month')
    )
    businesses_chart = {
        'labels': [item['month'].strftime('%b %Y') for item in businesses_monthly],
        'data':   [item['count'] for item in businesses_monthly],
    }

    return render(request, 'dashboard/admin/analytics.html', {
        'stats':            stats,
        'users_chart':      json.dumps(users_chart,      ensure_ascii=False),
        'category_chart':   json.dumps(category_chart,   ensure_ascii=False),
        'gov_chart':        json.dumps(gov_chart,         ensure_ascii=False),
        'businesses_chart': json.dumps(businesses_chart, ensure_ascii=False),
    })


@staff_member_required
def admin_reports(request):
    return render(request, 'dashboard/admin/reports.html')


# ========================================
# USERS MANAGEMENT
# ========================================
@staff_member_required
def admin_users_list(request):
    users  = User.objects.all().order_by('-date_joined')
    search = request.GET.get('search', '')
    status = request.GET.get('status', '')

    if search:
        users = users.filter(
            Q(username__icontains=search) | Q(email__icontains=search) |
            Q(first_name__icontains=search) | Q(last_name__icontains=search)
        )
    if status == 'active':
        users = users.filter(is_active=True)
    elif status == 'inactive':
        users = users.filter(is_active=False)
    elif status == 'staff':
        users = users.filter(is_staff=True)

    paginator  = Paginator(users, 20)
    users_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/users_list.html', {
        'users': users_page, 'search': search, 'status': status,
    })


@staff_member_required
def admin_user_detail(request, user_id):
    user       = get_object_or_404(User, id=user_id)
    businesses = Business.objects.filter(owner=user)
    return render(request, 'dashboard/admin/user_detail.html', {
        'user_obj': user, 'businesses': businesses,
    })


@staff_member_required
def admin_user_delete(request, user_id):
    user = get_object_or_404(User, id=user_id)
    if request.method == 'POST':
        if user == request.user:
            messages.error(request, '❌ لا يمكنك حذف حسابك الخاص!')
            return redirect('dashboard:admin_user_detail', user_id=user_id)
        user.delete()
        messages.success(request, '✅ تم حذف المستخدم بنجاح')
        return redirect('dashboard:admin_users_list')
    return redirect('dashboard:admin_user_detail', user_id=user_id)


@staff_member_required
def admin_user_toggle_status(request, user_id):
    user = get_object_or_404(User, id=user_id)
    if user == request.user:
        messages.error(request, '❌ لا يمكنك تعطيل حسابك الخاص!')
        return redirect('dashboard:admin_user_detail', user_id=user_id)
    user.is_active = not user.is_active
    user.save()
    status = 'فعّال' if user.is_active else 'معطّل'
    messages.success(request, f'تم تغيير حالة المستخدم إلى {status}')
    return redirect('dashboard:admin_user_detail', user_id=user_id)


# ========================================
# BUSINESSES MANAGEMENT
# ========================================
@staff_member_required
def admin_businesses_list(request):
    businesses = Business.objects.select_related('owner', 'category').order_by('-created_at')
    search = request.GET.get('search', '')
    status = request.GET.get('status', '')
    btype  = request.GET.get('type', '')

    if search:
        businesses = businesses.filter(
            Q(name_ar__icontains=search) | Q(name_en__icontains=search) |
            Q(owner__username__icontains=search)
        )
    if status == 'verified':
        businesses = businesses.filter(is_verified=True)
    elif status == 'pending':
        businesses = businesses.filter(is_verified=False, is_active=True)
    elif status == 'inactive':
        businesses = businesses.filter(is_active=False)
    elif status == 'featured':
        businesses = businesses.filter(is_featured=True)
    if btype:
        businesses = businesses.filter(business_type=btype)

    paginator       = Paginator(businesses, 20)
    businesses_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/businesses_list.html', {
        'businesses': businesses_page,
        'search': search, 'status': status, 'business_type': btype,
    })


@staff_member_required
def admin_business_detail(request, business_id):
    business = get_object_or_404(Business, id=business_id)
    products = Product.objects.filter(business=business)
    reviews  = Review.objects.filter(business=business).select_related('user')[:10]
    return render(request, 'dashboard/admin/business_detail.html', {
        'business': business, 'products': products, 'reviews': reviews,
    })


@staff_member_required
def admin_business_verify(request, business_id):
    business = get_object_or_404(Business, id=business_id)
    business.is_verified = not business.is_verified
    business.save()
    status = 'مُوثّق' if business.is_verified else 'غير موثق'
    messages.success(request, f'تم تغيير حالة التوثيق إلى {status}')
    return redirect('dashboard:admin_business_detail', business_id=business_id)


@staff_member_required
def admin_business_feature(request, business_id):
    business = get_object_or_404(Business, id=business_id)
    business.is_featured = not business.is_featured
    business.save()
    status = 'مُبرَز' if business.is_featured else 'غير مبرز'
    messages.success(request, f'تم تغيير حالة الإبراز إلى {status}')
    return redirect('dashboard:admin_business_detail', business_id=business_id)


@staff_member_required
def admin_business_toggle_status(request, business_id):
    business = get_object_or_404(Business, id=business_id)
    business.is_active = not business.is_active
    business.save()
    status = 'فعّال' if business.is_active else 'معطّل'
    messages.success(request, f'تم تغيير حالة المحل إلى {status}')
    return redirect('dashboard:admin_business_detail', business_id=business_id)


@staff_member_required
def admin_business_delete(request, business_id):
    business = get_object_or_404(Business, id=business_id)
    if request.method == 'POST':
        business.delete()
        messages.success(request, '✅ تم حذف المحل بنجاح')
        return redirect('dashboard:admin_businesses_list')
    return redirect('dashboard:admin_business_detail', business_id=business_id)


# ========================================
# PRODUCTS MANAGEMENT
# ========================================
@staff_member_required
def admin_products_list(request):
    products = Product.objects.select_related('business').order_by('-created_at')
    search   = request.GET.get('search', '')
    ptype    = request.GET.get('type', '')

    if search:
        products = products.filter(
            Q(name_ar__icontains=search) | Q(name_en__icontains=search)
        )
    if ptype:
        products = products.filter(product_type=ptype)

    paginator     = Paginator(products, 20)
    products_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/products_list.html', {
        'products': products_page, 'search': search, 'product_type': ptype,
    })


@staff_member_required
def admin_product_detail(request, product_id):
    product = get_object_or_404(Product, id=product_id)
    return render(request, 'dashboard/admin/product_detail.html', {'product': product})


@staff_member_required
def admin_product_toggle_status(request, product_id):
    product = get_object_or_404(Product, id=product_id)
    product.is_available = not product.is_available
    product.save()
    messages.success(request, 'تم تغيير حالة المنتج')
    return redirect('dashboard:admin_product_detail', product_id=product_id)


@staff_member_required
def admin_product_feature(request, product_id):
    product = get_object_or_404(Product, id=product_id)
    product.is_featured = not product.is_featured
    product.save()
    messages.success(request, 'تم تغيير حالة الإبراز')
    return redirect('dashboard:admin_product_detail', product_id=product_id)


@staff_member_required
def admin_product_delete(request, product_id):
    product = get_object_or_404(Product, id=product_id)
    if request.method == 'POST':
        product.delete()
        messages.success(request, '✅ تم حذف المنتج')
        return redirect('dashboard:admin_products_list')
    return redirect('dashboard:admin_product_detail', product_id=product_id)


# ========================================
# DEALS MANAGEMENT
# ========================================
@staff_member_required
def admin_deals_list(request):
    deals  = Deal.objects.select_related('business').order_by('-created_at')
    status = request.GET.get('status', '')

    if status == 'active':
        deals = deals.filter(
            start_date__lte=timezone.now(),
            end_date__gte=timezone.now(),
            is_active=True
        )
    elif status == 'expired':
        deals = deals.filter(end_date__lt=timezone.now())
    elif status == 'inactive':
        deals = deals.filter(is_active=False)

    paginator  = Paginator(deals, 20)
    deals_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/deals_list.html', {
        'deals': deals_page, 'status': status,
    })


@staff_member_required
def admin_deal_detail(request, deal_id):
    deal = get_object_or_404(Deal, id=deal_id)
    return render(request, 'dashboard/admin/deal_detail.html', {'deal': deal})


@staff_member_required
def admin_deal_approve(request, deal_id):
    deal = get_object_or_404(Deal, id=deal_id)
    deal.is_active = not deal.is_active
    deal.save()
    messages.success(request, 'تم تغيير حالة العرض')
    return redirect('dashboard:admin_deal_detail', deal_id=deal_id)


@staff_member_required
def admin_deal_feature(request, deal_id):
    deal = get_object_or_404(Deal, id=deal_id)
    deal.is_featured = not deal.is_featured
    deal.save()
    messages.success(request, 'تم تغيير حالة الإبراز')
    return redirect('dashboard:admin_deal_detail', deal_id=deal_id)


@staff_member_required
def admin_deal_delete(request, deal_id):
    deal = get_object_or_404(Deal, id=deal_id)
    if request.method == 'POST':
        deal.delete()
        messages.success(request, '✅ تم حذف العرض')
        return redirect('dashboard:admin_deals_list')
    return redirect('dashboard:admin_deal_detail', deal_id=deal_id)


# ========================================
# REVIEWS MANAGEMENT
# ========================================
@staff_member_required
def admin_reviews_list(request):
    reviews = Review.objects.select_related('business', 'user').order_by('-created_at')
    status  = request.GET.get('status', '')

    if status == 'pending':
        reviews = reviews.filter(is_approved=False)
    elif status == 'approved':
        reviews = reviews.filter(is_approved=True)

    paginator    = Paginator(reviews, 20)
    reviews_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/reviews_list.html', {
        'reviews': reviews_page, 'status': status,
    })


@staff_member_required
def admin_review_approve(request, review_id):
    review = get_object_or_404(Review, id=review_id)
    review.is_approved = True
    review.save()
    messages.success(request, '✅ تم قبول التقييم')
    return redirect('dashboard:admin_reviews_list')


@staff_member_required
def admin_review_reject(request, review_id):
    review = get_object_or_404(Review, id=review_id)
    review.is_approved = False
    review.save()
    messages.success(request, 'تم رفض التقييم')
    return redirect('dashboard:admin_reviews_list')


@staff_member_required
def admin_review_delete(request, review_id):
    review = get_object_or_404(Review, id=review_id)
    if request.method == 'POST':
        review.delete()
        messages.success(request, '✅ تم حذف التقييم')
    return redirect('dashboard:admin_reviews_list')


# ========================================
# CATEGORIES MANAGEMENT
# ========================================
@staff_member_required
def admin_categories_list(request):
    search = request.GET.get('q', '').strip()

    categories = Category.objects.annotate(
        business_count=Count('business')
    ).order_by('order', 'name_ar')

    if search:
        categories = categories.filter(
            Q(name_ar__icontains=search) | Q(name_en__icontains=search)
        )

    paginator = Paginator(categories, 20)
    page      = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/categories_list.html', {
        'categories': page, 'page_obj': page, 'search': search,
    })


@staff_member_required
def admin_category_delete(request, category_id):
    category = get_object_or_404(Category, id=category_id)
    if request.method == 'POST':
        if category.business_set.exists():
            messages.error(request, '❌ لا يمكن حذف التصنيف لأنه يحتوي على محلات')
            return redirect('dashboard:admin_categories_list')
        category.delete()
        messages.success(request, '✅ تم حذف التصنيف')
    return redirect('dashboard:admin_categories_list')


# ========================================
# SYSTEM SETTINGS  →  /dashboard/admin/settings/
# ========================================
@staff_member_required
def admin_settings(request):
    """
    إعدادات النظام الكاملة — تحفظ كل الحقول في apps.core.models.SiteSettings.
    القالب يستخدم {{ settings.xxx }} لذا الـ context key هو 'settings'.
    """
    from apps.core.models import SiteSettings

    site = SiteSettings.get_settings()

    if request.method == 'POST':
        p = request.POST
        f = request.FILES

        # ── هوية الموقع ──────────────────────────────────────────
        site.site_name_ar        = p.get('site_name_ar', '').strip()
        site.site_name_en        = p.get('site_name_en', '').strip()
        site.site_description_ar = p.get('site_description_ar', '').strip()
        site.site_description_en = p.get('site_description_en', '').strip()

        # لوجو
        if p.get('delete_logo') and site.logo:
            site.logo.delete(save=False)
            site.logo = None
        elif 'logo' in f:
            site.logo = f['logo']

        # فافيكون
        if p.get('delete_favicon') and site.favicon:
            site.favicon.delete(save=False)
            site.favicon = None
        elif 'favicon' in f:
            site.favicon = f['favicon']

        # ── بيانات التواصل ────────────────────────────────────────
        site.contact_email = p.get('contact_email', '').strip()
        site.contact_phone = p.get('contact_phone', '').strip()
        site.address       = p.get('address', '').strip()

        # ── سوشيال ميديا ─────────────────────────────────────────
        site.facebook  = p.get('facebook',  '').strip()
        site.instagram = p.get('instagram', '').strip()
        site.twitter   = p.get('twitter',   '').strip()
        site.whatsapp  = p.get('whatsapp',  '').strip()
        site.youtube   = p.get('youtube',   '').strip()

        # ── روابط التطبيق ─────────────────────────────────────────
        site.ios_store_url     = p.get('ios_store_url',     '').strip()
        site.android_store_url = p.get('android_store_url', '').strip()

        # ── إعدادات تقنية ─────────────────────────────────────────
        try:
            site.results_per_page = int(p.get('results_per_page', 12))
        except (ValueError, TypeError):
            site.results_per_page = 12

        site.maintenance_mode        = 'maintenance_mode'        in p
        site.allow_registration      = 'allow_registration'      in p
        site.allow_reviews           = 'allow_reviews'           in p
        site.require_review_approval = 'require_review_approval' in p

        # ── SEO ───────────────────────────────────────────────────
        site.meta_description    = p.get('meta_description',    '').strip()
        site.meta_keywords       = p.get('meta_keywords',       '').strip()
        site.google_analytics_id = p.get('google_analytics_id', '').strip()
        site.google_maps_key     = p.get('google_maps_key',     '').strip()

        site.save()
        messages.success(request, '✅ تم حفظ الإعدادات بنجاح')
        return redirect('dashboard:admin_settings')

    # القالب يستخدم {{ settings.xxx }}
    return render(request, 'dashboard/admin/settings.html', {'settings': site})


@staff_member_required
def admin_clear_cache(request):
    from django.core.cache import cache
    cache.clear()
    messages.success(request, '✅ تم مسح الذاكرة المؤقتة بنجاح')
    return redirect('dashboard:admin_settings')
