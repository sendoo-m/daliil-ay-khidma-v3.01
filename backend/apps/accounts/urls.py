"""
Accounts URL Configuration
"""
from django.urls import path
from . import views
from .magic_link import issue_magic_link, redeem_magic_link

app_name = 'account'

urlpatterns = [
    # ── Auth ──
    path('login/',    views.login_view,    name='login'),
    path('logout/',   views.logout_view,   name='logout'),
    path('register/', views.register_view, name='register'),

    # ── Profile ──
    path('profile/',         views.profile_view,          name='profile'),
    path('profile/edit/',    views.profile_edit_view,      name='profile_edit'),
    path('change-password/', views.change_password_view,  name='change_password'),

    # ── Magic-Link Web Handoff ──
    # الموبايل يستدعي هذا الـ endpoint للحصول على رابط الدخول
    path('magic/',           redeem_magic_link,  name='magic_link_redeem'),
]

# ── API endpoint (مُضمَّن هنا ليكون تحت /api/auth/ في urls.py الرئيسي)
apiurlpatterns = [
    path('magic-link/', issue_magic_link, name='api_magic_link_issue'),
]
