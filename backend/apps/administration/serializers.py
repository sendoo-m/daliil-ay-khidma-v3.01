"""Administration — Serializers for role, staff, and audit endpoints."""

from django.contrib.auth import get_user_model
from rest_framework import serializers

from .constants import PERMISSION_REGISTRY, is_valid_permission
from .models import AuditLog, Role, StaffProfile

User = get_user_model()


class PermissionCatalogSerializer(serializers.Serializer):
    """
    كتالوج الصلاحيات المجمّعة — يبني شاشة الأدوار في Flutter تلقائيًا.
    أي صلاحية تُضاف في constants.py تظهر في التطبيق بلا تعديل واجهة.
    """

    @staticmethod
    def build() -> list[dict]:
        return [
            {
                'key': key,
                'label': str(group['label']),
                'permissions': [
                    {'code': code, 'label': str(label)}
                    for code, label in group['permissions'].items()
                ],
            }
            for key, group in PERMISSION_REGISTRY.items()
        ]


class RoleSerializer(serializers.ModelSerializer):
    staff_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Role
        fields = [
            'id', 'slug', 'name_ar', 'name_en', 'description',
            'permissions', 'is_protected', 'is_active',
            'staff_count', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'is_protected', 'created_at', 'updated_at']

    def validate_permissions(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError('يجب أن تكون قائمة أكواد.')
        unknown = [p for p in value if not is_valid_permission(p)]
        if unknown:
            raise serializers.ValidationError(
                f'صلاحيات غير معروفة: {", ".join(unknown)}'
            )
        return sorted(set(value))

    def validate(self, attrs):
        instance = self.instance
        if instance and instance.is_protected:
            if 'permissions' in attrs and set(attrs['permissions']) != set(
                instance.permissions
            ):
                raise serializers.ValidationError(
                    {'permissions': 'لا يمكن تعديل صلاحيات دور محمي.'}
                )
            if attrs.get('is_active') is False:
                raise serializers.ValidationError(
                    {'is_active': 'لا يمكن تعطيل دور محمي.'}
                )
        return attrs


class StaffProfileSerializer(serializers.ModelSerializer):
    user = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())
    role = serializers.PrimaryKeyRelatedField(queryset=Role.objects.filter(is_active=True))

    user_detail = serializers.SerializerMethodField()
    role_name = serializers.CharField(source='role.name_ar', read_only=True)
    governorate_names = serializers.SerializerMethodField()
    is_globally_scoped = serializers.BooleanField(read_only=True)

    class Meta:
        model = StaffProfile
        fields = [
            'id', 'user', 'user_detail', 'role', 'role_name',
            'governorates', 'governorate_names', 'is_globally_scoped',
            'job_title', 'is_active',
            'created_at', 'updated_at', 'last_admin_login',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'last_admin_login']

    def get_user_detail(self, obj) -> dict:
        return {
            'id': obj.user_id,
            'username': obj.user.username,
            'full_name': obj.user.get_full_name() or obj.user.username,
            'email': obj.user.email,
            'phone': getattr(obj.user, 'phone', ''),
        }

    def get_governorate_names(self, obj) -> list[str]:
        return [g.name_ar for g in obj.governorates.all()]

    def validate_role(self, value):
        """
        قاعدة مهمة: لا يمنح موظفٌ دورًا يفوق صلاحياته.
        بدونها يستطيع أي موظف عنده staff.manage أن يرقّي نفسه ضمنيًا
        بإنشاء حساب بدور أعلى ثم الدخول به.
        """
        request = self.context.get('request')
        if request is None or request.user.is_superuser:
            return value

        from .permissions import user_permissions
        granter = user_permissions(request.user)
        excess = set(value.permissions) - granter
        if excess:
            raise serializers.ValidationError(
                'لا يمكنك منح دور يحتوي صلاحيات لا تملكها: '
                + ', '.join(sorted(excess))
            )
        return value


class AuditLogSerializer(serializers.ModelSerializer):
    action_display = serializers.CharField(source='get_action_display', read_only=True)
    target_model = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = [
            'id', 'actor', 'actor_label', 'actor_role',
            'action', 'action_display',
            'target_model', 'target_id', 'target_label',
            'changes', 'reason', 'ip_address', 'created_at',
        ]
        read_only_fields = fields

    def get_target_model(self, obj) -> str | None:
        return obj.target_type.model if obj.target_type_id else None
