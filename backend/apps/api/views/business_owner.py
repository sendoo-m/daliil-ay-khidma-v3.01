"""Business Owner API Views"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Sum, Avg
from django.shortcuts import get_object_or_404   # ✅ مضاف
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema

from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review

from apps.api.serializers.business_owner import (
    BusinessOwnerStatsSerializer,
    BusinessOwnerBusinessSerializer,
    BusinessOwnerProductSerializer,
    BusinessOwnerDealSerializer,
    BusinessOwnerReviewSerializer,
    BusinessOwnerImageSerializer,
    BusinessOwnerProductImageSerializer,
)
from apps.api.pagination import StandardResultsSetPagination
from apps.api.permissions import IsBusinessOwner


class BusinessOwnerDashboardViewSet(viewsets.ViewSet):
    """Business owner dashboard"""
    permission_classes = [IsBusinessOwner]
    serializer_class = BusinessOwnerStatsSerializer

    @action(detail=False, methods=['get'])
    def stats(self, request):
        user = request.user
        businesses = Business.objects.filter(owner=user)

        stats = {
            'total_businesses':   businesses.count(),
            'verified_businesses': businesses.filter(is_verified=True).count(),
            'total_products':     Product.objects.filter(business__owner=user).count(),
            'total_deals':        Deal.objects.filter(business__owner=user).count(),
            'active_deals':       Deal.objects.filter(
                business__owner=user,
                is_active=True,
                start_date__lte=timezone.now(),
                end_date__gte=timezone.now()
            ).count(),
            'total_reviews':      Review.objects.filter(business__owner=user, is_approved=True).count(),
            'average_rating':     Review.objects.filter(
                business__owner=user,
                is_approved=True
            ).aggregate(Avg('rating'))['rating__avg'] or 0,
            'total_views':        businesses.aggregate(Sum('view_count'))['view_count__sum'] or 0,
            'total_clicks':       businesses.aggregate(Sum('click_count'))['click_count__sum'] or 0,
        }

        serializer = BusinessOwnerStatsSerializer(stats)
        return Response(serializer.data)


class BusinessOwnerBusinessViewSet(viewsets.ModelViewSet):
    """Business owner business management"""
    serializer_class = BusinessOwnerBusinessSerializer
    permission_classes = [IsBusinessOwner]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Business.objects.none()
        return Business.objects.filter(
            owner=self.request.user
        ).select_related('category')

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=['get', 'post'], url_path='images')
    def images(self, request, pk=None):
        business = self.get_object()
        if request.method == 'GET':
            serializer = BusinessOwnerImageSerializer(business.images.all(), many=True)
            return Response(serializer.data)

        if business.images.count() >= 10:
            return Response(
                {'error': 'الحد الأقصى لمعرض النشاط هو 10 صور'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = BusinessOwnerImageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(business=business)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @extend_schema(parameters=[OpenApiParameter('image_id', int, OpenApiParameter.PATH)])
    @action(detail=True, methods=['delete'], url_path=r'images/(?P<image_id>[^/.]+)')
    def delete_image(self, request, image_id=None, pk=None):
        business = self.get_object()
        image = get_object_or_404(business.images, pk=image_id)
        image.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BusinessOwnerProductViewSet(viewsets.ModelViewSet):
    """Business owner product management"""
    serializer_class = BusinessOwnerProductSerializer
    permission_classes = [IsBusinessOwner]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Product.objects.none()
        business_id = self.kwargs.get('business_pk')
        return Product.objects.filter(
            business_id=business_id,
            business__owner=self.request.user
        ).select_related('business')

    def perform_create(self, serializer):
        business_id = self.kwargs.get('business_pk')
        # ✅ get_object_or_404 بدل .get() العادي
        business = get_object_or_404(Business, id=business_id, owner=self.request.user)
        serializer.save(business=business)

    @action(detail=True, methods=['get', 'post'], url_path='images')
    def images(self, request, business_pk=None, pk=None):
        product = self.get_object()
        if request.method == 'GET':
            serializer = BusinessOwnerProductImageSerializer(product.images.all(), many=True)
            return Response(serializer.data)

        if product.images.count() >= 10:
            return Response(
                {'error': 'الحد الأقصى للمنتج هو 10 صور'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = BusinessOwnerProductImageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(product=product)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @extend_schema(parameters=[OpenApiParameter('image_id', int, OpenApiParameter.PATH)])
    @action(detail=True, methods=['delete'], url_path=r'images/(?P<image_id>[^/.]+)')
    def delete_image(self, request, image_id=None, business_pk=None, pk=None):
        product = self.get_object()
        image = get_object_or_404(product.images, pk=image_id)
        image.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BusinessOwnerDealViewSet(viewsets.ModelViewSet):
    """Business owner deal management"""
    serializer_class = BusinessOwnerDealSerializer
    permission_classes = [IsBusinessOwner]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Deal.objects.none()
        business_id = self.kwargs.get('business_pk')
        return Deal.objects.filter(
            business_id=business_id,
            business__owner=self.request.user
        ).select_related('business')

    def perform_create(self, serializer):
        business_id = self.kwargs.get('business_pk')
        # ✅ get_object_or_404 بدل .get() العادي
        business = get_object_or_404(Business, id=business_id, owner=self.request.user)
        serializer.save(business=business)


class BusinessOwnerReviewViewSet(viewsets.ReadOnlyModelViewSet):
    """Business owner review viewing (read-only)"""
    serializer_class = BusinessOwnerReviewSerializer
    permission_classes = [IsBusinessOwner]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Review.objects.none()
        business_id = self.kwargs.get('business_pk')
        return Review.objects.filter(
            business_id=business_id,
            business__owner=self.request.user
        ).select_related('user', 'business').order_by('-created_at')


# """Business Owner API Views"""
# from rest_framework import viewsets, permissions, status
# from rest_framework.decorators import action
# from rest_framework.response import Response
# from django.db.models import Count, Sum, Avg
# from django.utils import timezone

# # Import models from their respective apps
# from apps.directory.models import Business
# from apps.products.models import Product
# from apps.deals.models import Deal
# from apps.reviews.models import Review

# from apps.api.serializers.business_owner import (
#     BusinessOwnerStatsSerializer,
#     BusinessOwnerBusinessSerializer,
#     BusinessOwnerProductSerializer,
#     BusinessOwnerDealSerializer,
#     BusinessOwnerReviewSerializer
# )
# from apps.api.permissions import IsBusinessOwner
# from apps.api.pagination import StandardResultsSetPagination


# class BusinessOwnerDashboardViewSet(viewsets.ViewSet):
#     """Business owner dashboard"""
#     permission_classes = [permissions.IsAuthenticated]
    
#     @action(detail=False, methods=['get'])
#     def stats(self, request):
#         """Get business owner stats"""
#         user = request.user
#         businesses = Business.objects.filter(owner=user)
        
#         stats = {
#             'total_businesses': businesses.count(),
#             'verified_businesses': businesses.filter(is_verified=True).count(),
#             'total_products': Product.objects.filter(business__owner=user).count(),
#             'total_deals': Deal.objects.filter(business__owner=user).count(),
#             'active_deals': Deal.objects.filter(
#                 business__owner=user,
#                 is_active=True,
#                 start_date__lte=timezone.now(),
#                 end_date__gte=timezone.now()
#             ).count(),
#             'total_reviews': Review.objects.filter(business__owner=user, is_approved=True).count(),
#             'average_rating': Review.objects.filter(
#                 business__owner=user, 
#                 is_approved=True
#             ).aggregate(Avg('rating'))['rating__avg'] or 0,
#             'total_views': businesses.aggregate(Sum('views_count'))['views_count__sum'] or 0,
#             'total_clicks': businesses.aggregate(Sum('clicks_count'))['clicks_count__sum'] or 0,
#         }
        
#         serializer = BusinessOwnerStatsSerializer(stats)
#         return Response(serializer.data)


# class BusinessOwnerBusinessViewSet(viewsets.ModelViewSet):
#     """Business owner business management"""
#     serializer_class = BusinessOwnerBusinessSerializer
#     permission_classes = [permissions.IsAuthenticated]
#     pagination_class = StandardResultsSetPagination
    
#     def get_queryset(self):
#         return Business.objects.filter(owner=self.request.user).select_related('category')
    
#     def perform_create(self, serializer):
#         serializer.save(owner=self.request.user)


# class BusinessOwnerProductViewSet(viewsets.ModelViewSet):
#     """Business owner product management"""
#     serializer_class = BusinessOwnerProductSerializer
#     permission_classes = [permissions.IsAuthenticated]
#     pagination_class = StandardResultsSetPagination
    
#     def get_queryset(self):
#         business_id = self.kwargs.get('business_pk')
#         return Product.objects.filter(
#             business_id=business_id,
#             business__owner=self.request.user
#         ).select_related('business')
    
#     def perform_create(self, serializer):
#         business_id = self.kwargs.get('business_pk')
#         business = Business.objects.get(id=business_id, owner=self.request.user)
#         serializer.save(business=business)


# class BusinessOwnerDealViewSet(viewsets.ModelViewSet):
#     """Business owner deal management"""
#     serializer_class = BusinessOwnerDealSerializer
#     permission_classes = [permissions.IsAuthenticated]
#     pagination_class = StandardResultsSetPagination
    
#     def get_queryset(self):
#         business_id = self.kwargs.get('business_pk')
#         return Deal.objects.filter(
#             business_id=business_id,
#             business__owner=self.request.user
#         ).select_related('business')
    
#     def perform_create(self, serializer):
#         business_id = self.kwargs.get('business_pk')
#         business = Business.objects.get(id=business_id, owner=self.request.user)
#         serializer.save(business=business)


# class BusinessOwnerReviewViewSet(viewsets.ReadOnlyModelViewSet):
#     """Business owner review viewing"""
#     serializer_class = BusinessOwnerReviewSerializer
#     permission_classes = [permissions.IsAuthenticated]
#     pagination_class = StandardResultsSetPagination
    
#     def get_queryset(self):
#         business_id = self.kwargs.get('business_pk')
#         return Review.objects.filter(
#             business_id=business_id,
#             business__owner=self.request.user
#         ).select_related('user', 'business').order_by('-created_at')
