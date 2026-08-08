"""
Accounts URL Configuration
"""
from django.urls import path
from . import views
from .magic_link import redeem_magic_link

app_name = 'accounts'

urlpatterns = [
    # ── Auth ──
    path('login/',    views.LoginView.as_view(),    name='login'),
    path('logout/',   views.LogoutView.as_view(),   name='logout'),
    path('register/', views.RegisterView.as_view(), name='register'),

    # ── Profile ──
    path('profile/',         views.profile_view,          name='profile'),
    path('change-password/', views.password_change_view,  name='change_password'),

    # ── Password Reset ──
    path('password-reset/',
         views.PasswordResetView.as_view(),         name='password_reset'),
    path('password-reset/done/',
         views.PasswordResetDoneView.as_view(),     name='password_reset_done'),
    path('password-reset/confirm/<uidb64>/<token>/',
         views.PasswordResetConfirmView.as_view(),  name='password_reset_confirm'),
    path('password-reset/complete/',
         views.PasswordResetCompleteView.as_view(), name='password_reset_complete'),

    # ── Magic-Link Web Handoff ──
    # Flutter يفتح هذا الـ URL في WebView — يُسجَّل الدخول ويُحوَّل للخطط
    path('magic/', redeem_magic_link, name='magic_link_redeem'),
]
