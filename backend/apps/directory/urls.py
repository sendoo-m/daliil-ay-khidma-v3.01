"""
Directory App URLs
==================
جميع روابط تطبيق الدليل
"""

from django.urls import path
from . import views

app_name = 'directory'

urlpatterns = [
    # Home
    path('', views.home, name='home'),
    
    # Search (أضف هذا السطر)
    path('search/', views.business_search, name='business_search'),
     
    # Browse by Location
    path('governorates/', views.governorate_list, name='governorate_list'),
    path('governorate/<slug:slug>/', views.governorate_detail, name='governorate_detail'),
    path('city/<slug:slug>/', views.city_detail, name='city_detail'),
    path('district/<slug:slug>/', views.district_detail, name='district_detail'),
    
    # Business
    path('businesses/', views.business_list, name='business_list'),
    path('business/<slug:slug>/', views.business_detail, name='business_detail'),
    path('business/add/', views.business_create, name='business_create'),
    path('business/<slug:slug>/edit/', views.business_update, name='business_update'),
    path('business/<slug:slug>/delete/', views.business_delete, name='business_delete'),
    
    # User Actions
    path('business/<slug:slug>/favorite/', views.favorite_toggle, name='favorite_toggle'),
    path('my-businesses/', views.my_businesses, name='my_businesses'),
    path('my-favorites/', views.my_favorites, name='my_favorites'),
    
    # AJAX/API Endpoints
    path('api/business/<slug:slug>/increment-view/', views.increment_view, name='increment_view'),
    path('api/business/<slug:slug>/increment-click/', views.increment_click, name='increment_click'),

    # Map View (أضف هذا السطر)
    path('map/', views.map_view, name='map'),
    
    # Search
    path('search/', views.business_search, name='business_search'),
 
    # Shops
    path('shops/',                    views.shops_list,    name='shops_list'),
    path('shops/<slug:slug>/',        views.shop_detail,   name='shop_detail'),

    # Crafts
    path('crafts/',                   views.crafts_list,   name='crafts_list'),
    path('crafts/<slug:slug>/',       views.craft_detail,  name='craft_detail'),

    # Services
    path('services/',                 views.services_list, name='services_list'),
    path('services/<slug:slug>/',     views.service_detail, name='service_detail'),

]
