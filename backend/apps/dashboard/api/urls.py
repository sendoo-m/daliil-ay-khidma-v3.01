# apps/dashboard/api/urls.py

from django.urls import path
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .views.admin_api import (
    AdminStatsAPIView,
    AdminChartDataAPIView,
    AdminUsersAPIView,
    AdminUserToggleAPIView,
    AdminBusinessesAPIView,
    AdminBusinessVerifyAPIView,
    AdminBusinessFeatureAPIView,
    AdminBusinessToggleAPIView,
    AdminReviewsAPIView,
    AdminReviewApproveAPIView,
    AdminReviewRejectAPIView,
)
from .views.owner_api import (
    OwnerStatsAPIView,
    OwnerBusinessesAPIView,
    OwnerProductsAPIView,
    OwnerProductToggleAPIView,
    OwnerDealsAPIView,
    OwnerDealToggleAPIView,
    OwnerReviewsAPIView,
)


@api_view(['GET'])
def api_root(request):
    base = request.build_absolute_uri('/api/dashboard/')
    return Response({
        'admin': {
            'stats':      base + 'admin/stats/',
            'chart_data': base + 'admin/chart-data/',
            'users':      base + 'admin/users/',
            'businesses': base + 'admin/businesses/',
            'reviews':    base + 'admin/reviews/',
        },
        'owner': {
            'stats':      base + 'owner/stats/',
            'businesses': base + 'owner/businesses/',
            'products':   base + 'owner/products/',
            'deals':      base + 'owner/deals/',
            'reviews':    base + 'owner/reviews/',
        }
    })


# ✅ urlpatterns واحدة بس
urlpatterns = [
    path('', api_root),

    # ── Admin ──────────────────────────────────────────────
    path('admin/stats/',                        AdminStatsAPIView.as_view()),
    path('admin/chart-data/',                   AdminChartDataAPIView.as_view()),

    path('admin/users/',                        AdminUsersAPIView.as_view()),
    path('admin/users/<int:user_id>/toggle/',   AdminUserToggleAPIView.as_view()),

    path('admin/businesses/',                           AdminBusinessesAPIView.as_view()),
    path('admin/businesses/<int:business_id>/verify/',  AdminBusinessVerifyAPIView.as_view()),
    path('admin/businesses/<int:business_id>/feature/', AdminBusinessFeatureAPIView.as_view()),
    path('admin/businesses/<int:business_id>/toggle/',  AdminBusinessToggleAPIView.as_view()),

    path('admin/reviews/',                         AdminReviewsAPIView.as_view()),
    path('admin/reviews/<int:review_id>/approve/', AdminReviewApproveAPIView.as_view()),
    path('admin/reviews/<int:review_id>/reject/',  AdminReviewRejectAPIView.as_view()),

    # ── Owner ──────────────────────────────────────────────
    path('owner/stats/',                            OwnerStatsAPIView.as_view()),
    path('owner/businesses/',                       OwnerBusinessesAPIView.as_view()),

    path('owner/products/',                         OwnerProductsAPIView.as_view()),
    path('owner/products/<int:product_id>/toggle/', OwnerProductToggleAPIView.as_view()),

    path('owner/deals/',                            OwnerDealsAPIView.as_view()),
    path('owner/deals/<int:deal_id>/toggle/',       OwnerDealToggleAPIView.as_view()),

    path('owner/reviews/',                          OwnerReviewsAPIView.as_view()),
]
