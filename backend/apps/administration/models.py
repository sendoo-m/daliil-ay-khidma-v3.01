"""
Administration — Models
=======================
ثلاثة نماذج تشكل أساس لوحة الإدارة:

    Role         دور قابل للإنشاء والتعديل من التطبيق، يحمل مجموعة صلاحيات.
    StaffProfile ربط المستخدم بدور + نطاق جغرافي اختياري.
    AuditLog     سجل غير قابل للتعديل لكل عملية إدارية مؤثرة.

ملاحظة معمارية: `Role.permissions` حقل JSON وليس M2M مع Django Permission.
السبب أن صلاحيات Django مربوطة بجداول قاعدة البيانات (add/change/delete_model)
بينما صلاحياتنا مربوطة بعمليات العمل (توثيق نشاط، تمييز نشاط) — وهي لا تتطابق.
"""

from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from .constants import all_permissions, is_valid_permission


class Role(models.Model):
    """دور إداري = اسم + مجموعة صلاحيات."""

    slug = models.SlugField(
        _('المعرّف'),
        max_length=50,
        unique=True,
        help_text=_('معرّف ثابت لا يتغير، مثل operations_manager'),
    )
    name_ar = models.CharField(_('الاسم بالعربية'), max_length=100)
    name_en = models.CharField(_('الاسم بالإنجليزية'), max_length=100, blank=True)
    description = models.TextField(_('الوصف'), blank=True)

    permissions = models.JSONField(
        _('الصلاحيات'),
        default=list,
        help_text=_('قائمة أكواد الصلاحيات من PERMISSION_REGISTRY'),
    )

    is_protected = models.BooleanField(
        _('محمي'),
        default=False,
        help_text=_('الأدوار المحمية لا يمكن حذفها أو تجريدها من صلاحياتها'),
    )
    is_active = models.BooleanField(_('نشط'), default=True)

    created_at = models.DateTimeField(_('أُنشئ في'), auto_now_add=True)
    updated_at = models.DateTimeField(_('حُدّث في'), auto_now=True)

    class Meta:
        verbose_name = _('دور إداري')
        verbose_name_plural = _('الأدوار الإدارية')
        ordering = ['name_ar']

    def __str__(self) -> str:
        return self.name_ar

    def clean(self):
        if not isinstance(self.permissions, list):
            raise ValidationError({'permissions': _('يجب أن تكون قائمة.')})

        unknown = [p for p in self.permissions if not is_valid_permission(p)]
        if unknown:
            raise ValidationError({
                'permissions': _('صلاحيات غير معروفة: %(codes)s')
                % {'codes': ', '.join(unknown)}
            })

    def save(self, *args, **kwargs):
        # إزالة التكرار مع الحفاظ على ترتيب مستقر للمقارنة في السجل.
        self.permissions = sorted(set(self.permissions or []))
        super().save(*args, **kwargs)

    def grant_all(self):
        self.permissions = sorted(all_permissions())

    @property
    def is_superuser_role(self) -> bool:
        return set(self.permissions) >= set(all_permissions())


class StaffProfile(models.Model):
    """
    ربط مستخدم بدور إداري.

    النطاق الجغرافي (`governorates`) يقيّد ما يراه الموظف. فارغ = كل المحافظات.
    هذا ضروري لمنصة تغطي الجمهورية: مراجع أنشطة في أسيوط لا يجب أن
    يوثّق محلات في الإسكندرية.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='staff_profile',
        verbose_name=_('المستخدم'),
    )
    role = models.ForeignKey(
        Role,
        on_delete=models.PROTECT,
        related_name='staff_members',
        verbose_name=_('الدور'),
    )

    governorates = models.ManyToManyField(
        'directory.Governorate',
        blank=True,
        related_name='scoped_staff',
        verbose_name=_('نطاق المحافظات'),
        help_text=_('اتركه فارغًا لمنح صلاحية على كل المحافظات'),
    )

    job_title = models.CharField(_('المسمى الوظيفي'), max_length=100, blank=True)
    is_active = models.BooleanField(_('نشط'), default=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='staff_members_created',
        verbose_name=_('أضافه'),
    )
    created_at = models.DateTimeField(_('أُنشئ في'), auto_now_add=True)
    updated_at = models.DateTimeField(_('حُدّث في'), auto_now=True)
    last_admin_login = models.DateTimeField(_('آخر دخول للوحة'), null=True, blank=True)

    class Meta:
        verbose_name = _('موظف إدارة')
        verbose_name_plural = _('موظفو الإدارة')
        ordering = ['-created_at']
        indexes = [models.Index(fields=['is_active'])]

    def __str__(self) -> str:
        return f'{self.user} — {self.role.name_ar}'

    # ── الصلاحيات ─────────────────────────────────────

    @property
    def permissions(self) -> set[str]:
        if not self.is_active or not self.role.is_active:
            return set()
        return set(self.role.permissions or [])

    def has_perm(self, code: str) -> bool:
        return code in self.permissions

    def has_any_perm(self, *codes: str) -> bool:
        return bool(self.permissions.intersection(codes))

    # ── النطاق الجغرافي ───────────────────────────────

    @property
    def is_globally_scoped(self) -> bool:
        return not self.governorates.exists()

    def scope_governorate_ids(self) -> list[int] | None:
        """`None` تعني بلا قيود."""
        if self.is_globally_scoped:
            return None
        return list(self.governorates.values_list('id', flat=True))

    def touch_login(self):
        self.last_admin_login = timezone.now()
        self.save(update_fields=['last_admin_login'])


class AuditLog(models.Model):
    """
    سجل غير قابل للتعديل لكل عملية إدارية مؤثرة.

    لا يُحذف ولا يُعدَّل — `save()` يمنع التعديل بعد الإنشاء.
    """

    class Action(models.TextChoices):
        CREATE = 'create', _('إنشاء')
        UPDATE = 'update', _('تعديل')
        DELETE = 'delete', _('حذف')
        VERIFY = 'verify', _('توثيق')
        UNVERIFY = 'unverify', _('إلغاء توثيق')
        FEATURE = 'feature', _('تمييز')
        UNFEATURE = 'unfeature', _('إلغاء تمييز')
        APPROVE = 'approve', _('اعتماد')
        REJECT = 'reject', _('رفض')
        SUSPEND = 'suspend', _('تعليق')
        ACTIVATE = 'activate', _('تفعيل')
        ROLE_CHANGE = 'role_change', _('تغيير دور')
        NOTIFY = 'notify', _('إرسال إشعار')
        LOGIN = 'login', _('دخول للوحة')
        BULK = 'bulk', _('عملية جماعية')

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='audit_entries',
        verbose_name=_('المنفّذ'),
    )
    actor_label = models.CharField(
        _('اسم المنفّذ'),
        max_length=150,
        blank=True,
        help_text=_('نسخة نصية تبقى بعد حذف الحساب'),
    )
    actor_role = models.CharField(_('دور المنفّذ'), max_length=100, blank=True)

    action = models.CharField(_('العملية'), max_length=20, choices=Action.choices)

    target_type = models.ForeignKey(
        ContentType,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        verbose_name=_('نوع الهدف'),
    )
    target_id = models.PositiveIntegerField(_('معرّف الهدف'), null=True, blank=True)
    target = GenericForeignKey('target_type', 'target_id')
    target_label = models.CharField(_('اسم الهدف'), max_length=255, blank=True)

    changes = models.JSONField(
        _('التغييرات'),
        default=dict,
        blank=True,
        help_text=_('{"field": {"from": ..., "to": ...}}'),
    )
    reason = models.TextField(_('السبب'), blank=True)

    ip_address = models.GenericIPAddressField(_('عنوان IP'), null=True, blank=True)
    user_agent = models.CharField(_('المتصفح/الجهاز'), max_length=255, blank=True)

    created_at = models.DateTimeField(_('التوقيت'), auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = _('سجل عملية')
        verbose_name_plural = _('سجل العمليات')
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['actor', '-created_at']),
            models.Index(fields=['target_type', 'target_id']),
            models.Index(fields=['action', '-created_at']),
        ]

    def __str__(self) -> str:
        return f'{self.actor_label} · {self.get_action_display()} · {self.target_label}'

    def save(self, *args, **kwargs):
        if self.pk is not None:
            raise ValidationError(_('سجل العمليات غير قابل للتعديل.'))
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValidationError(_('سجل العمليات غير قابل للحذف.'))
