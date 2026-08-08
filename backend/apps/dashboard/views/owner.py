"""Owner dashboard home view."""

from django.contrib.auth.decorators import login_required
from django.db.models import Avg, Sum
from django.shortcuts import render
from django.utils import timezone

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product
from apps.reviews.models import Review


#: ما تعنيه كل خطوة للتاجر على الويب: العنوان والسبب والوجهة.
#: السبب مذكور لأن "أضف الموقع" أمر، بينما "من غير موقع محلك مش هيظهر
#: على الخريطة" سبب — والثاني يُنجَز والأول يُؤجَّل.
_SETUP_ACTIONS = {
    'select_plan': {
        'title': 'اختار خطتك',
        'why': 'الخطة بتحدد كام نشاط ومنتج تقدر تضيف.',
        'cta': 'شوف الخطط',
        'url_name': 'subscriptions:plans_list',
        'icon': 'bi-award',
    },
    'create_business': {
        'title': 'أنشئ نشاطك',
        'why': 'بعدها تقدر تضيف منتجاتك وعروضك.',
        'cta': 'ابدأ الإنشاء',
        'url_name': 'dashboard:business_create',
        'icon': 'bi-shop',
    },
    'submit_payment': {
        'title': 'ارفع بيانات الدفع',
        'why': 'بعد ما الإدارة تراجعها، اشتراكك بيتفعّل.',
        'cta': 'ارفع البيانات',
        'url_name': 'subscriptions:my_subscription',
        'icon': 'bi-receipt',
    },
    'await_admin_review': {
        'title': 'طلبك تحت المراجعة',
        'why': 'هنبعتلك إشعار أول ما يتفعّل. مفيش حاجة مطلوبة منك دلوقتي.',
        'cta': '',
        'url_name': '',
        'icon': 'bi-hourglass-split',
    },
    'add_logo': {
        'title': 'ارفع شعار المحل',
        'why': 'الشعار بيظهر جنب اسمك في نتايج البحث.',
        'cta': 'عدّل بيانات النشاط',
        'url_name': 'dashboard:business_list',
        'icon': 'bi-image',
    },
    'add_cover': {
        'title': 'ضيف صورة غلاف',
        'why': 'الغلاف أول حاجة الزبون بيشوفها في صفحة محلك.',
        'cta': 'عدّل بيانات النشاط',
        'url_name': 'dashboard:business_list',
        'icon': 'bi-images',
    },
    'add_location': {
        'title': 'حدد موقع المحل',
        'why': 'من غير موقع، محلك مش هيظهر على الخريطة ولا لما حد '
               'يدوّر على أقرب مكان ليه.',
        'cta': 'حدد الموقع',
        'url_name': 'dashboard:business_list',
        'icon': 'bi-geo-alt',
    },
    'add_working_hours': {
        'title': 'اكتب مواعيد العمل',
        'why': 'الزبون بيدوّر على اللي فاتح دلوقتي.',
        'cta': 'عدّل المواعيد',
        'url_name': 'dashboard:business_list',
        'icon': 'bi-clock',
    },
    'add_contact': {
        'title': 'ضيف رقم للتواصل',
        'why': 'التليفون والواتساب هما اللي بيوصلوا الزبون بيك.',
        'cta': 'ضيف الأرقام',
        'url_name': 'dashboard:business_list',
        'icon': 'bi-telephone',
    },
    'add_product': {
        'title': 'ضيف أول منتج أو خدمة',
        'why': 'المحلات اللي عندها منتجات بأسعار واضحة بتجيب زيارات أكتر.',
        'cta': 'ضيف منتج',
        'url_name': 'dashboard:product_create',
        'icon': 'bi-box-seam',
    },
    'add_deal': {
        'title': 'اعمل أول عرض',
        'why': 'العرض بيحطّ محلك في صفحة العروض.',
        'cta': 'اعمل عرض',
        'url_name': 'dashboard:deal_create',
        'icon': 'bi-tag',
    },
}


@login_required
def owner_dashboard(request):
    """Render the business-owner dashboard using the current data model."""
    businesses = Business.objects.filter(owner=request.user).select_related('category')

    total_businesses = businesses.count()
    active_businesses = businesses.filter(is_active=True).count()
    verified_businesses = businesses.filter(is_verified=True).count()

    total_products = Product.objects.filter(
        business__owner=request.user,
    ).count()

    active_deals = Deal.objects.filter(
        business__owner=request.user,
        start_date__lte=timezone.now(),
        end_date__gte=timezone.now(),
        is_active=True,
    ).count()

    totals = businesses.aggregate(
        total_views=Sum('view_count'),
        total_clicks=Sum('click_count'),
    )

    owner_reviews = Review.objects.filter(business__owner=request.user)
    pending_reviews = owner_reviews.filter(reply__isnull=True).count()
    avg_rating = owner_reviews.filter(is_approved=True).aggregate(
        average=Avg('rating'),
    )['average'] or 0

    # حالة رحلة التجهيز — نفس المحرك الذي يغذّي تطبيق التاجر.
    # لا نحسبها هنا مرة أخرى: نسبتان محسوبتان بمنطقين ستفترقان، ويصير
    # للتاجر رقمان مختلفان على سطحين لنفس النشاط.
    setup = None
    try:
        from apps.subscriptions.onboarding import (
            build_onboarding_state,
            get_or_create_onboarding,
        )

        setup = build_onboarding_state(get_or_create_onboarding(request.user))
    except Exception:  # noqa: BLE001
        # اللوحة تعمل بلا الرحلة. فشل هنا يخفي البانر ولا يُسقط الصفحة.
        import logging

        logging.getLogger('dashboard.owner').exception(
            'تعذّر بناء حالة التجهيز'
        )

    context = {
        'setup': setup,
        'setup_action': _SETUP_ACTIONS.get(
            (setup or {}).get('next_action', ''),
        ),
        'businesses': businesses.order_by('-created_at')[:5],
        'total_businesses': total_businesses,
        'active_businesses': active_businesses,
        'verified_businesses': verified_businesses,
        'total_products': total_products,
        'active_deals': active_deals,
        'total_views': totals['total_views'] or 0,
        'total_clicks': totals['total_clicks'] or 0,
        'pending_reviews': pending_reviews,
        'avg_rating': round(avg_rating, 1) if avg_rating else 0,
    }
    return render(request, 'dashboard/owner/index.html', context)
