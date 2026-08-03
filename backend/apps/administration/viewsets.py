"""
Administration — Base ViewSets
==============================
الأساس الذي ترث منه كل ViewSets لوحة الإدارة.

يوفّر تلقائيًا:
    · التحقق من الصلاحية لكل action (الافتراضي منع)
    · تقييد النتائج بالنطاق الجغرافي للموظف
    · تسجيل كل عملية إنشاء/تعديل/حذف في AuditLog مع الفروق
    · بنية موحّدة للعمليات الجماعية

ترث منه ViewSet فتحصل على كل هذا بلا كود إضافي.
"""

from django.db import transaction
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from . import services
from .models import AuditLog
from .permissions import (
    GovernorateScopedMixin,
    HasActionPermission,
    IsAdminPanelUser,
)


class AdminModelViewSet(GovernorateScopedMixin, viewsets.ModelViewSet):
    """
    ViewSet أساسي للوحة الإدارة.

    على الوارث تعريف:
        required_permissions : dict[action_name, permission_code]
        scope_lookup         : str | None
    """

    permission_classes = [IsAdminPanelUser, HasActionPermission]
    required_permissions: dict = {}
    scope_lookup: str | None = None

    #: الحقول التي تُتابَع في سجل التغييرات. None = كل الحقول.
    audited_fields: list[str] | None = None

    # ── تسجيل العمليات ────────────────────────────────

    def perform_create(self, serializer):
        instance = serializer.save()
        services.record(
            actor=self.request.user,
            action=AuditLog.Action.CREATE,
            target=instance,
            changes=services.snapshot(instance, self.audited_fields),
            request=self.request,
        )

    def perform_update(self, serializer):
        before = services.snapshot(serializer.instance, self.audited_fields)
        instance = serializer.save()
        after = services.snapshot(instance, self.audited_fields)

        changes = services.diff(before, after)
        if changes:  # لا نسجّل تعديلًا لم يغيّر شيئًا
            services.record(
                actor=self.request.user,
                action=AuditLog.Action.UPDATE,
                target=instance,
                changes=changes,
                request=self.request,
            )

    def perform_destroy(self, instance):
        label = str(instance)
        snap = services.snapshot(instance, self.audited_fields)
        target_ref = instance
        instance.delete()
        services.record(
            actor=self.request.user,
            action=AuditLog.Action.DELETE,
            target=None,
            target_label=f'{target_ref.__class__.__name__}: {label}',
            changes=snap,
            request=self.request,
        )

    # ── أداة مساعدة للعمليات المخصّصة ─────────────────

    def audited_toggle(
        self,
        instance,
        field: str,
        value: bool,
        *,
        action_on: str,
        action_off: str,
    ) -> Response:
        """
        تنفيذ تبديل حقل منطقي مع تسجيله.

        تُستخدم في verify / feature / suspend وما شابه بدل تكرار الكود.
        """
        if not self.is_within_scope(instance):
            return Response(
                {'detail': 'هذا العنصر خارج نطاقك الجغرافي.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        old = getattr(instance, field)
        if old == value:
            return Response({'status': 'unchanged', field: value})

        setattr(instance, field, value)
        instance.save(update_fields=[field])

        services.record(
            actor=self.request.user,
            action=action_on if value else action_off,
            target=instance,
            changes={field: {'from': old, 'to': value}},
            reason=self.request.data.get('reason', ''),
            request=self.request,
        )
        return Response({'status': 'success', field: value})

    # ── العمليات الجماعية ─────────────────────────────

    #: الحقول المسموح تعديلها جماعيًا. الوارث يحددها صراحةً.
    bulk_updatable_fields: dict[str, str] = {}  # {field_name: permission_code}

    @action(detail=False, methods=['post'], url_path='bulk-update')
    def bulk_update(self, request):
        """
        POST /bulk-update/
            {"ids": [1,2,3], "field": "is_verified", "value": true, "reason": "..."}

        تُنفَّذ داخل transaction واحدة وتُسجَّل كعملية واحدة في السجل.
        """
        ids = request.data.get('ids') or []
        field = request.data.get('field')
        value = request.data.get('value')
        reason = request.data.get('reason', '')

        if not isinstance(ids, list) or not ids:
            return Response(
                {'detail': 'يجب تحديد عناصر.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(ids) > 200:
            return Response(
                {'detail': 'الحد الأقصى 200 عنصر في العملية الواحدة.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        allowed = self.bulk_updatable_fields
        if field not in allowed:
            return Response(
                {'detail': f'الحقل "{field}" غير مسموح بتعديله جماعيًا.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from .permissions import user_can
        if not user_can(request.user, allowed[field]):
            return Response(
                {'detail': 'ليس لديك صلاحية هذه العملية.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # get_queryset يطبّق النطاق الجغرافي — لا يمكن تعديل ما هو خارجه.
        queryset = self.filter_queryset(self.get_queryset()).filter(id__in=ids)
        matched = list(queryset.values_list('id', flat=True))

        with transaction.atomic():
            updated = queryset.update(**{field: value})

        services.record(
            actor=request.user,
            action=AuditLog.Action.BULK,
            target=None,
            target_label=f'{self.queryset.model.__name__} × {updated}',
            changes={field: {'to': value}, 'ids': matched},
            reason=reason,
            request=request,
        )

        skipped = [i for i in ids if i not in set(matched)]
        return Response({
            'status': 'success',
            'updated': updated,
            'skipped': skipped,
            'skipped_reason': 'خارج نطاقك أو غير موجود' if skipped else None,
        })


class AdminReadOnlyViewSet(GovernorateScopedMixin, viewsets.ReadOnlyModelViewSet):
    """نسخة للقراءة فقط — للتقارير وسجل العمليات."""

    permission_classes = [IsAdminPanelUser, HasActionPermission]
    required_permissions: dict = {}
    scope_lookup: str | None = None
