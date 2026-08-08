"""
Login Handoff — Web side
=========================
يستهلك توكن التسليم ويسجّل دخول المستخدم، ثم يوجّهه لخطوته الفعلية.

الوجهة تُحسب من محرك الرحلة نفسه (`build_onboarding_state`) لا من رأي
منفصل هنا — نفس المصدر الذي يبني بانر لوحة صاحب النشاط. اختار التاجر
الخطة على التطبيق، فيصل هنا ليجد "أنشئ نشاطك" جاهزة، لا صفحة عامة
يبحث فيها عن نفسه من جديد.
"""

from django.contrib.auth import login
from django.shortcuts import redirect, render
from django.urls import reverse

from apps.accounts.handoff import LoginHandoffToken


def consume_handoff(request, token):
    user = LoginHandoffToken.consume(token, purpose='onboarding')

    if user is None:
        return render(
            request,
            'dashboard/handoff_expired.html',
            status=410,  # Gone — الرابط كان صالحًا وانتهى، لا أنه خطأ.
        )

    # ‏backend صريح: المستخدم لم يمرّ بنموذج كلمة مرور هنا، والاعتماد
    # الافتراضي على أول backend مُعرَّف قد لا يكون هو المقصود لو تعددت.
    login(request, user, backend='django.contrib.auth.backends.ModelBackend')

    return redirect('dashboard:onboarding_continue')


def onboarding_continue(request):
    """يقرأ حالة الرحلة الحقيقية ويوجّه المستخدم لخطوته التالية بالضبط."""
    if not request.user.is_authenticated:
        return redirect('dashboard:staff_login')

    try:
        from apps.dashboard.views.owner import _SETUP_ACTIONS
        from apps.subscriptions.onboarding import (
            build_onboarding_state,
            get_or_create_onboarding,
        )

        state = build_onboarding_state(get_or_create_onboarding(request.user))
        spec = _SETUP_ACTIONS.get(state.get('next_action', ''))

        if spec and spec.get('url_name'):
            return redirect(reverse(spec['url_name']))
    except Exception:  # noqa: BLE001
        # فشل حساب الخطوة لا يجوز أن يترك المستخدم على صفحة توكن منتهية
        # الصلاحية — يصل دائمًا إلى مكان آمن يعمل: لوحته.
        import logging

        logging.getLogger('dashboard.onboarding').exception(
            'تعذّر تحديد وجهة الاستمرار بعد التسليم'
        )

    return redirect('dashboard:owner_dashboard')
