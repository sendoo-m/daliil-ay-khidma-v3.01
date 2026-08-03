"""
Dashboard URLs
==============
ملف واحد - بدون include لملفات تانية
"""

from django.urls import path
from apps.dashboard.views.main import (
    index, get_cities_by_governorate, get_districts_by_city,
    get_districts_by_governorate, profile, settings,
    notifications, help_center,
)
from apps.dashboard.views.business import (
    business_list, business_create, business_update,
    business_detail, business_delete,
)
from apps.dashboard.views.product import (
    product_list, product_create, product_update, product_delete,
    admin_products_list,
)
from apps.dashboard.views.deal import (
    deal_list, deal_create, deal_update, deal_delete,
)
from apps.dashboard.views.review import (
    review_list, review_reply, review_approve, review_reject,
)
from apps.dashboard.views.owner import owner_dashboard
from apps.dashboard.views import admin_views, admin_crud
from apps.dashboard.views import subscription_admin


app_name = 'dashboard'


urlpatterns = [
    path('', index, name='index'),

    path('profile/', profile, name='profile'),
    path('settings/', settings, name='settings'),
    path('notifications/', notifications, name='notifications'),
    path('help/', help_center, name='help_center'),

    path('ajax/cities/', get_cities_by_governorate, name='ajax_cities'),
    path('ajax/districts/', get_districts_by_city, name='ajax_districts'),
    path('ajax/districts-by-gov/', get_districts_by_governorate, name='ajax_districts_by_gov'),

    path('owner/', owner_dashboard, name='owner_dashboard'),
    path('owner/businesses/', business_list, name='business_list'),
    path('owner/businesses/create/', business_create, {'business_type': 'shop'}, name='business_create'),
    path('owner/businesses/create/craft/', business_create, {'business_type': 'craft'}, name='business_create_craft'),
    path('owner/businesses/<slug:slug>/', business_detail, name='business_detail'),
    path('owner/businesses/<slug:slug>/edit/', business_update, name='business_update'),
    path('owner/businesses/<slug:slug>/delete/', business_delete, name='business_delete'),
    path('owner/products/', product_list, name='product_list'),
    path('owner/products/create/', product_create, name='product_create'),
    path('owner/products/<slug:slug>/edit/', product_update, name='product_update'),
    path('owner/products/<slug:slug>/delete/', product_delete, name='product_delete'),
    path('owner/deals/', deal_list, name='deal_list'),
    path('owner/deals/create/', deal_create, name='deal_create'),
    path('owner/deals/<slug:slug>/edit/', deal_update, name='deal_update'),
    path('owner/deals/<slug:slug>/delete/', deal_delete, name='deal_delete'),
    path('owner/reviews/', review_list, name='review_list'),
    path('owner/reviews/<int:pk>/reply/', review_reply, name='review_reply'),
    path('owner/reviews/<int:pk>/approve/', review_approve, name='review_approve'),
    path('owner/reviews/<int:pk>/reject/', review_reject, name='review_reject'),

    path('admin/', admin_views.admin_dashboard_home, name='admin_home'),

    path('admin/subscriptions/', subscription_admin.subscription_dashboard, name='admin_subscriptions_home'),
    path('admin/subscriptions/list/', subscription_admin.subscription_list, name='admin_subscriptions_list'),
    path('admin/subscriptions/plans/', subscription_admin.subscription_plan_list, name='admin_subscription_plans'),
    path('admin/subscriptions/plans/<int:plan_id>/edit/', subscription_admin.subscription_plan_edit, name='admin_subscription_plan_edit'),
    path('admin/subscriptions/<int:subscription_id>/', subscription_admin.subscription_detail, name='admin_subscription_detail'),
    path('admin/subscriptions/<int:subscription_id>/activate/', subscription_admin.subscription_activate, name='admin_subscription_activate'),
    path('admin/subscriptions/<int:subscription_id>/cancel/', subscription_admin.subscription_cancel, name='admin_subscription_cancel'),

    path('admin/users/', admin_views.admin_users_list, name='admin_users_list'),
    path('admin/users/create/', admin_crud.admin_user_create, name='admin_user_create'),
    path('admin/users/<int:user_id>/', admin_views.admin_user_detail, name='admin_user_detail'),
    path('admin/users/<int:user_id>/edit/', admin_crud.admin_user_edit_view, name='admin_user_edit'),
    path('admin/users/<int:user_id>/delete/', admin_views.admin_user_delete, name='admin_user_delete'),
    path('admin/users/<int:user_id>/toggle/', admin_views.admin_user_toggle_status, name='admin_user_toggle'),

    path('admin/businesses/', admin_views.admin_businesses_list, name='admin_businesses_list'),
    path('admin/businesses/create/', admin_crud.admin_business_create, name='admin_business_create'),
    path('admin/businesses/<int:business_id>/', admin_views.admin_business_detail, name='admin_business_detail'),
    path('admin/businesses/<int:business_id>/edit/', admin_crud.admin_business_edit_view, name='admin_business_edit'),
    path('admin/businesses/<int:business_id>/verify/', admin_views.admin_business_verify, name='admin_business_verify'),
    path('admin/businesses/<int:business_id>/feature/', admin_views.admin_business_feature, name='admin_business_feature'),
    path('admin/businesses/<int:business_id>/toggle/', admin_views.admin_business_toggle_status, name='admin_business_toggle'),
    path('admin/businesses/<int:business_id>/delete/', admin_views.admin_business_delete, name='admin_business_delete'),

    path('admin/products/', admin_products_list, name='admin_products_list'),
    path('admin/products/create/', admin_crud.admin_product_create, name='admin_product_create'),
    path('admin/products/create/<int:business_id>/', admin_crud.admin_product_create, name='admin_product_create_for_business'),
    path('admin/products/<int:product_id>/', admin_views.admin_product_detail, name='admin_product_detail'),
    path('admin/products/<int:product_id>/edit/', admin_crud.admin_product_edit_view, name='admin_product_edit'),
    path('admin/products/<int:product_id>/toggle/', admin_views.admin_product_toggle_status, name='admin_product_toggle'),
    path('admin/products/<int:product_id>/feature/', admin_views.admin_product_feature, name='admin_product_feature'),
    path('admin/products/<int:product_id>/delete/', admin_views.admin_product_delete, name='admin_product_delete'),

    path('admin/deals/', admin_views.admin_deals_list, name='admin_deals_list'),
    path('admin/deals/create/', admin_crud.admin_deal_create, name='admin_deal_create'),
    path('admin/deals/create/<int:business_id>/', admin_crud.admin_deal_create, name='admin_deal_create_for_business'),
    path('admin/deals/<int:deal_id>/', admin_views.admin_deal_detail, name='admin_deal_detail'),
    path('admin/deals/<int:deal_id>/edit/', admin_crud.admin_deal_edit_view, name='admin_deal_edit'),
    path('admin/deals/<int:deal_id>/approve/', admin_views.admin_deal_approve, name='admin_deal_approve'),
    path('admin/deals/<int:deal_id>/feature/', admin_views.admin_deal_feature, name='admin_deal_feature'),
    path('admin/deals/<int:deal_id>/delete/', admin_views.admin_deal_delete, name='admin_deal_delete'),

    path('admin/reviews/', admin_views.admin_reviews_list, name='admin_reviews_list'),
    path('admin/reviews/<int:review_id>/approve/', admin_views.admin_review_approve, name='admin_review_approve'),
    path('admin/reviews/<int:review_id>/reject/', admin_views.admin_review_reject, name='admin_review_reject'),
    path('admin/reviews/<int:review_id>/delete/', admin_views.admin_review_delete, name='admin_review_delete'),

    path('admin/categories/', admin_views.admin_categories_list, name='admin_categories_list'),
    path('admin/categories/create/', admin_crud.admin_category_create_view, name='admin_category_create'),
    path('admin/categories/<int:category_id>/edit/', admin_crud.admin_category_edit_view, name='admin_category_edit'),
    path('admin/categories/<int:category_id>/delete/', admin_views.admin_category_delete, name='admin_category_delete'),

    path('admin/location/governorates/', admin_crud.admin_governorates_list, name='admin_governorates_list'),
    path('admin/location/governorates/create/', admin_crud.admin_governorate_create, name='admin_governorate_create'),
    path('admin/location/governorates/<int:gov_id>/edit/', admin_crud.admin_governorate_edit, name='admin_governorate_edit'),
    path('admin/location/governorates/<int:gov_id>/delete/', admin_crud.admin_governorate_delete, name='admin_governorate_delete'),
    path('admin/location/cities/', admin_crud.admin_cities_list, name='admin_cities_list'),
    path('admin/location/cities/create/', admin_crud.admin_city_create, name='admin_city_create'),
    path('admin/location/cities/<int:city_id>/edit/', admin_crud.admin_city_edit, name='admin_city_edit'),
    path('admin/location/cities/<int:city_id>/delete/', admin_crud.admin_city_delete, name='admin_city_delete'),
    path('admin/location/districts/', admin_crud.admin_districts_list, name='admin_districts_list'),
    path('admin/location/districts/create/', admin_crud.admin_district_create, name='admin_district_create'),
    path('admin/location/districts/<int:district_id>/edit/', admin_crud.admin_district_edit, name='admin_district_edit'),
    path('admin/location/districts/<int:district_id>/delete/', admin_crud.admin_district_delete, name='admin_district_delete'),

    path('admin/analytics/', admin_views.admin_analytics, name='admin_analytics'),
    path('admin/reports/', admin_views.admin_reports, name='admin_reports'),
    path('admin/settings/', admin_views.admin_settings, name='admin_settings'),
    path('admin/settings/clear-cache/', admin_views.admin_clear_cache, name='admin_clear_cache'),
    path('admin/ajax/districts/', admin_crud.ajax_get_districts, name='admin_ajax_districts'),

    path('settings/', admin_crud.AdminSettingsView.as_view(), name='settings'),
]
