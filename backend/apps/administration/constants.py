"""
Administration — Permission Registry
====================================
مصدر الحقيقة الوحيد لصلاحيات لوحة الإدارة.

القاعدة المعمارية:
    الكود يتحقق من *صلاحية*، ولا يتحقق أبدًا من *دور*.

    صح:  request.user.admin_can(Perm.BUSINESS_VERIFY)
    غلط: request.user.role == 'moderator'

السبب: الأدوار تتغير مع نمو الفريق ويُنشئها المدير من التطبيق نفسه،
أما الصلاحيات فثابتة ومرتبطة بسلوك محدد في الكود. فصلهما يعني أن
إضافة دور جديد لا تتطلب أي تعديل على الكود ولا إعادة نشر.
"""

from django.utils.translation import gettext_lazy as _


class Perm:
    """أسماء الصلاحيات. `domain.action` — لا تُعاد تسميتها بعد النشر."""

    # ── الأنشطة والمحلات ──────────────────────────────
    BUSINESS_VIEW = 'business.view'
    BUSINESS_EDIT = 'business.edit'
    BUSINESS_CREATE = 'business.create'
    BUSINESS_VERIFY = 'business.verify'
    BUSINESS_FEATURE = 'business.feature'
    BUSINESS_SUSPEND = 'business.suspend'
    BUSINESS_DELETE = 'business.delete'

    # ── المنتجات والخدمات ─────────────────────────────
    PRODUCT_VIEW = 'product.view'
    PRODUCT_EDIT = 'product.edit'
    PRODUCT_DELETE = 'product.delete'

    # ── العروض ────────────────────────────────────────
    DEAL_VIEW = 'deal.view'
    DEAL_EDIT = 'deal.edit'
    DEAL_DELETE = 'deal.delete'

    # ── التقييمات ─────────────────────────────────────
    REVIEW_VIEW = 'review.view'
    REVIEW_MODERATE = 'review.moderate'
    REVIEW_DELETE = 'review.delete'

    # ── المستخدمون ────────────────────────────────────
    USER_VIEW = 'user.view'
    USER_EDIT = 'user.edit'
    USER_SUSPEND = 'user.suspend'
    USER_DELETE = 'user.delete'

    # ── الموظفون والأدوار ─────────────────────────────
    STAFF_VIEW = 'staff.view'
    STAFF_MANAGE = 'staff.manage'
    ROLE_MANAGE = 'role.manage'

    # ── التصنيفات والمواقع ────────────────────────────
    CATEGORY_MANAGE = 'category.manage'
    LOCATION_MANAGE = 'location.manage'

    # ── الاشتراكات ────────────────────────────────────
    SUBSCRIPTION_VIEW = 'subscription.view'
    SUBSCRIPTION_MANAGE = 'subscription.manage'

    # ── الإشعارات ─────────────────────────────────────
    NOTIFICATION_SEND = 'notification.send'

    # ── التقارير والنظام ──────────────────────────────
    ANALYTICS_VIEW = 'analytics.view'
    AUDIT_VIEW = 'audit.view'
    SETTINGS_MANAGE = 'settings.manage'
    APP_CONFIG_MANAGE = 'app_config.manage'


#: التسميات العربية والتجميع حسب النطاق.
#: تُستخدم لبناء شاشة "الأدوار" في تطبيق الإدارة تلقائيًا — أي صلاحية
#: تُضاف هنا تظهر في الواجهة فورًا بدون تعديل في Flutter.
PERMISSION_REGISTRY: dict[str, dict] = {
    'business': {
        'label': _('الأنشطة والمحلات'),
        'permissions': {
            Perm.BUSINESS_VIEW: _('عرض الأنشطة'),
            Perm.BUSINESS_CREATE: _('إضافة نشاط'),
            Perm.BUSINESS_EDIT: _('تعديل بيانات نشاط'),
            Perm.BUSINESS_VERIFY: _('توثيق نشاط'),
            Perm.BUSINESS_FEATURE: _('تمييز نشاط'),
            Perm.BUSINESS_SUSPEND: _('تعليق نشاط'),
            Perm.BUSINESS_DELETE: _('حذف نشاط'),
        },
    },
    'product': {
        'label': _('المنتجات والخدمات'),
        'permissions': {
            Perm.PRODUCT_VIEW: _('عرض المنتجات'),
            Perm.PRODUCT_EDIT: _('تعديل المنتجات'),
            Perm.PRODUCT_DELETE: _('حذف المنتجات'),
        },
    },
    'deal': {
        'label': _('العروض'),
        'permissions': {
            Perm.DEAL_VIEW: _('عرض العروض'),
            Perm.DEAL_EDIT: _('تعديل العروض'),
            Perm.DEAL_DELETE: _('حذف العروض'),
        },
    },
    'review': {
        'label': _('التقييمات'),
        'permissions': {
            Perm.REVIEW_VIEW: _('عرض التقييمات'),
            Perm.REVIEW_MODERATE: _('اعتماد ورفض التقييمات'),
            Perm.REVIEW_DELETE: _('حذف التقييمات'),
        },
    },
    'user': {
        'label': _('المستخدمون'),
        'permissions': {
            Perm.USER_VIEW: _('عرض المستخدمين'),
            Perm.USER_EDIT: _('تعديل بيانات مستخدم'),
            Perm.USER_SUSPEND: _('تعطيل حساب'),
            Perm.USER_DELETE: _('حذف حساب'),
        },
    },
    'staff': {
        'label': _('الموظفون والأدوار'),
        'permissions': {
            Perm.STAFF_VIEW: _('عرض الموظفين'),
            Perm.STAFF_MANAGE: _('إضافة وتعديل الموظفين'),
            Perm.ROLE_MANAGE: _('إدارة الأدوار والصلاحيات'),
        },
    },
    'catalog': {
        'label': _('التصنيفات والمواقع'),
        'permissions': {
            Perm.CATEGORY_MANAGE: _('إدارة التصنيفات'),
            Perm.LOCATION_MANAGE: _('إدارة المحافظات والمدن'),
        },
    },
    'subscription': {
        'label': _('الاشتراكات'),
        'permissions': {
            Perm.SUBSCRIPTION_VIEW: _('عرض الاشتراكات'),
            Perm.SUBSCRIPTION_MANAGE: _('إدارة الخطط والاشتراكات'),
        },
    },
    'system': {
        'label': _('النظام والتقارير'),
        'permissions': {
            Perm.NOTIFICATION_SEND: _('إرسال إشعارات'),
            Perm.ANALYTICS_VIEW: _('عرض التقارير'),
            Perm.AUDIT_VIEW: _('عرض سجل العمليات'),
            Perm.SETTINGS_MANAGE: _('إعدادات المنصة'),
            Perm.APP_CONFIG_MANAGE: _('إعدادات التطبيق'),
        },
    },
}


def all_permissions() -> list[str]:
    """كل الصلاحيات المعرّفة، مسطّحة."""
    return [
        code
        for group in PERMISSION_REGISTRY.values()
        for code in group['permissions']
    ]


def is_valid_permission(code: str) -> bool:
    return code in set(all_permissions())


# ── الأدوار الافتراضية ────────────────────────────────
# تُزرع مرة واحدة عبر `manage.py seed_roles`. بعدها يملكها المدير
# ويعدّلها من التطبيق. الكود لا يقرأ منها في وقت التشغيل.

DEFAULT_ROLES: dict[str, dict] = {
    'super_admin': {
        'name_ar': 'مدير عام',
        'name_en': 'Super Admin',
        'description': 'صلاحية كاملة على المنصة بما فيها إدارة الأدوار.',
        'permissions': '__all__',
        'is_protected': True,
    },
    'operations_manager': {
        'name_ar': 'مدير تشغيل',
        'name_en': 'Operations Manager',
        'description': 'يدير المحتوى والأنشطة والفريق، بدون صلاحيات النظام.',
        'permissions': [
            Perm.BUSINESS_VIEW, Perm.BUSINESS_CREATE, Perm.BUSINESS_EDIT,
            Perm.BUSINESS_VERIFY, Perm.BUSINESS_FEATURE, Perm.BUSINESS_SUSPEND,
            Perm.PRODUCT_VIEW, Perm.PRODUCT_EDIT,
            Perm.DEAL_VIEW, Perm.DEAL_EDIT,
            Perm.REVIEW_VIEW, Perm.REVIEW_MODERATE,
            Perm.USER_VIEW, Perm.USER_SUSPEND,
            Perm.STAFF_VIEW,
            Perm.CATEGORY_MANAGE, Perm.LOCATION_MANAGE,
            Perm.SUBSCRIPTION_VIEW,
            Perm.NOTIFICATION_SEND,
            Perm.ANALYTICS_VIEW, Perm.AUDIT_VIEW,
        ],
    },
    'business_reviewer': {
        'name_ar': 'مراجع أنشطة',
        'name_en': 'Business Reviewer',
        'description': 'يراجع طلبات الأنشطة ويوثقها. يُقيَّد عادةً بنطاق جغرافي.',
        'permissions': [
            Perm.BUSINESS_VIEW, Perm.BUSINESS_EDIT, Perm.BUSINESS_VERIFY,
            Perm.PRODUCT_VIEW,
            Perm.DEAL_VIEW,
            Perm.ANALYTICS_VIEW,
        ],
    },
    'content_moderator': {
        'name_ar': 'مشرف محتوى',
        'name_en': 'Content Moderator',
        'description': 'يراجع التقييمات والمحتوى المُبلَّغ عنه.',
        'permissions': [
            Perm.REVIEW_VIEW, Perm.REVIEW_MODERATE, Perm.REVIEW_DELETE,
            Perm.BUSINESS_VIEW,
            Perm.PRODUCT_VIEW,
            Perm.USER_VIEW,
        ],
    },
    'support_agent': {
        'name_ar': 'دعم فني',
        'name_en': 'Support Agent',
        'description': 'يساعد المستخدمين وأصحاب الأنشطة. قراءة فقط في الغالب.',
        'permissions': [
            Perm.USER_VIEW,
            Perm.BUSINESS_VIEW,
            Perm.PRODUCT_VIEW,
            Perm.DEAL_VIEW,
            Perm.REVIEW_VIEW,
            Perm.SUBSCRIPTION_VIEW,
        ],
    },
    'analyst': {
        'name_ar': 'محلل بيانات',
        'name_en': 'Analyst',
        'description': 'اطلاع على التقارير فقط، بدون أي تعديل.',
        'permissions': [
            Perm.ANALYTICS_VIEW,
            Perm.BUSINESS_VIEW,
            Perm.USER_VIEW,
            Perm.REVIEW_VIEW,
        ],
    },
}
