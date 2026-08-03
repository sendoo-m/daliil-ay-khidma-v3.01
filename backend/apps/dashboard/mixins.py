from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import redirect
from django.contrib import messages


class AdminRequiredMixin(LoginRequiredMixin):
    """يسمح فقط للمستخدمين الـ staff (أدمن)"""

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return self.handle_no_permission()

        if not request.user.is_staff:
            messages.error(request, "ليس لديك صلاحية الوصول للوحة التحكم.")
            return redirect('/')

        return super().dispatch(request, *args, **kwargs)


class OwnerRequiredMixin(LoginRequiredMixin):
    """يسمح فقط لأصحاب المحلات"""

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return self.handle_no_permission()

        if request.user.is_staff or not getattr(request.user, 'is_business_owner', False):
            messages.error(request, "ليس لديك صلاحية الوصول للوحة صاحب المحل.")
            return redirect('/')

        return super().dispatch(request, *args, **kwargs)
