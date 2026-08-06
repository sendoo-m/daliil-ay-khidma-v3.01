"""
Dashboard — Permission Map
==========================
تربط كل مسار في لوحة الويب بالصلاحية التي يتطلّبها.

لماذا جدول واحد بدل ديكوريتور على كل view؟ لأن ٩١ ديكوريتورًا موزّعة على
اثني عشر ملفًا لا يمكن مراجعتها. هنا تقرأ الصفحة كلها في دقيقة وتعرف من
يقدر على ماذا — وهذا بالضبط السؤال الذي تريد أن تجيبه بسرعة لاحقًا.

والأهم: **الافتراضي منع**. مسار إداري غير مذكور هنا يُرفض. إضافة صفحة
جديدة ونسيان تسجيلها تُنتج 403 ظاهرة وقت الاختبار، لا ثغرة صامتة.
"""

from apps.administration.constants import Perm

#: مسارات لا تحتاج صلاحية — تخص المستخدم نفسه لا الإدارة.
PUBLIC_DASHBOARD_ROUTES = {
    'staff_login',
    'staff_logout',
    'index',
    'profile',
    'settings',
    'notifications',
    'help_center',
    'owner_dashboard',
    'ajax_cities',
    'ajax_districts',
    'ajax_districts_by_gov',
    # مسارات صاحب النشاط: الملكية تُفحص داخل الـview نفسه.
    'business_list', 'business_detail', 'business_create',
    'business_create_craft', 'business_update', 'business_delete',
    'product_list', 'product_create', 'product_update', 'product_delete',
    'deal_list', 'deal_create', 'deal_update', 'deal_delete',
    'review_list', 'review_reply', 'review_approve', 'review_reject',
}

#: مسارات تحتاج أن يكون المستخدم موظفًا، بلا صلاحية بعينها.
#: صفحة الهبوط من هذا النوع: الموظف يُحوَّل إليها فور الدخول، فاشتراط
#: صلاحية عليها يعني أن مشرف المحتوى يدخل ويصطدم بحائط قبل أن يرى شيئًا.
STAFF_ONLY_ROUTES = {
    'admin_home',
}

#: الصلاحية المطلوبة لكل مسار إداري.
DASHBOARD_PERMISSIONS = {
    # ── التقارير ──
    'admin_analytics': Perm.ANALYTICS_VIEW,
    'admin_reports': Perm.ANALYTICS_VIEW,
    'admin_ajax_districts': Perm.BUSINESS_VIEW,

    # ── الأنشطة ──
    'admin_businesses_list': Perm.BUSINESS_VIEW,
    'admin_business_detail': Perm.BUSINESS_VIEW,
    'admin_business_create': Perm.BUSINESS_CREATE,
    'admin_business_edit': Perm.BUSINESS_EDIT,
    'admin_business_delete': Perm.BUSINESS_DELETE,
    'admin_business_verify': Perm.BUSINESS_VERIFY,
    'admin_business_feature': Perm.BUSINESS_FEATURE,
    'admin_business_toggle': Perm.BUSINESS_SUSPEND,

    # ── التصنيفات ──
    'admin_categories_list': Perm.BUSINESS_VIEW,
    'admin_category_create': Perm.CATEGORY_MANAGE,
    'admin_category_edit': Perm.CATEGORY_MANAGE,
    'admin_category_delete': Perm.CATEGORY_MANAGE,

    # ── المواقع ──
    'admin_governorates_list': Perm.BUSINESS_VIEW,
    'admin_governorate_create': Perm.LOCATION_MANAGE,
    'admin_governorate_edit': Perm.LOCATION_MANAGE,
    'admin_governorate_delete': Perm.LOCATION_MANAGE,
    'admin_cities_list': Perm.BUSINESS_VIEW,
    'admin_city_create': Perm.LOCATION_MANAGE,
    'admin_city_edit': Perm.LOCATION_MANAGE,
    'admin_city_delete': Perm.LOCATION_MANAGE,
    'admin_districts_list': Perm.BUSINESS_VIEW,
    'admin_district_create': Perm.LOCATION_MANAGE,
    'admin_district_edit': Perm.LOCATION_MANAGE,
    'admin_district_delete': Perm.LOCATION_MANAGE,

    # ── المنتجات ──
    'admin_products_list': Perm.PRODUCT_VIEW,
    'admin_product_detail': Perm.PRODUCT_VIEW,
    'admin_product_create': Perm.PRODUCT_EDIT,
    'admin_product_create_for_business': Perm.PRODUCT_EDIT,
    'admin_product_edit': Perm.PRODUCT_EDIT,
    'admin_product_delete': Perm.PRODUCT_DELETE,
    'admin_product_toggle': Perm.PRODUCT_EDIT,
    'admin_product_feature': Perm.PRODUCT_EDIT,

    # ── العروض ──
    'admin_deals_list': Perm.DEAL_VIEW,
    'admin_deal_detail': Perm.DEAL_VIEW,
    'admin_deal_create': Perm.DEAL_EDIT,
    'admin_deal_create_for_business': Perm.DEAL_EDIT,
    'admin_deal_edit': Perm.DEAL_EDIT,
    'admin_deal_delete': Perm.DEAL_DELETE,
    'admin_deal_approve': Perm.DEAL_EDIT,
    'admin_deal_feature': Perm.DEAL_EDIT,

    # ── التقييمات ──
    'admin_reviews_list': Perm.REVIEW_VIEW,
    'admin_review_approve': Perm.REVIEW_MODERATE,
    'admin_review_reject': Perm.REVIEW_MODERATE,
    'admin_review_delete': Perm.REVIEW_DELETE,

    # ── النظام ──
    'admin_settings': Perm.SETTINGS_MANAGE,
    'admin_clear_cache': Perm.SETTINGS_MANAGE,
}

#: المسارات التي تغيّر بيانات — تُسجَّل في سجل العمليات.
#: القراءة لا تُسجَّل: سجل يمتلئ بـ"فتح صفحة" لا يُقرأ، والسؤال الحقيقي
#: دائمًا "مين غيّر ده؟" لا "مين شافه؟".
MUTATING_ROUTES = {
    name: action
    for name, action in {
        'admin_business_create': 'create',
        'admin_business_edit': 'update',
        'admin_business_delete': 'delete',
        'admin_business_verify': 'verify',
        'admin_business_feature': 'feature',
        'admin_business_toggle': 'suspend',
        'admin_category_create': 'create',
        'admin_category_edit': 'update',
        'admin_category_delete': 'delete',
        'admin_governorate_create': 'create',
        'admin_governorate_edit': 'update',
        'admin_governorate_delete': 'delete',
        'admin_city_create': 'create',
        'admin_city_edit': 'update',
        'admin_city_delete': 'delete',
        'admin_district_create': 'create',
        'admin_district_edit': 'update',
        'admin_district_delete': 'delete',
        'admin_product_create': 'create',
        'admin_product_create_for_business': 'create',
        'admin_product_edit': 'update',
        'admin_product_delete': 'delete',
        'admin_product_toggle': 'update',
        'admin_product_feature': 'feature',
        'admin_deal_create': 'create',
        'admin_deal_create_for_business': 'create',
        'admin_deal_edit': 'update',
        'admin_deal_delete': 'delete',
        'admin_deal_approve': 'approve',
        'admin_deal_feature': 'feature',
        'admin_review_approve': 'approve',
        'admin_review_reject': 'reject',
        'admin_review_delete': 'delete',
        'admin_settings': 'update',
        'admin_clear_cache': 'update',
    }.items()
}
