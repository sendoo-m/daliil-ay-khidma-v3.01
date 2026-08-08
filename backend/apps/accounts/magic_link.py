"""
Magic-Link / Web-Handoff
========================
الموبايل (Flutter) عنده DRF token للمستخدم.
عايز يفتح WebView على الويب وهو مسجّل دخول بنفس الحساب.

التسلسل:
  1.  Flutter  →  POST /api/auth/magic-link/           (Authorization: Token <drf_token>)
  2.  Backend  →  ينشئ MagicLinkToken (one-time, 10 دقايق)
                  يرجع { "url": "https://…/auth/magic/?t=<token>" }
  3.  Flutter  →  يفتح الـ URL ده في WebView / External browser
  4.  Django   →  يتحقق من التوكن، يعمل login(request, user)
                  يعمل redirect لـ next أو subscriptions:plans_list
"""

import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model, login
from django.db import models
from django.http import JsonResponse
from django.shortcuts import redirect
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import AuthenticationFailed

User = get_user_model()

_TTL_MINUTES = 10  # التوكن بيبقى صالح 10 دقايق بس


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


# ──────────────────────────────────────────────
#  API View — يستقبل طلب الموبايل (DRF token)
# ──────────────────────────────────────────────

@csrf_exempt
@require_POST
def issue_magic_link(request):
    """
    POST /api/auth/magic-link/
    Header: Authorization: Token <drf_token>

    يرجع:
        200  { "url": "https://<host>/auth/magic/?t=<token>&next=<next>" }
        401  { "error": "..." }
    """
    # نتحقق من DRF token بدون الحاجة لـ DRF view class
    auth = TokenAuthentication()
    try:
        user, _ = auth.authenticate(request)  # يرمي AuthenticationFailed لو فشل
    except (AuthenticationFailed, TypeError):
        return JsonResponse({'error': 'غير مصرح'}, status=401)

    if user is None or not user.is_active:
        return JsonResponse({'error': 'الحساب غير نشط'}, status=401)

    # نمسح توكنات قديمة للمستخدم ده (cleanup)
    MagicLinkToken.objects.filter(
        user=user,
        used=False,
        expires_at__lt=timezone.now(),
    ).delete()

    token_str = secrets.token_urlsafe(48)
    ml = MagicLinkToken.objects.create(
        user=user,
        token=token_str,
        expires_at=timezone.now() + timedelta(minutes=_TTL_MINUTES),
        issued_ip=_get_client_ip(request),
    )

    next_url = request.GET.get('next', '/subscriptions/plans/')
    host = request.build_absolute_uri('/').rstrip('/')
    magic_url = f"{host}/auth/magic/?t={ml.token}&next={next_url}"

    return JsonResponse({'url': magic_url})


# ──────────────────────────────────────────────
#  Web View — التاجر يفتح الـ URL ده في المتصفح
# ──────────────────────────────────────────────

@require_GET
def redeem_magic_link(request):
    """
    GET /auth/magic/?t=<token>&next=<path>

    - يتحقق من التوكن
    - يعمل Django session login
    - يعمل redirect لـ next (default: صفحة الخطط)
    """
    token_str = request.GET.get('t', '').strip()
    next_url = request.GET.get('next', '/subscriptions/plans/')

    # أمان بسيط: next لازم يبدأ بـ /
    if not next_url.startswith('/'):
        next_url = '/subscriptions/plans/'

    try:
        ml = MagicLinkToken.objects.select_related('user').get(token=token_str)
    except MagicLinkToken.DoesNotExist:
        return redirect(f'/account/login/?error=invalid_link')

    if not ml.is_valid:
        return redirect(f'/account/login/?error=expired_link')

    # نعلّم التوكن كـ مستخدم فوراً (one-time)
    ml.used = True
    ml.save(update_fields=['used'])

    user = ml.user
    if not user.is_active:
        return redirect('/account/login/?error=inactive')

    # Django login — نحدد backend صراحةً
    backend = 'django.contrib.auth.backends.ModelBackend'
    login(request, user, backend=backend)

    return redirect(next_url)
