"""
Dashboard — Permission & Audit Middleware
=========================================
تطبّق نظام الأدوار على لوحة الويب.

قبل هذا الملف كانت اللوحة تحرسها `@staff_member_required` وحدها — أي
`is_staff` يساوي كل الصلاحيات في كل المحافظات بلا أي أثر. فكان لدينا
نظاما صلاحيات متوازيان: واحد دقيق على الـAPI وآخر معطّل على اللوحة،
والموظفون يعملون على اللوحة.

لماذا middleware لا ديكوريتور؟ لأن الديكوريتور يجب أن يُضاف يدويًا على
كل view، وأول view يُنسى يصبح ثغرة صامتة. الـmiddleware تمرّ على كل
طلب، والمسار غير المسجَّل يُرفض بدل أن يمرّ.
"""

import logging

from django.contrib import messages
from django.shortcuts import redirect, render

from apps.administration.permissions import get_staff_profile, user_can
from apps.dashboard.permissions_map import (
    DASHBOARD_PERMISSIONS,
    MUTATING_ROUTES,
    PUBLIC_DASHBOARD_ROUTES,
    STAFF_ONLY_ROUTES,
)

logger = logging.getLogger('dashboard.access')


class DashboardPermissionMiddleware:
    """تمنع الوصول لمسارات اللوحة الإدارية بلا الصلاحية المطلوبة."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        match = request.resolver_match
        if match is None or match.app_name != 'dashboard':
            return None

        route = match.url_name or ''

        # مسارات المستخدم وصاحب النشاط: الملكية تُفحص داخل الـview.
        if route in PUBLIC_DASHBOARD_ROUTES:
            return None

        user = request.user
        if not user.is_authenticated:
            return redirect(f'/dashboard/login/?next={request.path}')

        # مسار الطوارئ — يبقى مفتوحًا لاستعادة الوصول لو أخطأ أحدهم
        # في ضبط الأدوار وأقفل الجميع خارج اللوحة.
        if user.is_superuser:
            return None

        if get_staff_profile(user) is None:
            return self._denied(
                request,
                'الحساب ده مش مسجَّل كموظف إدارة.',
            )

        # صفحة الهبوط: يكفي أن يكون موظفًا — وقد تحقّقنا من ذلك فوق.
        if route in STAFF_ONLY_ROUTES:
            return None

        needed = DASHBOARD_PERMISSIONS.get(route)
        if needed is None:
            # الافتراضي منع: صفحة إدارية جديدة غير مسجّلة في الجدول.
            logger.warning('مسار إداري بلا صلاحية مسجّلة: %s', route)
            return self._denied(
                request,
                'الصفحة دي لسه مش متاحة لدورك.',
            )

        if not user_can(user, needed):
            return self._denied(
                request,
                'دورك مش بيسمح بالعملية دي.',
            )

        return None

    def _denied(self, request, message):
        try:
            return render(
                request,
                'dashboard/denied.html',
                {'message': message},
                status=403,
            )
        except Exception:
            # القالب قد لا يوجد بعد — لا نُسقط الطلب بخطأ 500 بسبب ذلك.
            messages.error(request, message)
            return redirect('dashboard:index')


class DashboardAuditMiddleware:
    """
    تسجّل العمليات المؤثّرة في نفس `AuditLog` الذي يستعمله الـAPI.

    سجل واحد للسطحين: سؤال "مين عطّل المحل ده؟" له إجابة واحدة سواء
    نُفّذت من اللوحة أو من التطبيق.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        match = getattr(request, 'resolver_match', None)
        if match is None or match.app_name != 'dashboard':
            return response

        route = match.url_name or ''
        action = MUTATING_ROUTES.get(route)

        # نسجّل الناجح فقط: محاولة فاشلة لم تغيّر شيئًا، وتسجيلها
        # يملأ السجل بضجيج يخفي التغييرات الحقيقية.
        if (
            action is None
            or request.method not in {'POST', 'PUT', 'PATCH', 'DELETE'}
            or response.status_code >= 400
            or not request.user.is_authenticated
        ):
            return response

        self._record(request, route, action, view_kwargs=match.kwargs)
        return response

    @staticmethod
    def _record(request, route, action, view_kwargs):
        from apps.administration import services
        from apps.administration.models import AuditLog

        valid = {choice[0] for choice in AuditLog.Action.choices}
        mapped = action if action in valid else AuditLog.Action.UPDATE

        target = ' · '.join(f'{k}={v}' for k, v in (view_kwargs or {}).items())

        services.record(
            actor=request.user,
            action=mapped,
            target=None,
            target_label=f'لوحة الويب · {route}{f" ({target})" if target else ""}',
            changes={'route': route, 'method': request.method},
            request=request,
        )
