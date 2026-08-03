# apps/core/urls.py
from django.urls import path
from . import views
from .views import SiteSettingsPublicView, SiteSettingsAdminView


app_name = 'core'


urlpatterns = [
    path('', views.home, name='home'),
    path('about/', views.about, name='about'),
    path('contact/', views.contact, name='contact'),
    path('privacy/', views.privacy_policy, name='privacy_policy'),       # ← جديد
    path('terms/', views.terms_of_service, name='terms_of_service'),     # ← جديد
    path('support/', views.support, name='support'),                     # ← جديد
    path('test-icons/', views.test_icons, name='test_icons'),
    path('set-language/', views.set_language, name='set_language'),
    path("settings/",       SiteSettingsPublicView.as_view(),  name="site-settings-public"),
    path("settings/admin/", SiteSettingsAdminView.as_view(),   name="site-settings-admin"),
]