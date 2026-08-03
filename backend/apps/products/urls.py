"""
Products URLs
=============
مسارات تطبيق المنتجات والخدمات
"""

from django.urls import path
from . import views

app_name = 'products'

urlpatterns = [
    # Public URLs
    path('', views.product_list, name='product_list'),
    path('detail/<slug:slug>/', views.product_detail, name='product_detail'),
    path('business/<slug:business_slug>/', views.products_by_business, name='products_by_business'),
    
    # Dashboard URLs
    path('my/', views.my_products, name='my_products'),
    path('create/', views.product_create, name='product_create'),
    path('edit/<slug:slug>/', views.product_edit, name='product_edit'),
    path('delete/<slug:slug>/', views.product_delete, name='product_delete'),
    path('toggle/<slug:slug>/', views.product_toggle_availability, name='toggle_availability'),
    
    # AJAX URLs
    path('ajax/view/<int:product_id>/', views.increment_product_view, name='ajax_increment_view'),
]
