# apps/dashboard/api/views/owner_api.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Avg, Sum, Count
from django.utils import timezone

from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review

from ..permissions import IsBusinessOwner, IsOwnerOfBusiness
from ..serializers.owner_serializers import (
    OwnerStatsSerializer,
    OwnerBusinessSerializer,
    OwnerProductSerializer,
    OwnerDealSerializer,
    OwnerReviewSerializer,
)


# ══════════════════════════════════════════
# STATS
# ══════════════════════════════════════════
class OwnerStatsAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def get(self, request):
        businesses = Business.objects.filter(owner=request.user)
        products   = Product.objects.filter(business__owner=request.user)
        deals      = Deal.objects.filter(business__owner=request.user)
        reviews    = Review.objects.filter(business__owner=request.user)
        today      = timezone.now()

        data = {
            'total_businesses':  businesses.count(),
            'active_businesses': businesses.filter(is_active=True).count(),
            'verified_count':    businesses.filter(is_verified=True).count(),

            'total_products':    products.count(),
            'active_products':   products.filter(is_available=True).count(),

            'total_deals':       deals.count(),
            'active_deals':      deals.filter(
                start_date__lte=today, end_date__gte=today, is_active=True
            ).count(),

            'total_reviews':     reviews.count(),
            'average_rating':    round(
                reviews.filter(is_approved=True).aggregate(
                    Avg('rating'))['rating__avg'] or 0, 2
            ),

            'total_views':       businesses.aggregate(
                Sum('view_count'))['view_count__sum'] or 0,
            'total_clicks':      businesses.aggregate(
                Sum('click_count'))['click_count__sum'] or 0,
        }

        serializer = OwnerStatsSerializer(data)
        return Response(serializer.data)


# ══════════════════════════════════════════
# BUSINESSES
# ══════════════════════════════════════════
class OwnerBusinessesAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def get(self, request):
        businesses = Business.objects.filter(
            owner=request.user
        ).select_related('category').order_by('-created_at')

        serializer = OwnerBusinessSerializer(businesses, many=True)
        return Response({
            'count':   businesses.count(),
            'results': serializer.data,
        })


# ══════════════════════════════════════════
# PRODUCTS
# ══════════════════════════════════════════
class OwnerProductsAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def get(self, request):
        products = Product.objects.filter(
            business__owner=request.user
        ).select_related('business').order_by('-created_at')

        business_id = request.query_params.get('business_id')
        if business_id:
            products = products.filter(business_id=business_id)

        serializer = OwnerProductSerializer(products, many=True)
        return Response({
            'count':   products.count(),
            'results': serializer.data,
        })


class OwnerProductToggleAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def post(self, request, product_id):
        try:
            product = Product.objects.get(
                id=product_id, business__owner=request.user
            )
        except Product.DoesNotExist:
            return Response(
                {'error': 'المنتج غير موجود أو لا ينتمي إليك'},
                status=status.HTTP_404_NOT_FOUND
            )

        product.is_available = not product.is_available
        product.save()

        return Response({
            'success':      True,
            'is_available': product.is_available,
            'message':      f"تم {'تفعيل' if product.is_available else 'تعطيل'} المنتج"
        })


# ══════════════════════════════════════════
# DEALS
# ══════════════════════════════════════════
class OwnerDealsAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def get(self, request):
        deals = Deal.objects.filter(
            business__owner=request.user
        ).select_related('business').order_by('-created_at')

        business_id = request.query_params.get('business_id')
        if business_id:
            deals = deals.filter(business_id=business_id)

        serializer = OwnerDealSerializer(deals, many=True)
        return Response({
            'count':   deals.count(),
            'results': serializer.data,
        })


class OwnerDealToggleAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def post(self, request, deal_id):
        try:
            deal = Deal.objects.get(
                id=deal_id, business__owner=request.user
            )
        except Deal.DoesNotExist:
            return Response(
                {'error': 'العرض غير موجود أو لا ينتمي إليك'},
                status=status.HTTP_404_NOT_FOUND
            )

        deal.is_active = not deal.is_active
        deal.save()

        return Response({
            'success':   True,
            'is_active': deal.is_active,
            'message':   f"تم {'تفعيل' if deal.is_active else 'تعطيل'} العرض"
        })


# ══════════════════════════════════════════
# REVIEWS
# ══════════════════════════════════════════
class OwnerReviewsAPIView(APIView):
    permission_classes = [IsBusinessOwner]

    def get(self, request):
        reviews = Review.objects.filter(
            business__owner=request.user
        ).select_related('business', 'user').order_by('-created_at')

        business_id = request.query_params.get('business_id')
        if business_id:
            reviews = reviews.filter(business_id=business_id)

        serializer = OwnerReviewSerializer(reviews, many=True)
        return Response({
            'count':   reviews.count(),
            'results': serializer.data,
        })
