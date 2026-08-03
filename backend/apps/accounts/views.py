"""
Accounts Views
==============
Views for user authentication and profile management
"""

from django.contrib.auth import login, authenticate, update_session_auth_hash
from django.contrib.auth.views import (
    LogoutView as DjangoLogoutView,
    PasswordResetView as DjangoPasswordResetView,
    PasswordResetDoneView as DjangoPasswordResetDoneView,
    PasswordResetConfirmView as DjangoPasswordResetConfirmView,
    PasswordResetCompleteView as DjangoPasswordResetCompleteView,
)
from django.contrib.auth.decorators import login_required
from django.contrib.auth.forms import PasswordChangeForm
from django.shortcuts import render, redirect
from django.contrib import messages
from django.views import View
from django.views.decorators.http import require_http_methods
from django.views.decorators.cache import never_cache
from django.utils.decorators import method_decorator
from django.urls import reverse_lazy

from .forms import RegistrationForm
from .models import User


# ========================================
# LOGIN VIEW
# ========================================
@method_decorator(never_cache, name='dispatch')
class LoginView(View):
    """صفحة تسجيل الدخول"""
    template_name = 'accounts/login.html'
    
    def get(self, request):
        # If already logged in, redirect based on role
        if request.user.is_authenticated:
            if request.user.is_staff or request.user.is_superuser:
                return redirect('dashboard:index')
            return redirect('dashboard:index')
        
        return render(request, self.template_name)
    
    def post(self, request):
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '').strip()
        
        if not username or not password:
            messages.error(request, 'الرجاء إدخال اسم المستخدم وكلمة المرور')
            return render(request, self.template_name)
        
        # Authenticate user
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            # Login successful
            login(request, user)
            messages.success(request, f'مرحباً بك {user.get_full_name() or user.username}!')
            
            # Redirect based on role
            next_url = request.GET.get('next')
            if next_url:
                return redirect(next_url)
            elif user.is_staff or user.is_superuser:
                return redirect('dashboard:index')
            else:
                return redirect('dashboard:index')
        else:
            # Authentication failed
            messages.error(request, 'اسم المستخدم أو كلمة المرور غير صحيحة')
        
        return render(request, self.template_name)


# Keep the function version for backward compatibility
@never_cache
@require_http_methods(["GET", "POST"])
def login_view(request):
    """صفحة تسجيل الدخول (Function-based)"""
    # If already logged in, redirect based on role
    if request.user.is_authenticated:
        if request.user.is_staff or request.user.is_superuser:
            return redirect('dashboard:index')
        return redirect('dashboard:index')
    
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '').strip()
        
        if not username or not password:
            messages.error(request, 'الرجاء إدخال اسم المستخدم وكلمة المرور')
            return render(request, 'accounts/login.html')
        
        # Authenticate user
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            # Login successful
            login(request, user)
            messages.success(request, f'مرحباً بك {user.get_full_name() or user.username}!')
            
            # Redirect based on role
            next_url = request.GET.get('next')
            if next_url:
                return redirect(next_url)
            elif user.is_staff or user.is_superuser:
                return redirect('dashboard:index')
            else:
                return redirect('dashboard:index')
        else:
            # Authentication failed
            messages.error(request, 'اسم المستخدم أو كلمة المرور غير صحيحة')
    
    return render(request, 'accounts/login.html')


# ========================================
# LOGOUT VIEW
# ========================================
class LogoutView(DjangoLogoutView):
    """صفحة تسجيل الخروج"""
    http_method_names = ['get', 'post', 'options']
    next_page = 'accounts:login'
    
    def get(self, request, *args, **kwargs):
        return self.post(request, *args, **kwargs)


# ========================================
# REGISTER VIEW
# ========================================
class RegisterView(View):
    """صفحة التسجيل"""
    template_name = 'accounts/register.html'

    def get(self, request):
        # If already logged in, redirect
        if request.user.is_authenticated:
            return redirect('dashboard:index')

        return render(
            request,
            self.template_name,
            {'form': RegistrationForm()},
        )

    def post(self, request):
        form = RegistrationForm(request.POST)

        if form.is_valid():
            user = form.save()

            # Log the user in
            login(request, user)
            messages.success(
                request,
                f'مرحباً بك {user.get_full_name() or user.username}! تم إنشاء حسابك بنجاح',
            )
            return redirect('dashboard:index')

        return render(request, self.template_name, {'form': form})


# ========================================
# PROFILE VIEW
# ========================================
@login_required
def profile_view(request):
    """صفحة الملف الشخصي"""
    if request.method == 'POST':
        # Update profile
        user = request.user
        user.first_name = request.POST.get('first_name', '').strip()
        user.last_name = request.POST.get('last_name', '').strip()
        user.email = request.POST.get('email', '').strip()
        
        try:
            user.save()
            messages.success(request, 'تم تحديث الملف الشخصي بنجاح')
        except Exception as e:
            messages.error(request, f'حدث خطأ: {str(e)}')
        
        return redirect('accounts:profile')
    
    return render(request, 'accounts/profile.html')


# ========================================
# PASSWORD CHANGE VIEW
# ========================================
@login_required
def password_change_view(request):
    """تغيير كلمة المرور"""
    if request.method == 'POST':
        form = PasswordChangeForm(request.user, request.POST)
        if form.is_valid():
            user = form.save()
            update_session_auth_hash(request, user)
            messages.success(request, 'تم تغيير كلمة المرور بنجاح')
            return redirect('accounts:profile')
        else:
            for error in form.errors.values():
                messages.error(request, error)
    else:
        form = PasswordChangeForm(request.user)
    
    return render(request, 'accounts/password_change.html', {'form': form})


# ========================================
# PASSWORD RESET VIEWS
# ========================================
class PasswordResetView(DjangoPasswordResetView):
    """إعادة تعيين كلمة المرور - طلب"""
    template_name = 'accounts/password_reset.html'
    email_template_name = 'accounts/password_reset_email.html'
    subject_template_name = 'accounts/password_reset_subject.txt'
    success_url = reverse_lazy('accounts:password_reset_done')


class PasswordResetDoneView(DjangoPasswordResetDoneView):
    """إعادة تعيين كلمة المرور - تم الإرسال"""
    template_name = 'accounts/password_reset_done.html'


class PasswordResetConfirmView(DjangoPasswordResetConfirmView):
    """إعادة تعيين كلمة المرور - تأكيد"""
    template_name = 'accounts/password_reset_confirm.html'
    success_url = reverse_lazy('accounts:password_reset_complete')


class PasswordResetCompleteView(DjangoPasswordResetCompleteView):
    """إعادة تعيين كلمة المرور - اكتمل"""
    template_name = 'accounts/password_reset_complete.html'
