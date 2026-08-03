"""
Main Dashboard Views
"""
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.db.models import Count, Q, Avg, Sum
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django import forms  # ← أضف
from apps.accounts.forms import ProfileUpdateForm as UserProfileForm

from apps.directory.models import Business
from apps.directory.models.location import District, Governorate, City
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.accounts.models import User
from apps.dashboard.forms import UserProfileForm

@login_required
def index(request):
    """
    Main dashboard index - redirects based on user role
    """
    if request.user.is_staff or request.user.is_superuser:
        # Admin user - redirect to admin dashboard
        return redirect('dashboard:admin_home')
    else:
        # Regular user - business owner
        businesses = Business.objects.filter(owner=request.user)
        
        if businesses.exists():
            # Has businesses - show owner dashboard
            return redirect('dashboard:owner_dashboard')
        else:
            # No businesses yet - encourage to create one
            messages.info(request, 'مرحباً! يمكنك إضافة محلك الأول من هنا.')
            return redirect('dashboard:business_create')

from django.http import JsonResponse
from apps.directory.models.location import City, District

@require_http_methods(["GET"])
def get_cities_by_governorate(request):
    gov_id = request.GET.get('governorate_id')
    cities = City.objects.filter(
        governorate_id=gov_id, is_active=True
    ).order_by('name_ar').values('id', 'name_ar')
    return JsonResponse({'cities': list(cities)})

def get_districts_by_city(request):
    city_id = request.GET.get('city_id')
    districts = District.objects.filter(
        city_id=city_id, is_active=True
    ).order_by('name_ar').values('id', 'name_ar')
    return JsonResponse({'districts': list(districts)})


@require_http_methods(["GET"])
def get_districts_by_governorate(request):
    """
    AJAX endpoint: Get all districts in a governorate (Legacy support)
    """
    governorate_id = request.GET.get('governorate_id')
    if not governorate_id:
        return JsonResponse({'results': []})
    
    districts = District.objects.filter(
        city__governorate_id=governorate_id, 
        is_active=True
    ).select_related('city').order_by('city__name_ar', 'name_ar')
    
    results = [{'id': district.id, 'text': f"{district.city.name_ar} - {district.name_ar}"} for district in districts]
    return JsonResponse({'results': results})

@login_required
def profile(request):
    """
    User profile page
    """
    context = {
        'user': request.user,
    }
    return render(request, 'dashboard/profile.html', context)

@login_required
def settings(request):
    """
    User settings page with profile update form
    """
    if request.method == 'POST':
        form = UserProfileForm(request.POST, instance=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'تم تحديث الإعدادات بنجاح!')
            return redirect('dashboard:settings')
    else:
        form = UserProfileForm(instance=request.user)
    
    context = {
        'user': request.user,
        'form': form,
    }
    return render(request, 'dashboard/admin/settings.html', context)

@login_required
def notifications(request):
    """
    User notifications page
    """
    context = {
        'notifications': [],
    }
    return render(request, 'dashboard/notifications.html', context)

@login_required
def help_center(request):
    """
    Help center page
    """
    context = {
        'faqs': [
            {
                'question': 'كيف أضيف محل جديد؟',
                'answer': 'اذهب إلى لوحة التحكم واضغط على "إضافة محل جديد" وقم بملء البيانات المطلوبة.'
            },
            {
                'question': 'كيف أعدل بيانات محلي؟',
                'answer': 'من قائمة محلاتي، اضغط على "تعديل" بجانب المحل المراد تعديله.'
            },
            {
                'question': 'كيف أضيف منتجات لمحلي؟',
                'answer': 'ادخل على صفحة تفاصيل المحل واضغط على "إضافة منتج".'
            },
        ]
    }
    return render(request, 'dashboard/help.html', context)

# Statistics helpers
def get_business_stats(user):
    """
    Get business statistics for user
    """
    businesses = Business.objects.filter(owner=user)
    
    return {
        'total': businesses.count(),
        'active': businesses.filter(is_active=True).count(),
        'verified': businesses.filter(is_verified=True).count(),
        'featured': businesses.filter(is_featured=True).count(),
    }

def get_product_stats(user):
    """
    Get product statistics for user's businesses
    """
    products = Product.objects.filter(business__owner=user)
    
    return {
        'total': products.count(),
        'available': products.filter(is_available=True).count(),
        'featured': products.filter(is_featured=True).count(),
    }

def get_deal_stats(user):
    """
    Get deal statistics for user's businesses
    """
    deals = Deal.objects.filter(business__owner=user)
    
    return {
        'total': deals.count(),
        'active': deals.filter(is_active=True).count(),
        'featured': deals.filter(is_featured=True).count(),
    }

def get_review_stats(user):
    """
    Get review statistics for user's businesses
    """
    reviews = Review.objects.filter(business__owner=user)
    
    return {
        'total': reviews.count(),
        'approved': reviews.filter(is_approved=True).count(),
        'average_rating': reviews.aggregate(Avg('rating'))['rating__avg'] or 0,
    }
