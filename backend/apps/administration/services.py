"""
Administration — Audit Service
==============================
نقطة واحدة لتسجيل العمليات الإدارية.

القاعدة: أي عملية تُغيّر البيانات تُسجَّل. لا استثناءات.
"""

from __future__ import annotations

from typing import Any

from django.contrib.contenttypes.models import ContentType
from django.db import models

from .models import AuditLog
from .permissions import get_staff_profile

#: حقول لا تُسجَّل قيمها أبدًا في السجل.
SENSITIVE_FIELDS = {
    'password', 'token', 'access', 'refresh', 'secret',
    'api_key', 'otp', 'reset_token',
}


def _client_ip(request) -> str | None:
    if request is None:
        return None
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def _serialize(value: Any) -> Any:
    """تحويل القيمة لشكل قابل للتخزين في JSON."""
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, models.Model):
        return {'id': value.pk, 'label': str(value)}
    return str(value)


def snapshot(instance: models.Model, fields: list[str] | None = None) -> dict:
    """لقطة من قيم الحقول قبل التعديل."""
    if instance is None or instance.pk is None:
        return {}

    names = fields or [
        f.name for f in instance._meta.fields
        if f.name.lower() not in SENSITIVE_FIELDS
    ]
    return {name: _serialize(getattr(instance, name, None)) for name in names}


def diff(before: dict, after: dict) -> dict:
    """
    الفرق بين لقطتين، بصيغة {"field": {"from": x, "to": y}}.
    الحقول غير المتغيرة تُحذف — السجل يجب أن يكون قابلًا للقراءة.
    """
    changes = {}
    for key in set(before) | set(after):
        if key.lower() in SENSITIVE_FIELDS:
            continue
        old, new = before.get(key), after.get(key)
        if old != new:
            changes[key] = {'from': old, 'to': new}
    return changes


def record(
    *,
    actor,
    action: str,
    target: models.Model | None = None,
    changes: dict | None = None,
    reason: str = '',
    request=None,
    target_label: str = '',
) -> AuditLog:
    """يسجّل عملية إدارية. لا يرمي استثناءً أبدًا — الفشل في التسجيل
    لا يجب أن يُسقط عملية ناجحة، لكنه يُسجَّل في اللوج."""

    profile = get_staff_profile(actor)
    role_label = ''
    if actor is not None and getattr(actor, 'is_superuser', False):
        role_label = 'superuser'
    elif profile is not None:
        role_label = profile.role.name_ar

    entry = AuditLog(
        actor=actor if getattr(actor, 'is_authenticated', False) else None,
        actor_label=str(actor) if actor else 'system',
        actor_role=role_label,
        action=action,
        changes=changes or {},
        reason=reason or '',
        ip_address=_client_ip(request),
        user_agent=(request.META.get('HTTP_USER_AGENT', '')[:255] if request else ''),
    )

    if target is not None:
        entry.target_type = ContentType.objects.get_for_model(target.__class__)
        entry.target_id = target.pk
        entry.target_label = (target_label or str(target))[:255]
    elif target_label:
        entry.target_label = target_label[:255]

    try:
        entry.save()
    except Exception:  # noqa: BLE001 — التسجيل لا يُسقط العملية
        import logging
        logging.getLogger('administration.audit').exception(
            'Failed to write audit entry: action=%s actor=%s', action, actor
        )
    return entry
