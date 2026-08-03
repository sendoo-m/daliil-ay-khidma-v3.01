"""
Core Views
==========
Views للصفحات الأساسية
"""

from django.shortcuts import render, redirect
from django.utils.translation import activate, get_language
from django.conf import settings
from django.db.models import Count, Q
from apps.directory.models import Business, Category, Governorate
from apps.deals.models import Deal


def home(request):
    """الصفحة الرئيسية"""
    
    # Featured Categories
    featured_categories = Category.objects.filter(
        is_active=True,
        parent__isnull=True
    ).annotate(
        business_count=Count('business', filter=Q(business__is_active=True))
    ).order_by('order')[:8]
    
    # Latest Businesses
    latest_businesses = Business.objects.filter(
        is_active=True,
        is_verified=True
    ).select_related('category', 'district__city__governorate').order_by('-created_at')[:8]
    
    # Featured Businesses
    featured_businesses = Business.objects.filter(
        is_active=True,
        is_featured=True,
        is_verified=True
    ).select_related('category', 'district__city__governorate')[:6]
    
    # Most Viewed
    most_viewed_businesses = Business.objects.filter(
        is_active=True,
        is_verified=True
    ).select_related('category', 'district__city__governorate').order_by('-view_count')[:6]
    
    # Governorates
    governorates = Governorate.objects.filter(
        is_active=True
    ).order_by('order')[:6]
    
    # Active Deals
    active_deals = Deal.objects.filter(
        is_active=True,
        business__is_active=True
    ).select_related('business').order_by('-created_at')[:6]
    
    # Statistics
    stats = {
        'total_businesses': Business.objects.filter(is_active=True).count(),
        'total_categories': Category.objects.filter(is_active=True).count(),
        'total_deals': Deal.objects.filter(is_active=True).count(),
        'verified_businesses': Business.objects.filter(is_active=True, is_verified=True).count(),
    }
    
    context = {
        'featured_categories': featured_categories,
        'latest_businesses': latest_businesses,
        'featured_businesses': featured_businesses,
        'most_viewed_businesses': most_viewed_businesses,
        'governorates': governorates,
        'active_deals': active_deals,
        'stats': stats,
    }
    
    return render(request, 'core/home.html', context)


def set_language(request):
    """تبديل اللغة"""
    language = request.GET.get('language', 'ar')
    
    # Validate language
    if language in [lang[0] for lang in settings.LANGUAGES]:
        activate(language)
        request.session[settings.LANGUAGE_COOKIE_NAME] = language
    
    # Get redirect URL
    next_url = request.GET.get('next')
    if not next_url:
        next_url = request.META.get('HTTP_REFERER', '/')
    
    response = redirect(next_url)
    response.set_cookie(
        settings.LANGUAGE_COOKIE_NAME,
        language,
        max_age=365 * 24 * 60 * 60  # 1 year
    )
    
    return response


def about(request):
    """صفحة عن الموقع"""
    return render(request, 'core/about.html')

def test_icons(request):
    return render(request, 'test_icons.html')

def privacy_policy(request):
    """سياسة الخصوصية"""
    return render(request, 'core/privacy_policy.html')


def terms_of_service(request):
    """شروط الخدمة"""
    return render(request, 'core/terms_of_service.html')


def support(request):
    """الدعم الفني"""
    if request.method == 'POST':
        # هنا تضيف منطق إرسال التذكرة لو عندك
        pass
    return render(request, 'core/support.html')

from django.contrib import messages

def contact(request):
    if request.method == 'POST':
        name    = request.POST.get('name', '')
        email   = request.POST.get('email', '')
        subject = request.POST.get('subject', '')
        message = request.POST.get('message', '')
        # أضف منطق الإرسال هنا (email أو حفظ في DB)
        messages.success(request,
            'تم إرسال رسالتك بنجاح! سنرد عليك قريباً.' if request.LANGUAGE_CODE == 'ar'
            else 'Your message was sent successfully! We\'ll reply soon.'
        )
        return redirect('core:contact')
    return render(request, 'core/contact.html')

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser, AllowAny
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from .models import SiteSettings
from .serializers import SiteSettingsSerializer

class SiteSettingsPublicView(APIView):
    """عامة — للفرونت والموبايل"""
    permission_classes = [AllowAny]

    def get(self, request):
        settings = SiteSettings.get_settings()
        serializer = SiteSettingsSerializer(settings)
        return Response(serializer.data)

class SiteSettingsAdminView(APIView):
    """للأدمن فقط — قراءة وتعديل"""
    permission_classes = [IsAdminUser]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        settings = SiteSettings.get_settings()
        return Response(SiteSettingsSerializer(settings).data)

    def patch(self, request):
        settings = SiteSettings.get_settings()
        serializer = SiteSettingsSerializer(settings, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)
