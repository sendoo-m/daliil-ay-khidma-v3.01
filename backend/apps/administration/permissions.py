"""
Administration — Permissions
============================
طبقة التحقق من الصلاحيات لطلبات الـAPI.

الاستخدام في ViewSet:

    class AdminBusinessViewSet(AdminModelViewSet):
        required_permissions = {
            'list':     Perm.BUSINESS_VIEW,
            'retrieve': Perm.BUSINESS_VIEW,
            'create':   Perm.BUSINESS_CREATE,
            'update':   Perm.BUSINESS_EDIT,
            'destroy':  Perm.BUSINESS_DELETE,
            'verify':   Perm.BUSINESS_VERIFY,
        }

القاعدة الحاسمة: **الافتراضي هو المنع**. أي action غير مذكور في
`required_permissions` يُرفض. إضافة endpoint جديد ونسيان تسجيل صلاحيته
تُنتج 403 وليس ثغرة.
"""

from rest_framework import permissions

from .models import StaffProfile


def get_staff_profile(user) -> StaffProfile | None:
    """يُرجع ملف الموظف النشط، أو None."""
    if not user or not user.is_authenticated:
        return None
    profile = getattr(user, 'staff_profile', None)
    if profile is None or not profile.is_active:
        return None
    return profile


def user_permissions(user) -> set[str]:
    """
    كل صلاحيات المستخدم الإدارية.

    `is_superuser` في Django يتجاوز كل شيء — هذا مقصود، فهو مسار
    الطوارئ لاستعادة الوصول لو أخطأ أحدهم في ضبط الأدوار.
    """
    if not user or not user.is_authenticated:
        return set()

    if user.is_superuser:
        from .constants import all_permissions
        return set(all_permissions())

    profile = get_staff_profile(user)
    return profile.permissions if profile else set()


def user_can(user, code: str) -> bool:
    return code in user_permissions(user)


class IsAdminPanelUser(permissions.BasePermission):
    """بوابة الدخول للوحة: موظف نشط أو superuser."""

    message = 'هذا الحساب لا يملك صلاحية الدخول للوحة الإدارة.'

    def has_permission(self, request, view) -> bool:
        user = request.user
        if not user or not user.is_authenticated or not user.is_active:
            return False
        return bool(user.is_superuser or get_staff_profile(user))


class HasActionPermission(permissions.BasePermission):
    """
    يتحقق من الصلاحية المطلوبة للـaction الحالي.

    يقرأ `view.required_permissions`. الافتراضي منع.
    """

    message = 'ليس لديك صلاحية تنفيذ هذه العملية.'

    def has_permission(self, request, view) -> bool:
        user = request.user
        if user and user.is_superuser:
            return True

        required = getattr(view, 'required_permissions', None)
        if not required:
            return False  # deny by default

        action = getattr(view, 'action', None)
        if action is None:
            return False

        needed = required.get(action)
        if needed is None:
            return False  # action غير مسجَّل → منع

        if isinstance(needed, (list, tuple, set)):
            return bool(user_permissions(user).intersection(needed))
        return user_can(user, needed)


class GovernorateScopedMixin:
    """
    يقيّد الـqueryset بالنطاق الجغرافي للموظف.

    عرّف `scope_lookup` بالمسار من الموديل إلى Governorate، مثلًا:

        scope_lookup = 'governorate'                  # Business
        scope_lookup = 'business__governorate'        # Product / Deal / Review

    اترك `scope_lookup = None` للموارد غير الجغرافية (التصنيفات مثلًا).
    """

    scope_lookup: str | None = None

    def get_queryset(self):
        queryset = super().get_queryset()

        if self.scope_lookup is None:
            return queryset

        user = self.request.user
        if user.is_superuser:
            return queryset

        profile = get_staff_profile(user)
        if profile is None:
            return queryset.none()

        allowed = profile.scope_governorate_ids()
        if allowed is None:  # نطاق عام
            return queryset

        return queryset.filter(**{f'{self.scope_lookup}__in': allowed})

    def is_within_scope(self, obj) -> bool:
        """فحص صريح قبل تنفيذ عملية على كائن بعينه."""
        if self.scope_lookup is None or self.request.user.is_superuser:
            return True

        profile = get_staff_profile(self.request.user)
        if profile is None:
            return False

        allowed = profile.scope_governorate_ids()
        if allowed is None:
            return True

        target = obj
        for part in self.scope_lookup.split('__'):
            target = getattr(target, part, None)
            if target is None:
                return False
        return getattr(target, 'id', None) in allowed
