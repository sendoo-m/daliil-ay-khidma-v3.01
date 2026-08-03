# apps/api/urls_v2.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_nested import routers
from drf_spectacular.views import (
    SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView,
)

from apps.api.views.admin import (
    AdminDashboardViewSet, AdminUserViewSet, AdminBusinessViewSet,
    AdminCategoryViewSet, AdminProductViewSet, AdminDealViewSet, AdminReviewViewSet
)
from apps.api.views.business_owner import (
    BusinessOwnerDashboardViewSet, BusinessOwnerBusinessViewSet,
    BusinessOwnerProductViewSet, BusinessOwnerDealViewSet, BusinessOwnerReviewViewSet
)
from apps.api.views import directory, deals, products, reviews, subscriptions
from apps.api.views.auth import (
    CustomTokenObtainPairView, MobileTokenRefreshView,
    register, get_user_profile, update_user_profile, change_password,
    logout, request_password_reset, confirm_password_reset,
)
from apps.api.views.home import MobileHomeView
from apps.notifications.views import (
    AdminSendNotificationView,
    DeviceRegistrationViewSet,
    MobileAppConfigView,
    NotificationViewSet,
)

app_name = 'api_v2'

router = DefaultRouter()

# Admin
router.register(r'admin/dashboard',  AdminDashboardViewSet,  basename='admin-dashboard')
router.register(r'admin/users',       AdminUserViewSet,       basename='admin-users')
router.register(r'admin/businesses',  AdminBusinessViewSet,   basename='admin-businesses')
router.register(r'admin/categories',  AdminCategoryViewSet,   basename='admin-categories')
router.register(r'admin/products',    AdminProductViewSet,    basename='admin-products')
router.register(r'admin/deals',       AdminDealViewSet,       basename='admin-deals')
router.register(r'admin/reviews',     AdminReviewViewSet,     basename='admin-reviews')

# Business Owner
router.register(r'business-owner/dashboard',  BusinessOwnerDashboardViewSet, basename='business-owner-dashboard')
router.register(r'business-owner/businesses', BusinessOwnerBusinessViewSet,  basename='business-owner-businesses')

business_router = routers.NestedDefaultRouter(router, r'business-owner/businesses', lookup='business')
business_router.register(r'products', BusinessOwnerProductViewSet, basename='business-owner-products')
business_router.register(r'deals',    BusinessOwnerDealViewSet,    basename='business-owner-deals')
business_router.register(r'reviews',  BusinessOwnerReviewViewSet,  basename='business-owner-reviews')

# Public
router.register(r'governorates',       directory.GovernorateViewSet,       basename='governorates')
router.register(r'cities',             directory.CityViewSet,               basename='cities')
router.register(r'districts',          directory.DistrictViewSet,           basename='districts')
router.register(r'categories',         directory.CategoryViewSet,           basename='categories')
router.register(r'businesses',         directory.BusinessViewSet,           basename='businesses')
router.register(r'favorites',          directory.FavoriteViewSet,           basename='favorites')
router.register(r'products',           products.ProductViewSet,             basename='products')
router.register(r'deals',              deals.DealViewSet,                   basename='deals')
router.register(r'deal-claims',        deals.DealClaimViewSet,              basename='deal-claims')
router.register(r'reviews',            reviews.ReviewViewSet,               basename='reviews')
router.register(r'subscriptions',      subscriptions.SubscriptionViewSet,   basename='subscriptions')
router.register(r'subscription-plans', subscriptions.SubscriptionPlanViewSet, basename='subscription-plans')
router.register(r'devices', DeviceRegistrationViewSet, basename='devices')
router.register(r'notifications', NotificationViewSet, basename='notifications')

urlpatterns = [
    # ── Auth ───────────────────────────────────────────
    path('auth/login/',           CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/',         MobileTokenRefreshView.as_view(),    name='token_refresh'),
    path('auth/register/',        register,                            name='register'),
    path('auth/profile/',         get_user_profile,                    name='profile'),
    path('auth/profile/update/',  update_user_profile,                 name='profile_update'),
    path('auth/change-password/', change_password,                     name='change_password'),
    path('auth/logout/',          logout,                              name='logout'),
    path('auth/password-reset/',  request_password_reset,              name='password_reset'),
    path('auth/password-reset/confirm/', confirm_password_reset,       name='password_reset_confirm'),
    path('home/',                 MobileHomeView.as_view(),             name='home'),
    path('app-config/',           MobileAppConfigView.as_view(),        name='app_config'),
    path('admin/notifications/send/', AdminSendNotificationView.as_view(), name='admin_send_notification'),
    path('schema/', SpectacularAPIView.as_view(urlconf='apps.api.urls_v2'), name='schema'),
    path('docs/', SpectacularSwaggerView.as_view(url_name='api_v2:schema'), name='swagger'),
    path('redoc/', SpectacularRedocView.as_view(url_name='api_v2:schema'), name='redoc'),

    # ── Routers ────────────────────────────────────────
    path('', include(router.urls)),
    path('', include(business_router.urls)),

]
