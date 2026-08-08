"""
Onboarding Handoff — API side
==============================
نقطة واحدة: مستخدم موثَّق بـJWT في التطبيق يطلب رابط دخول للويب.
"""

from django.conf import settings
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.handoff import TOKEN_TTL_SECONDS, LoginHandoffToken

#: نفس الخادم الذي يخدم الـAPI — لوحة الويب مستضافة عليه.
WEB_BASE = getattr(settings, 'WEB_DASHBOARD_BASE_URL', '') or (
    'https://daliil-ay-khidma.onrender.com'
)


class OnboardingHandoffView(APIView):
    """
    POST /api/v2/onboarding/handoff/

    يُصدر رابطًا بصلاحية دخول لمرة واحدة، صالحًا لثوانٍ معدودة، ينقل
    المستخدم لجلسة ويب بنفس حسابه دون كتابة بياناته من جديد.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = LoginHandoffToken.issue(request.user, purpose='onboarding')
        return Response({
            'url': f'{WEB_BASE}/dashboard/handoff/{token.token}/',
            'expires_in': TOKEN_TTL_SECONDS,
        })
