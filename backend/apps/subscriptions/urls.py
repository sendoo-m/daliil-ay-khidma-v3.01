"""
Subscriptions URLs
==================
مسارات تطبيق الاشتراكات
"""

from django.urls import path
from django.views.generic import RedirectView

from . import views

app_name = 'subscriptions'

urlpatterns = [
    # Make /subscriptions/ a useful public entry point.
    path(
        '',
        RedirectView.as_view(
            pattern_name='subscriptions:pricing_comparison',
            permanent=False,
        ),
        name='index',
    ),

    # Public URLs
    path('plans/', views.plans_list, name='plans_list'),
    path('plans/<str:plan_name>/', views.plan_detail, name='plan_detail'),
    path('pricing/', views.pricing_comparison, name='pricing_comparison'),

    # User Subscription Management
    path('my/', views.my_subscription, name='my_subscription'),
    path('subscribe/<str:plan_name>/', views.subscribe, name='subscribe'),
    path('payment/<int:subscription_id>/', views.payment, name='payment'),
    path('cancel/', views.cancel_subscription, name='cancel_subscription'),
    path('toggle-auto-renew/', views.toggle_auto_renew, name='toggle_auto_renew'),
    path('upgrade/<str:plan_name>/', views.upgrade_subscription, name='upgrade'),

    # AJAX URLs
    path(
        'ajax/price/<str:plan_name>/<str:duration>/',
        views.get_plan_price,
        name='ajax_get_price',
    ),
]
