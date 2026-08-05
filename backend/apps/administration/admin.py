"""
تسجيل موديلات الإدارة في لوحة Django.

الفائدة العملية: تمنحك مسارًا بديلًا لإدارة الموظفين من المتصفح على
`/admin/` بلا حاجة إلى shell — مفيد على الاستضافات التي لا توفّره.
"""

from django.contrib import admin
from django.utils.html import format_html

from .constants import PERMISSION_REGISTRY
from .models import AuditLog, Role, StaffProfile


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ('name_ar', 'slug', 'permission_count', 'staff_count',
                    'is_protected', 'is_active')
    list_filter = ('is_active', 'is_protected')
    search_fields = ('name_ar', 'name_en', 'slug')
    readonly_fields = ('created_at', 'updated_at', 'permission_help')

    fieldsets = (
        (None, {'fields': ('slug', 'name_ar', 'name_en', 'description')}),
        ('الصلاحيات', {'fields': ('permissions', 'permission_help')}),
        ('الحالة', {'fields': ('is_active', 'is_protected')}),
        ('التتبّع', {'fields': ('created_at', 'updated_at')}),
    )

    @admin.display(description='عدد الصلاحيات')
    def permission_count(self, obj):
        return len(obj.permissions or [])

    @admin.display(description='الموظفون')
    def staff_count(self, obj):
        return obj.staff_members.count()

    @admin.display(description='الأكواد المتاحة')
    def permission_help(self, obj):
        rows = []
        for group in PERMISSION_REGISTRY.values():
            codes = ' · '.join(group['permissions'])
            rows.append(f'<b>{group["label"]}</b><br><code>{codes}</code>')
        return format_html('<br><br>'.join(rows))

    def has_delete_permission(self, request, obj=None):
        if obj is not None and obj.is_protected:
            return False
        return super().has_delete_permission(request, obj)


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'role', 'scope_display', 'job_title',
                    'is_active', 'last_admin_login')
    list_filter = ('is_active', 'role')
    search_fields = ('user__username', 'user__email', 'job_title')
    autocomplete_fields = ('user', 'role')
    filter_horizontal = ('governorates',)
    readonly_fields = ('created_at', 'updated_at', 'last_admin_login')

    @admin.display(description='النطاق')
    def scope_display(self, obj):
        names = [g.name_ar for g in obj.governorates.all()]
        return ' · '.join(names) if names else 'كل المحافظات'

    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
        # الدخول للوحة يمر عبر StaffProfile، لكن is_staff تبقى مطلوبة
        # للوحة Django نفسها.
        if not obj.user.is_staff:
            obj.user.is_staff = True
            obj.user.save(update_fields=['is_staff'])


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'actor_label', 'actor_role',
                    'action', 'target_label')
    list_filter = ('action', 'created_at')
    search_fields = ('actor_label', 'target_label', 'reason')
    date_hierarchy = 'created_at'

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        # السجل غير قابل للحذف — الموديل نفسه يرفض، ونمنعه هنا أيضًا
        # حتى لا تعرض الواجهة زرًا يفشل.
        return False

    def get_readonly_fields(self, request, obj=None):
        return [f.name for f in self.model._meta.fields]
