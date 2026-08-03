# apps/dashboard/api/permissions.py

from rest_framework.permissions import BasePermission


class IsAdminDashboard(BasePermission):
    """
    فقط الـ staff أو superuser
    """
    message = 'ليس لديك صلاحية الوصول للوحة الإدارة'

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (request.user.is_staff or request.user.is_superuser)
        )


class IsBusinessOwner(BasePermission):
    """
    فقط أصحاب المحلات
    """
    message = 'ليس لديك صلاحية الوصول للوحة صاحب المحل'

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user and
            user.is_authenticated and
            not user.is_staff and
            (
                getattr(user, 'is_business_owner', False) or
                user.businesses.exists()
            )
        )


class IsOwnerOfBusiness(BasePermission):
    """
    فقط صاحب المحل نفسه (object-level)
    """
    message = 'هذا المحل لا ينتمي إليك'

    def has_object_permission(self, request, view, obj):
        return obj.owner == request.user
