"""
Magic-Link / Web-Handoff
========================
الموبايل عنده JWT access token للمستخدم. عايز يفتح متصفح على الويب
وهو مسجّل دخول بنفس الحساب — بلا كتابة بياناته من جديد.

التسلسل:
  1. Flutter   →  POST /api/auth/magic-link/   (Authorization: Bearer <jwt>)
  2. Backend   →  ينشئ MagicLinkToken (استخدام واحد، دقيقتين)
                  يرجع { "url": "https://…/auth/magic/?t=<token>" }
  3. Flutter   →  يفتح الرابط في متصفح خارجي
  4. Django    →  يتحقق من التوكن، يعمل login(request, user)
                  يحسب next_action من محرك الرحلة نفسه ويوجّه إليه

تصحيحان جوهريان عن النسخة الأولى من هذا الملف:

  ١. المصادقة كانت `TokenAuthentication` (توكنات DRF التقليدية)، بينما
     المشروع كله موثَّق بـJWT عبر `rest_framework_simplejwt`
     (`DEFAULT_AUTHENTICATION_CLASSES` في settings). فكان أي طلب من
     التطبيق الحقيقي سيُرفض بـ401 دائمًا — الآلية لم تكن تعمل قط مع
     الموبايل الفعلي، فقط مع توكن من نوع مختلف لا يُصدره النظام.

  ٢. الوجهة كانت تُقرأ من `?next=` في الرابط مباشرة. رابط تسليم مسروق
     (نُسخ من شاشة تعاون، أو رصدته أداة تتبّع روابط) كان يستطيع توجيه
     ضحيته بعد تسجيل دخولها تلقائيًا لأي مسار داخل الموقع، لا فقط
     لوحتها. الآن تُحسب الوجهة من `build_onboarding_state` — نفس
     المصدر الذي يبني بانر لوحة صاحب النشاط
     (`apps.dashboard.views.owner._SETUP_ACTIONS`) — فلا يقرر الوجهة
     أي رابط، بل حالة المستخدم الفعلية فقط.
"""

import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model, login
from django.db import models
from django.http import JsonResponse
from django.shortcuts import redirect
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

User = get_user_model()

#: التوكن قصير عمدًا: نافذة انتقال بين نداء API وفتح المتصفح، لا جلسة
#: تُحفظ. كل دقيقة زيادة هنا نافذة إضافية لإعادة استخدام رابط مسروق.
_TTL_MINUTES = 2


# ──────────────────────────────────────────────
#  Model
# ──────────────────────────────────────────────

class MagicLinkToken(models.Model):
    """توكن استخدام واحد لتسجيل دخول التاجر من الموبايل للويب."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='magic_link_tokens',
    )
    token = models.CharField(max_length=64, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)
    # اختياري — نربط بـ IP المُصدِر للحماية من سرقة التوكن
    issued_ip = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        app_label = 'accounts'

    def __str__(self):
        return f'MagicLink({self.user_id}) expires={self.expires_at} used={self.used}'

    @property
    def is_valid(self):
        return not self.used and timezone.now() < self.expires_at


# ──────────────────────────────────────────────
#  Helper
# ──────────────────────────────────────────────

def _get_client_ip(request):
    x_forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    return x_forwarded.split(',')[0].strip() if x_forwarded else request.META.get('REMOTE_ADDR')


def _resolve_destination(user) -> str:
    """يحسب وجهة التاجر من حالة رحلته الفعلية — لا من مدخل خارجي."""
    try:
        from apps.dashboard.views.owner import _SETUP_ACTIONS
        from apps.subscriptions.onboarding import (
            build_onboarding_state,
            get_or_create_onboarding,
        )

        state = build_onboarding_state(get_or_create_onboarding(user))
        spec = _SETUP_ACTIONS.get(state.get('next_action', ''))
        if spec and spec.get('url_name'):
            return reverse(spec['url_name'])
    except Exception:  # noqa: BLE001
        # فشل حساب الوجهة لا يجوز أن يترك المستخدم عالقًا — يصل دائمًا
        # إلى مكان يعمل: لوحته.
        import logging

        logging.getLogger('accounts.magic_link').exception(
            'تعذّر حساب وجهة تسليم الجلسة للمستخدم %s', user.pk
        )

    return reverse('dashboard:owner_dashboard')


# ──────────────────────────────────────────────
#  API View — يستقبل طلب الموبايل (JWT)
# ──────────────────────────────────────────────

@csrf_exempt
@require_POST
def issue_magic_link(request):
    """
    POST /api/auth/magic-link/
    Header: Authorization: Bearer <jwt access token>

    يرجع:
        200  { "url": "https://<host>/auth/magic/?t=<token>", "expires_in": 120 }
        401  { "error": "..." }
    """
    header = request.META.get('HTTP_AUTHORIZATION', '')
    if not header.startswith('Bearer '):
        return JsonResponse({'error': 'غير مصرح'}, status=401)

    try:
        auth = JWTAuthentication()
        validated = auth.get_validated_token(header.split(' ', 1)[1].strip())
        user = auth.get_user(validated)
    except (InvalidToken, TokenError):
        return JsonResponse({'error': 'التوكن غير صالح'}, status=401)

    if user is None or not user.is_active:
        return JsonResponse({'error': 'الحساب غير نشط'}, status=401)

    # تنظيف توكنات منتهية لنفس المستخدم — الجدول صغير بطبيعته ولا
    # يحتاج مهمة دورية منفصلة.
    MagicLinkToken.objects.filter(
        user=user, used=False, expires_at__lt=timezone.now(),
    ).delete()

    token_str = secrets.token_urlsafe(48)
    MagicLinkToken.objects.create(
        user=user,
        token=token_str,
        expires_at=timezone.now() + timedelta(minutes=_TTL_MINUTES),
        issued_ip=_get_client_ip(request),
    )

    host = request.build_absolute_uri('/').rstrip('/')
    magic_url = f'{host}{reverse("magic_link_redeem")}?t={token_str}'

    return JsonResponse({'url': magic_url, 'expires_in': _TTL_MINUTES * 60})


# ──────────────────────────────────────────────
#  Web View — التاجر يفتح الرابط ده في المتصفح
# ──────────────────────────────────────────────

@require_GET
def redeem_magic_link(request):
    """
    GET /auth/magic/?t=<token>

    - يتحقق من التوكن ويعلّمه مُستخدَمًا فورًا (منع إعادة الاستخدام)
    - يسجّل جلسة Django بنفس الحساب
    - يوجّه لخطوة الرحلة الفعلية — لا لمسار وارد في الرابط
    """
    token_str = request.GET.get('t', '').strip()

    try:
        magic = MagicLinkToken.objects.select_related('user').get(
            token=token_str
        )
    except MagicLinkToken.DoesNotExist:
        return redirect(f'{reverse("dashboard:staff_login")}?error=invalid_link')

    if not magic.is_valid:
        return redirect(f'{reverse("dashboard:staff_login")}?error=expired_link')

    # نعلّمه مُستخدَمًا قبل أي شيء آخر — منع إعادة استخدام في نافذتين
    # متزامنتين (تبويبان، أو معاينة رابط مسبقة من المتصفح).
    magic.used = True
    magic.save(update_fields=['used'])

    user = magic.user
    if not user.is_active:
        return redirect(f'{reverse("dashboard:staff_login")}?error=inactive')

    login(request, user, backend='django.contrib.auth.backends.ModelBackend')

    return redirect(_resolve_destination(user))
