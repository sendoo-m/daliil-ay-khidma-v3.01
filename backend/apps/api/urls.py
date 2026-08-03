"""
API URLs - Enhanced with JWT Authentication
============================================
Main API router with all endpoints
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

from .views.directory import (
    GovernorateViewSet, CityViewSet, DistrictViewSet,
    CategoryViewSet, BusinessViewSet, FavoriteViewSet
)
from .views.products import ProductViewSet
from .views.deals import DealViewSet, DealClaimViewSet
from .views.subscriptions import SubscriptionPlanViewSet, SubscriptionViewSet

# JWT Authentication views
from .views.auth import (
    CustomTokenObtainPairView,
    register,
    get_user_profile,
    update_user_profile,
    change_password
)

app_name = 'api'

# Create router
router = DefaultRouter()

# Directory endpoints (Public)
router.register(r'governorates', GovernorateViewSet, basename='governorate')
router.register(r'cities', CityViewSet, basename='city')
router.register(r'districts', DistrictViewSet, basename='district')
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'businesses', BusinessViewSet, basename='business')
router.register(r'favorites', FavoriteViewSet, basename='favorite')

# Products endpoints (Public)
router.register(r'products', ProductViewSet, basename='product')

# Deals endpoints (Public)
router.register(r'deals', DealViewSet, basename='deal')
router.register(r'deal-claims', DealClaimViewSet, basename='deal-claim')

# Subscriptions endpoints
router.register(r'subscription-plans', SubscriptionPlanViewSet, basename='subscription-plan')
router.register(r'subscriptions', SubscriptionViewSet, basename='subscription')

urlpatterns = [
    # JWT Authentication
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', register, name='register'),
    path('auth/profile/', get_user_profile, name='profile'),
    path('auth/profile/update/', update_user_profile, name='profile_update'),
    path('auth/change-password/', change_password, name='change_password'),
    
    # API Router (all endpoints)
    path('', include(router.urls)),
    
    # API Documentation (drf-spectacular)
    path('schema/', SpectacularAPIView.as_view(), name='schema'),
    path('docs/', SpectacularSwaggerView.as_view(url_name='api:schema'), name='swagger-ui'),
    path('redoc/', SpectacularRedocView.as_view(url_name='api:schema'), name='redoc'),
]
