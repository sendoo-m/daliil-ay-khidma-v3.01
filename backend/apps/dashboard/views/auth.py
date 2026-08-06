"""
Dashboard — Staff Authentication
================================
شاشة دخول خاصة بالموظفين.

قبلها كان `staff_member_required` يحوّل على شاشة دخول Django الخام —
واجهة إنجليزية بهوية Django لا بهوية المنصة، وتُربك الموظف الجديد.
"""

from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.shortcuts import redirect, render
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_protect

from apps.administration.permissions import get_staff_profile


@never_cache
@csrf_protect
def staff_login(request):
    if request.user.is_authenticated and (
        request.user.is_superuser or get_staff_profile(request.user)
    ):
        return redirect(request.GET.get('next') or 'dashboard:admin_home')

    if request.method != 'POST':
        return render(request, 'dashboard/login.html')

    username = (request.POST.get('username') or '').strip()
    password = request.POST.get('password') or ''
    user = authenticate(request, username=username, password=password)

    # رسالة واحدة للاسم الخطأ ولكلمة المرور الخطأ: التمييز بينهما يكشف
    # أي أسماء المستخدمين موجودة فعلًا.
    if user is None:
        messages.error(request, 'اسم المستخدم أو كلمة المرور غير صحيحة.')
        return render(request, 'dashboard/login.html', {'username': username})

    if not user.is_active:
        messages.error(request, 'الحساب ده متوقف. كلّم الإدارة.')
        return render(request, 'dashboard/login.html', {'username': username})

    if not (user.is_superuser or get_staff_profile(user)):
        messages.error(
            request,
            'بياناتك صحيحة، لكن الحساب ده مش مسجَّل كموظف إدارة. '
            'لو عندك محل أو خدمة، ادخل من صفحة أصحاب الأنشطة.',
        )
        return render(request, 'dashboard/login.html', {'username': username})

    login(request, user)

    profile = get_staff_profile(user)
    if profile is not None:
        profile.touch_login()

    return redirect(request.GET.get('next') or 'dashboard:admin_home')


def staff_logout(request):
    logout(request)
    return redirect('dashboard:staff_login')
