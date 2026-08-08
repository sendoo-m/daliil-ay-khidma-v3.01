"""
Main Dashboard Views
"""
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.db.models import Count, Q, Avg, Sum
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django import forms
from apps.accounts.forms import ProfileUpdateForm as UserProfileForm

from apps.directory.models import Business
from apps.directory.models.location import District, Governorate, City
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.accounts.models import User
from apps.notifications.models import Notification
from apps.dashboard.forms import UserProfileForm

@login_required
def index(request):
    if request.user.is_staff or request.user.is_superuser:
        return redirect('dashboard:admin_home')
    businesses = Business.objects.filter(owner=request.user)
    if businesses.exists():
        return redirect('dashboard:owner_dashboard')
    messages.info(request, 'مرحباً! يمكنك إضافة محلك الأول من هنا.')
    return redirect('dashboard:business_create')

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
    governorate_id = request.GET.get('governorate_id')
    if not governorate_id:
        return JsonResponse({'results': []})
    districts = District.objects.filter(
        city__governorate_id=governorate_id,
        is_active=True,
    ).select_related('city').order_by('city__name_ar', 'name_ar')
    results = [
        {'id': district.id, 'text': f"{district.city.name_ar} - {district.name_ar}"}
        for district in districts
    ]
    return JsonResponse({'results': results})

@login_required
def profile(request):
    return render(request, 'dashboard/profile.html', {'user': request.user})

@login_required
def settings(request):
    """إعدادات صاحب المحل — اسم، باسورد، لغة، ثيم."""
    if request.method == 'POST':
        form = UserProfileForm(request.POST, instance=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'تم تحديث إعداداتك بنجاح!')
            return redirect('dashboard:settings')
    else:
        form = UserProfileForm(instance=request.user)
    return render(request, 'dashboard/owner/settings.html', {
        'user': request.user,
        'form': form,
    })

@login_required
def notifications(request):
    """Owner notification center backed by the shared Notification model."""
    queryset = Notification.objects.filter(user=request.user).order_by('-created_at')
    notification_type = request.GET.get('type', '').strip()
    if notification_type in dict(Notification.TYPE_CHOICES):
        queryset = queryset.filter(notification_type=notification_type)
    read_state = request.GET.get('read', '').strip()
    if read_state == 'unread':
        queryset = queryset.filter(is_read=False)
    elif read_state == 'read':
        queryset = queryset.filter(is_read=True)

    return render(request, 'dashboard/notifications.html', {
        'notifications': queryset[:100],
        'unread_count': Notification.objects.filter(
            user=request.user,
            is_read=False,
        ).count(),
        'selected_type': notification_type,
        'selected_read': read_state,
    })

@login_required
def help_center(request):
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

def get_business_stats(user):
    businesses = Business.objects.filter(owner=user)
    return {
        'total': businesses.count(),
        'active': businesses.filter(is_active=True).count(),
        'verified': businesses.filter(is_verified=True).count(),
        'featured': businesses.filter(is_featured=True).count(),
    }

def get_product_stats(user):
    products = Product.objects.filter(business__owner=user)
    return {
        'total': products.count(),
        'available': products.filter(is_available=True).count(),
        'featured': products.filter(is_featured=True).count(),
    }

def get_deal_stats(user):
    deals = Deal.objects.filter(business__owner=user)
    return {
        'total': deals.count(),
        'active': deals.filter(is_active=True).count(),
        'featured': deals.filter(is_featured=True).count(),
    }

def get_review_stats(user):
    reviews = Review.objects.filter(business__owner=user)
    return {
        'total': reviews.count(),
        'approved': reviews.filter(is_approved=True).count(),
        'average_rating': reviews.aggregate(Avg('rating'))['rating__avg'] or 0,
    }
