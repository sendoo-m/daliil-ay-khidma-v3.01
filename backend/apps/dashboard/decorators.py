"""
Dashboard Decorators
====================
Custom decorators for dashboard access control
"""

"""
Dashboard Decorators
====================
"""

from functools import wraps
from django.shortcuts import redirect
from django.contrib import messages


def business_owner_required(view_func):
    """يتطلب وجود محل للمستخدم"""
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect('accounts:login')
        if not request.user.businesses.exists():
            messages.error(request, 'يجب أن يكون لديك محل لاستخدام هذه الميزة')
            return redirect('dashboard:business_create')
        return view_func(request, *args, **kwargs)
    return wrapper


def admin_required(view_func):
    """يتطلب صلاحيات الأدمن"""
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect('accounts:login')
        if not (request.user.is_staff or request.user.is_superuser):
            messages.error(request, 'ليس لديك صلاحية للوصول لهذه الصفحة')
            return redirect('dashboard:index')  # ✅ index مش owner_dashboard
        return view_func(request, *args, **kwargs)
    return wrapper

# from functools import wraps
# from django.contrib.auth.decorators import login_required
# from django.shortcuts import redirect
# from django.contrib import messages


# def business_owner_required(view_func):
#     """Decorator to require user to be a business owner"""
#     @wraps(view_func)
#     @login_required
#     def wrapper(request, *args, **kwargs):
#         # Check if user has at least one business
#         if not request.user.businesses.exists():
#             messages.error(request, 'يجب أن يكون لديك محل لاستخدام هذه الميزة')
#             return redirect('dashboard:create_business')
#         return view_func(request, *args, **kwargs)
#     return wrapper


# def admin_required(view_func):
#     """Decorator to require user to be admin/staff"""
#     @wraps(view_func)
#     @login_required
#     def wrapper(request, *args, **kwargs):
#         if not request.user.is_staff:
#             messages.error(request, 'ليس لديك صلاحية للوصول لهذه الصفحة')
#             return redirect('dashboard:owner_dashboard')
#         return view_func(request, *args, **kwargs)
#     return wrapper
