"""Administration — Role / Staff / Audit endpoints."""

from django.db.models import Count
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from .constants import Perm
from .models import AuditLog, Role, StaffProfile
from .permissions import (
    HasActionPermission,
    IsAdminPanelUser,
    get_staff_profile,
    user_permissions,
)
from .serializers import (
    AuditLogSerializer,
    PermissionCatalogSerializer,
    RoleSerializer,
    StaffProfileSerializer,
)
from .viewsets import AdminModelViewSet, AdminReadOnlyViewSet


class AdminSessionView(APIView):
    """
    GET /api/v2/admin/session/

    أول نداء يقوم به تطبيق الإدارة بعد الدخول. يعيد هوية الموظف
    وصلاحياته ونطاقه، فيبني التطبيق قائمته وأزراره على أساسها بدل
    إظهار أزرار تفشل بـ403 عند الضغط.
    """

    permission_classes = [IsAdminPanelUser]

    def get(self, request):
        user = request.user
        profile = get_staff_profile(user)

        if profile is not None:
            profile.touch_login()

        return Response({
            'user': {
                'id': user.id,
                'username': user.username,
                'full_name': user.get_full_name() or user.username,
                'email': user.email,
                'is_superuser': user.is_superuser,
            },
            'role': {
                'id': profile.role_id,
                'slug': profile.role.slug,
                'name': profile.role.name_ar,
            } if profile else {'slug': 'superuser', 'name': 'مدير النظام'},
            'permissions': sorted(user_permissions(user)),
            'scope': {
                'is_global': profile.is_globally_scoped if profile else True,
                'governorates': [
                    {'id': g.id, 'name': g.name_ar}
                    for g in profile.governorates.all()
                ] if profile else [],
            },
        })


class PermissionCatalogView(APIView):
    """GET /api/v2/admin/permissions/ — كتالوج الصلاحيات لبناء شاشة الأدوار."""

    permission_classes = [IsAdminPanelUser]

    def get(self, request):
        return Response(PermissionCatalogSerializer.build())


class RoleViewSet(AdminModelViewSet):
    queryset = Role.objects.annotate(
        staff_count=Count('staff_members', distinct=True)
    ).order_by('name_ar')
    serializer_class = RoleSerializer
    scope_lookup = None

    required_permissions = {
        'list': [Perm.ROLE_MANAGE, Perm.STAFF_VIEW],
        'retrieve': [Perm.ROLE_MANAGE, Perm.STAFF_VIEW],
        'create': Perm.ROLE_MANAGE,
        'update': Perm.ROLE_MANAGE,
        'partial_update': Perm.ROLE_MANAGE,
        'destroy': Perm.ROLE_MANAGE,
    }
    search_fields = ['name_ar', 'name_en', 'slug']
    audited_fields = ['slug', 'name_ar', 'permissions', 'is_active']

    def perform_destroy(self, instance):
        if instance.is_protected:
            raise PermissionError('لا يمكن حذف دور محمي.')
        if instance.staff_members.exists():
            raise PermissionError(
                'لا يمكن حذف دور مرتبط بموظفين. انقلهم لدور آخر أولًا.'
            )
        super().perform_destroy(instance)


class StaffProfileViewSet(AdminModelViewSet):
    queryset = (
        StaffProfile.objects
        .select_related('user', 'role')
        .prefetch_related('governorates')
        .order_by('-created_at')
    )
    serializer_class = StaffProfileSerializer
    scope_lookup = None

    required_permissions = {
        'list': Perm.STAFF_VIEW,
        'retrieve': Perm.STAFF_VIEW,
        'create': Perm.STAFF_MANAGE,
        'update': Perm.STAFF_MANAGE,
        'partial_update': Perm.STAFF_MANAGE,
        'destroy': Perm.STAFF_MANAGE,
    }
    filterset_fields = ['is_active', 'role']
    search_fields = ['user__username', 'user__email', 'job_title']
    audited_fields = ['user', 'role', 'job_title', 'is_active']

    def perform_create(self, serializer):
        # لا نستدعي super() هنا: القاعدة تستدعي serializer.save() بدون
        # created_by، وتسجّل CREATE عامًا. تعيين موظف حدث يستحق تسجيلًا
        # أوضح، فنتولاه بأنفسنا.
        instance = serializer.save(created_by=self.request.user)

        # الدخول للوحة يمر عبر StaffProfile، لكن is_staff تبقى مطلوبة
        # لتوافق بقية أجزاء النظام (Django admin وغيرها).
        if not instance.user.is_staff:
            instance.user.is_staff = True
            instance.user.save(update_fields=['is_staff'])

        from . import services
        services.record(
            actor=self.request.user,
            action=AuditLog.Action.ROLE_CHANGE,
            target=instance,
            changes={
                'user': {'to': str(instance.user)},
                'role': {'to': instance.role.name_ar},
            },
            reason=self.request.data.get('reason', ''),
            request=self.request,
        )

    def perform_destroy(self, instance):
        if instance.user_id == self.request.user.id:
            raise PermissionError('لا يمكنك إزالة صلاحياتك الإدارية بنفسك.')
        user = instance.user
        super().perform_destroy(instance)
        user.is_staff = False
        user.save(update_fields=['is_staff'])

    @action(detail=True, methods=['post'], url_path='change-role')
    def change_role(self, request, pk=None):
        profile = self.get_object()
        role_id = request.data.get('role')

        try:
            role = Role.objects.get(pk=role_id, is_active=True)
        except Role.DoesNotExist:
            return Response(
                {'role': 'دور غير موجود أو غير نشط.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not request.user.is_superuser:
            excess = set(role.permissions) - user_permissions(request.user)
            if excess:
                return Response(
                    {'role': 'لا يمكنك منح صلاحيات لا تملكها.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        old = profile.role
        profile.role = role
        profile.save(update_fields=['role'])

        from . import services
        services.record(
            actor=request.user,
            action=AuditLog.Action.ROLE_CHANGE,
            target=profile,
            changes={'role': {'from': old.name_ar, 'to': role.name_ar}},
            reason=request.data.get('reason', ''),
            request=request,
        )
        return Response({'status': 'success', 'role': role.name_ar})


class AuditLogViewSet(AdminReadOnlyViewSet):
    queryset = AuditLog.objects.select_related('actor', 'target_type').order_by(
        '-created_at'
    )
    serializer_class = AuditLogSerializer
    scope_lookup = None

    required_permissions = {
        'list': Perm.AUDIT_VIEW,
        'retrieve': Perm.AUDIT_VIEW,
    }
    filterset_fields = ['action', 'actor', 'target_type']
    search_fields = ['actor_label', 'target_label', 'reason']
    ordering_fields = ['created_at']
