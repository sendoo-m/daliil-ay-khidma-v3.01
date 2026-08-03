"""
Admin Dashboard URLs
====================
URLs for admin dashboard - full control panel
"""

from django.urls import path
from .views import admin_views, admin_crud

app_name = 'admin_dashboard'

urlpatterns = [
    # Admin Dashboard Home
    path('', admin_views.admin_dashboard_home, name='home'),
    
    # Statistics & Analytics
    path('analytics/', admin_views.admin_analytics, name='analytics'),
    path('reports/', admin_views.admin_reports, name='reports'),
    
    # Users Management
    path('users/', admin_views.admin_users_list, name='users_list'),
    path('users/create/', admin_crud.admin_user_create, name='user_create'),
    path('users/<int:user_id>/', admin_views.admin_user_detail, name='user_detail'),
    path('users/<int:user_id>/edit/', admin_crud.admin_user_edit_view, name='user_edit'),
    path('users/<int:user_id>/delete/', admin_views.admin_user_delete, name='user_delete'),
    path('users/<int:user_id>/toggle-status/', admin_views.admin_user_toggle_status, name='user_toggle_status'),
    
    # Businesses Management
    path('businesses/', admin_views.admin_businesses_list, name='businesses_list'),
    path('businesses/create/', admin_crud.admin_business_create, name='business_create'),
    path('businesses/<int:business_id>/', admin_views.admin_business_detail, name='business_detail'),
    path('businesses/<int:business_id>/edit/', admin_crud.admin_business_edit_view, name='business_edit'),
    path('businesses/<int:business_id>/verify/', admin_views.admin_business_verify, name='business_verify'),
    path('businesses/<int:business_id>/feature/', admin_views.admin_business_feature, name='business_feature'),
    path('businesses/<int:business_id>/toggle-status/', admin_views.admin_business_toggle_status, name='business_toggle_status'),
    path('businesses/<int:business_id>/delete/', admin_views.admin_business_delete, name='business_delete'),
    
    # Products Management
    path('products/', admin_views.admin_products_list, name='products_list'),
    path('products/create/', admin_crud.admin_product_create, name='product_create'),
    path('products/create/<int:business_id>/', admin_crud.admin_product_create, name='product_create_for_business'),
    path('products/<int:product_id>/', admin_views.admin_product_detail, name='product_detail'),
    path('products/<int:product_id>/edit/', admin_crud.admin_product_edit_view, name='product_edit'),
    path('products/<int:product_id>/toggle-status/', admin_views.admin_product_toggle_status, name='product_toggle_status'),
    path('products/<int:product_id>/feature/', admin_views.admin_product_feature, name='product_feature'),
    path('products/<int:product_id>/delete/', admin_views.admin_product_delete, name='product_delete'),
    
    # Deals Management
    path('deals/', admin_views.admin_deals_list, name='deals_list'),
    path('deals/create/', admin_crud.admin_deal_create, name='deal_create'),
    path('deals/create/<int:business_id>/', admin_crud.admin_deal_create, name='deal_create_for_business'),
    path('deals/<int:deal_id>/', admin_views.admin_deal_detail, name='deal_detail'),
    path('deals/<int:deal_id>/edit/', admin_crud.admin_deal_edit_view, name='deal_edit'),
    path('deals/<int:deal_id>/approve/', admin_views.admin_deal_approve, name='deal_approve'),
    path('deals/<int:deal_id>/feature/', admin_views.admin_deal_feature, name='deal_feature'),
    path('deals/<int:deal_id>/delete/', admin_views.admin_deal_delete, name='deal_delete'),
    
    # Reviews Management
    path('reviews/', admin_views.admin_reviews_list, name='reviews_list'),
    path('reviews/<int:review_id>/approve/', admin_views.admin_review_approve, name='review_approve'),
    path('reviews/<int:review_id>/reject/', admin_views.admin_review_reject, name='review_reject'),
    path('reviews/<int:review_id>/delete/', admin_views.admin_review_delete, name='review_delete'),
    
    # Categories Management
    path('categories/', admin_views.admin_categories_list, name='categories_list'),
    path('categories/create/', admin_crud.admin_category_create_view, name='category_create'),
    path('categories/<int:category_id>/edit/', admin_crud.admin_category_edit_view, name='category_edit'),
    path('categories/<int:category_id>/delete/', admin_views.admin_category_delete, name='category_delete'),
    
    # System Settings
    path('settings/', admin_views.admin_settings, name='settings'),
    path('settings/cache/clear/', admin_views.admin_clear_cache, name='clear_cache'),

        # AJAX Endpoints
    path('ajax/districts/', admin_crud.ajax_get_districts, name='ajax_get_districts'),

    # Location Management
    path('locations/governorates/', admin_crud.admin_governorates_list, name='governorates_list'),
    path('locations/governorates/create/', admin_crud.admin_governorate_create, name='governorate_create'),
    path('locations/governorates/<int:gov_id>/edit/', admin_crud.admin_governorate_edit, name='governorate_edit'),
    path('locations/governorates/<int:gov_id>/delete/', admin_crud.admin_governorate_delete, name='governorate_delete'),

    path('locations/cities/', admin_crud.admin_cities_list, name='cities_list'),
    path('locations/cities/create/', admin_crud.admin_city_create, name='city_create'),
    path('locations/cities/<int:city_id>/edit/', admin_crud.admin_city_edit, name='city_edit'),
    path('locations/cities/<int:city_id>/delete/', admin_crud.admin_city_delete, name='city_delete'),

    path('locations/districts/', admin_crud.admin_districts_list, name='districts_list'),
    path('locations/districts/create/', admin_crud.admin_district_create, name='district_create'),
    path('locations/districts/<int:district_id>/edit/', admin_crud.admin_district_edit, name='district_edit'),
    path('locations/districts/<int:district_id>/delete/', admin_crud.admin_district_delete, name='district_delete'),

]
