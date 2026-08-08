"""
Login Handoff
=============
جسر جلسة من التطبيق للويب بنفس الحساب.

المشكلة: تطبيق المستخدم موثَّق بـJWT، ولوحة الويب موثَّقة بجلسة Django
عادية. لا رابط تلقائي بين الاثنين — المستخدم في التطبيق والمتصفح
حسابان منفصلان من نظر الخادم حتى يسجّل دخوله يدويًا في الاثنين.

الحل: توكن مرة واحدة قصير العمر. التطبيق (موثَّق بالفعل بـJWT) يطلبه،
والويب يستهلكه فيسجّل الدخول بنفس الحساب تلقائيًا. نفس نمط "روابط
السحر" في تسجيل الدخول بالبريد — التوكن نفسه لا يحمل صلاحية أوسع من
الجلسة العادية، فقط ينقل هوية مؤكدة مسبقًا من قناة لأخرى.
"""

import secrets
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

#: عمر التوكن. قصير عمدًا: هذه نافذة انتقال بين نداء API وفتح المتصفح،
#: لا جلسة تُحفظ. كل ثانية زيادة هنا نافذة إضافية لإعادة استخدام رابط
#: مسروق قبل فتحه.
TOKEN_TTL_SECONDS = 90


class LoginHandoffToken(models.Model):
    """توكن ينقل هوية مستخدم من التطبيق إلى جلسة ويب. يُستهلك مرة واحدة."""

    token = models.CharField(max_length=64, unique=True, db_index=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='handoff_tokens',
    )

    #: أين يذهب المستخدم بعد تسجيل الدخول. لا نفتح الباب لأي مسار —
    #: قائمة مغلقة تمنع استخدام آلية التسليم كوسيلة توجيه عامة.
    PURPOSE_CHOICES = [('onboarding', 'Onboarding continuation')]
    purpose = models.CharField(
        max_length=30, choices=PURPOSE_CHOICES, default='onboarding'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=['token', 'used_at'])]

    def __str__(self) -> str:
        return f'handoff:{self.user_id}:{self.purpose}'

    @property
    def is_expired(self) -> bool:
        return timezone.now() > self.created_at + timedelta(
            seconds=TOKEN_TTL_SECONDS
        )

    @property
    def is_used(self) -> bool:
        return self.used_at is not None

    @classmethod
    def issue(cls, user, purpose: str = 'onboarding') -> 'LoginHandoffToken':
        # ننظّف توكنات المستخدم القديمة بدل تركها تتراكم — الجدول صغير
        # بطبيعته (كل نداء يُستهلك أو يُنسى في دقائق) ولا يحتاج مهمة
        # دورية منفصلة.
        cls.objects.filter(user=user, used_at__isnull=True).delete()
        return cls.objects.create(
            token=secrets.token_urlsafe(32), user=user, purpose=purpose
        )

    @classmethod
    def consume(cls, token: str, purpose: str = 'onboarding'):
        """
        يستهلك التوكن مرة واحدة ويُرجع المستخدم، أو `None` لو غير صالح.

        العلامة والفحص في نفس الاستدعاء تمنع سباقًا لو فُتح الرابط
        مرتين في نفس اللحظة (تبويبان، أو معاينة رابط مسبقة من المتصفح).
        """
        updated = cls.objects.filter(
            token=token, purpose=purpose, used_at__isnull=True
        ).update(used_at=timezone.now())

        if updated == 0:
            return None

        record = cls.objects.select_related('user').get(token=token)
        if record.is_expired:
            return None

        return record.user
