"""
Merchant API — Base
===================
الأساس الذي ترث منه كل نقاط تطبيق الأنشطة.

القرار المعماري الحاسم: هذا مسار **منفصل بنيويًا** عن `/api/v2/admin/`.

السبب رقمي. مع أكثر من ألف نشاط، لو دخل التجار من بوابة الإدارة لاحتجنا
ألف `StaffProfile`. ومع ألف صف، احتمال ضبط أحدها بدور خاطئ مرة واحدة
يقترب من المؤكد — وساعتها يملك تاجر صلاحية توثيق محلات غيره.

فبدل الاعتماد على إعداد صحيح، لا نكتب العملية أصلًا. لا يوجد في هذا
الملف ولا في أي وارث منه أي مسار إلى التوثيق أو التمييز أو إدارة
المستخدمين. ليست ممنوعة — غير موجودة.

الفرق بين قفل وحاجز. مع هذا العدد، نأخذ الحاجز.
"""

from rest_framework import permissions, viewsets

from apps.administration import services
from apps.administration.models import AuditLog
from apps.directory.models import Business


class IsBusinessOwner(permissions.BasePermission):
    """
    بوابة تطبيق الأنشطة: مستخدم مسجّل يملك نشاطًا واحدًا على الأقل.

    لا علاقة لها بـ`is_staff` ولا بـ`StaffProfile` — مسار مستقل تمامًا.
    """

    message = 'هذا الحساب لا يملك أي نشاط مسجَّل.'

    def has_permission(self, request, view) -> bool:
        user = request.user
        if not user or not user.is_authenticated or not user.is_active:
            return False
        return Business.objects.filter(owner=user).exists()


class OwnedQuerysetMixin:
    """
    يقصر النتائج على ما يملكه المستخدم — على مستوى الـqueryset.

    هذا مقصود: الفلترة قبل الجلب تجعل سجل الغير يرجع **404 لا 403**،
    فلا تكشف الرسالة نفسها أن السجل موجود. الفرق مهم — 403 على معرّف
    ما تعني "هذا موجود ولك ممنوع"، وهي معلومة لا داعي لمنحها.

    عرّف `ownership_lookup` بالمسار من الموديل إلى المالك:

        ownership_lookup = 'owner'            # Business
        ownership_lookup = 'business__owner'  # Product · Deal · Review
    """

    ownership_lookup: str = 'owner'

    def get_queryset(self):
        return super().get_queryset().filter(
            **{self.ownership_lookup: self.request.user}
        )

    def owned_businesses(self):
        """أنشطة المستخدم — يُستخدم للتحقق عند الإنشاء."""
        return Business.objects.filter(owner=self.request.user)


class MerchantViewSet(OwnedQuerysetMixin, viewsets.ModelViewSet):
    """
    ViewSet أساسي لتطبيق الأنشطة.

    يسجّل التعديلات في نفس `AuditLog` — سؤال "مين غيّر السعر ده؟"
    يستحق إجابة سواء كان المنفّذ موظفًا أو صاحب المحل.
    """

    permission_classes = [IsBusinessOwner]
    ownership_lookup = 'business__owner'
    audited_fields: list[str] | None = None

    def _record(self, action: str, instance, changes: dict):
        services.record(
            actor=self.request.user,
            action=action,
            target=instance,
            changes=changes,
            request=self.request,
        )

    def perform_create(self, serializer):
        instance = serializer.save()
        self._record(
            AuditLog.Action.CREATE,
            instance,
            services.snapshot(instance, self.audited_fields),
        )

    def perform_update(self, serializer):
        before = services.snapshot(serializer.instance, self.audited_fields)
        instance = serializer.save()
        changes = services.diff(
            before, services.snapshot(instance, self.audited_fields)
        )
        if changes:
            self._record(AuditLog.Action.UPDATE, instance, changes)

    def perform_destroy(self, instance):
        label = f'{instance.__class__.__name__}: {instance}'
        snap = services.snapshot(instance, self.audited_fields)
        instance.delete()
        services.record(
            actor=self.request.user,
            action=AuditLog.Action.DELETE,
            target=None,
            target_label=label,
            changes=snap,
            request=self.request,
        )
