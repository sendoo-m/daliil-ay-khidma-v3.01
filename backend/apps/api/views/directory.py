"""
Directory API Views
===================
ViewSets for Location & Business
"""

from math import asin, cos, radians, sin, sqrt

from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.shortcuts import get_object_or_404

from apps.directory.models import (
    Governorate, City, District, Category,
    Business, BusinessImage, Favorite
)
from apps.api.serializers.directory import (
    GovernorateSerializer, CitySerializer, DistrictSerializer,
    CategorySerializer, BusinessListSerializer, BusinessDetailSerializer,
    BusinessImageSerializer, FavoriteSerializer
)
from apps.api.pagination import StandardResultsSetPagination
from apps.api.filters import BusinessFilter


class GovernorateViewSet(viewsets.ReadOnlyModelViewSet):
    """Governorate ViewSet"""
    queryset = Governorate.objects.filter(is_active=True)
    serializer_class = GovernorateSerializer
    lookup_field = 'slug'
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name_en', 'name_ar']
    ordering_fields = ['order', 'name_en']
    ordering = ['order', 'name_en']


class CityViewSet(viewsets.ReadOnlyModelViewSet):
    """City ViewSet"""
    queryset = City.objects.filter(is_active=True).select_related('governorate')
    serializer_class = CitySerializer
    lookup_field = 'slug'
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['governorate']
    search_fields = ['name_en', 'name_ar']
    ordering_fields = ['order', 'name_en']
    ordering = ['governorate__order', 'order', 'name_en']


class DistrictViewSet(viewsets.ReadOnlyModelViewSet):
    """District ViewSet"""
    queryset = District.objects.filter(is_active=True).select_related('city__governorate')
    serializer_class = DistrictSerializer
    lookup_field = 'slug'
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['city', 'city__governorate']
    search_fields = ['name_en', 'name_ar']
    ordering_fields = ['order', 'name_en']
    ordering = ['city__order', 'order', 'name_en']


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """Category ViewSet"""
    queryset = Category.objects.filter(is_active=True)
    serializer_class = CategorySerializer
    lookup_field = 'slug'
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name_en', 'name_ar']
    ordering_fields = ['order', 'name_en']
    ordering = ['order', 'name_en']


class BusinessViewSet(viewsets.ReadOnlyModelViewSet):
    """Public read-only business directory."""
    permission_classes = [AllowAny]
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = BusinessFilter
    search_fields = [
        'name_en', 'name_ar', 'description_en', 'description_ar',
        'address_en', 'address_ar', 'phone',
    ]
    ordering_fields = ['view_count', 'average_rating', 'created_at', 'name_en']
    ordering = ['-is_featured', '-created_at']
    lookup_field = 'slug'

    def get_queryset(self):
        queryset = Business.objects.filter(
            is_active=True
        ).select_related(
            'category', 'district__city__governorate'
        ).prefetch_related('images')

        return queryset.filter(is_verified=True)

    def get_serializer_class(self):
        if self.action == 'list':
            return BusinessListSerializer
        return BusinessDetailSerializer

    @action(detail=True, methods=['post'])
    def increment_view(self, request, slug=None):
        business = self.get_object()
        business.increment_view_count()
        return Response({'view_count': business.view_count})

    @action(detail=True, methods=['post'])
    def increment_click(self, request, slug=None):
        business = self.get_object()
        business.increment_click_count()
        return Response({'click_count': business.click_count})

    @action(detail=False, methods=['get'])
    def featured(self, request):
        businesses = self.get_queryset().filter(is_featured=True)[:10]
        serializer = self.get_serializer(businesses, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def shops(self, request):
        businesses = self.get_queryset().filter(business_type='shop')
        page = self.paginate_queryset(businesses)
        if page is not None:
            return self.get_paginated_response(self.get_serializer(page, many=True).data)
        return Response(self.get_serializer(businesses, many=True).data)

    @action(detail=False, methods=['get'])
    def crafts(self, request):
        businesses = self.get_queryset().filter(business_type='craft')
        page = self.paginate_queryset(businesses)
        if page is not None:
            return self.get_paginated_response(self.get_serializer(page, many=True).data)
        return Response(self.get_serializer(businesses, many=True).data)

    @action(detail=False, methods=['get'])
    def public_services(self, request):
        businesses = self.get_queryset().filter(business_type='public')
        page = self.paginate_queryset(businesses)
        if page is not None:
            return self.get_paginated_response(self.get_serializer(page, many=True).data)
        return Response(self.get_serializer(businesses, many=True).data)

    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Return the nearest verified businesses within a radius."""
        try:
            latitude = float(request.query_params['latitude'])
            longitude = float(request.query_params['longitude'])
            radius_km = float(request.query_params.get('radius_km', 10))
        except (KeyError, TypeError, ValueError):
            raise ValidationError({
                'coordinates': 'latitude وlongitude مطلوبان ويجب أن يكونا أرقامًا'
            })

        if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
            raise ValidationError({'coordinates': 'الإحداثيات خارج النطاق الصحيح'})
        if not 0 < radius_km <= 100:
            raise ValidationError({'radius_km': 'نطاق البحث يجب أن يكون بين 0 و100 كم'})

        latitude_delta = radius_km / 111.0
        longitude_scale = max(cos(radians(latitude)), 0.01)
        longitude_delta = radius_km / (111.0 * longitude_scale)
        candidates = self.filter_queryset(self.get_queryset()).filter(
            latitude__isnull=False,
            longitude__isnull=False,
            latitude__range=(latitude - latitude_delta, latitude + latitude_delta),
            longitude__range=(longitude - longitude_delta, longitude + longitude_delta),
        )[:200]

        nearby_businesses = []
        for business in candidates:
            lat_delta = radians(float(business.latitude) - latitude)
            lng_delta = radians(float(business.longitude) - longitude)
            value = sin(lat_delta / 2) ** 2 + cos(radians(latitude)) * cos(
                radians(float(business.latitude))
            ) * sin(lng_delta / 2) ** 2
            distance = 6371.0 * 2 * asin(sqrt(value))
            if distance <= radius_km:
                business.distance_km = distance
                nearby_businesses.append(business)

        nearby_businesses.sort(key=lambda business: business.distance_km)
        serializer = BusinessListSerializer(
            nearby_businesses[:20], many=True, context={'request': request}
        )
        return Response(serializer.data)

class FavoriteViewSet(viewsets.ModelViewSet):
    """Favorite ViewSet"""
    permission_classes = [IsAuthenticated]
    serializer_class = FavoriteSerializer
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Favorite.objects.none()
        return Favorite.objects.filter(
            user=self.request.user,
            business__is_active=True,
            business__is_verified=True,
        ).select_related('business')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['post'])
    def toggle(self, request):
        business_id = request.data.get('business_id')
        if not business_id:
            return Response(
                {'error': 'business_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        business = get_object_or_404(
            Business,
            pk=business_id,
            is_active=True,
            is_verified=True,
        )
        favorite = Favorite.objects.filter(
            user=request.user,
            business=business,
        ).first()

        if favorite:
            favorite.delete()
            return Response({'status': 'removed', 'is_favorite': False})

        Favorite.objects.create(user=request.user, business=business)
        return Response({'status': 'added', 'is_favorite': True})


# from rest_framework import viewsets, filters, status
# from rest_framework.decorators import action
# from rest_framework.response import Response
# from rest_framework.permissions import IsAuthenticatedOrReadOnly, IsAuthenticated
# from django_filters.rest_framework import DjangoFilterBackend

# from apps.directory.models import (
#     Governorate, City, District, Category,
#     Business, BusinessImage, Favorite
# )
# from apps.api.serializers.directory import (
#     GovernorateSerializer, CitySerializer, DistrictSerializer,
#     CategorySerializer, BusinessListSerializer, BusinessDetailSerializer,
#     BusinessImageSerializer, FavoriteSerializer
# )
# from apps.api.permissions import IsOwnerOrReadOnly


# class GovernorateViewSet(viewsets.ReadOnlyModelViewSet):
#     """Governorate ViewSet (Read-only)"""
#     queryset = Governorate.objects.filter(is_active=True)
#     serializer_class = GovernorateSerializer
#     lookup_field = 'slug'
#     filter_backends = [filters.SearchFilter, filters.OrderingFilter]
#     search_fields = ['name_en', 'name_ar']
#     ordering_fields = ['order', 'name_en']
#     ordering = ['order', 'name_en']


# class CityViewSet(viewsets.ReadOnlyModelViewSet):
#     """City ViewSet (Read-only)"""
#     queryset = City.objects.filter(is_active=True).select_related('governorate')
#     serializer_class = CitySerializer
#     lookup_field = 'slug'
#     filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
#     filterset_fields = ['governorate']
#     search_fields = ['name_en', 'name_ar']
#     ordering_fields = ['order', 'name_en']
#     ordering = ['governorate__order', 'order', 'name_en']


# class DistrictViewSet(viewsets.ReadOnlyModelViewSet):
#     """District ViewSet (Read-only)"""
#     queryset = District.objects.filter(is_active=True).select_related('city__governorate')
#     serializer_class = DistrictSerializer
#     lookup_field = 'slug'
#     filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
#     filterset_fields = ['city', 'city__governorate']
#     search_fields = ['name_en', 'name_ar']
#     ordering_fields = ['order', 'name_en']
#     ordering = ['city__order', 'order', 'name_en']


# class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
#     """Category ViewSet (Read-only)"""
#     queryset = Category.objects.filter(is_active=True)
#     serializer_class = CategorySerializer
#     lookup_field = 'slug'
#     filter_backends = [filters.SearchFilter, filters.OrderingFilter]
#     search_fields = ['name_en', 'name_ar']
#     ordering_fields = ['order', 'name_en']
#     ordering = ['order', 'name_en']


# class BusinessViewSet(viewsets.ModelViewSet):
#     """Business ViewSet"""
#     permission_classes = [IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
#     filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
#     filterset_fields = ['business_type', 'category', 'district', 'is_verified', 'is_featured']  # Added business_type
#     search_fields = ['name_en', 'name_ar', 'description_en', 'description_ar']
#     ordering_fields = ['view_count', 'created_at', 'name_en']
#     ordering = ['-is_featured', '-created_at']
#     lookup_field = 'slug'
    
#     def get_queryset(self):
#         queryset = Business.objects.filter(
#             is_active=True
#         ).select_related(
#             'category', 'district__city__governorate'
#         ).prefetch_related('images')
        
#         # Show all for authenticated users, only verified for others
#         if not self.request.user.is_authenticated:
#             queryset = queryset.filter(is_verified=True)
        
#         return queryset
    
#     def get_serializer_class(self):
#         if self.action == 'list':
#             return BusinessListSerializer
#         return BusinessDetailSerializer
    
#     def perform_create(self, serializer):
#         serializer.save(owner=self.request.user)
    
#     @action(detail=True, methods=['post'])
#     def increment_view(self, request, slug=None):
#         """زيادة عداد المشاهدات"""
#         business = self.get_object()
#         business.increment_view_count()
#         return Response({'view_count': business.view_count})
    
#     @action(detail=True, methods=['post'])
#     def increment_click(self, request, slug=None):
#         """زيادة عداد النقرات"""
#         business = self.get_object()
#         business.increment_click_count()
#         return Response({'click_count': business.click_count})
    
#     @action(detail=False, methods=['get'])
#     def featured(self, request):
#         """الحصول على المحلات المميزة"""
#         businesses = self.get_queryset().filter(is_featured=True)[:10]
#         serializer = self.get_serializer(businesses, many=True)
#         return Response(serializer.data)
    
#     @action(detail=False, methods=['get'])
#     def shops(self, request):
#         """الحصول على المحلات التجارية فقط"""
#         businesses = self.get_queryset().filter(business_type='shop')
        
#         # Apply pagination
#         page = self.paginate_queryset(businesses)
#         if page is not None:
#             serializer = self.get_serializer(page, many=True)
#             return self.get_paginated_response(serializer.data)
        
#         serializer = self.get_serializer(businesses, many=True)
#         return Response(serializer.data)
    
#     @action(detail=False, methods=['get'])
#     def crafts(self, request):
#         """الحصول على الحرف والخدمات الحرفية"""
#         businesses = self.get_queryset().filter(business_type='craft')
        
#         # Apply pagination
#         page = self.paginate_queryset(businesses)
#         if page is not None:
#             serializer = self.get_serializer(page, many=True)
#             return self.get_paginated_response(serializer.data)
        
#         serializer = self.get_serializer(businesses, many=True)
#         return Response(serializer.data)
    
#     @action(detail=False, methods=['get'])
#     def public_services(self, request):
#         """الحصول على الخدمات العامة"""
#         businesses = self.get_queryset().filter(business_type='public')
        
#         # Apply pagination
#         page = self.paginate_queryset(businesses)
#         if page is not None:
#             serializer = self.get_serializer(page, many=True)
#             return self.get_paginated_response(serializer.data)
        
#         serializer = self.get_serializer(businesses, many=True)
#         return Response(serializer.data)
    
#     @action(detail=False, methods=['get'])
#     def my_businesses(self, request):
#         """الحصول على محلات المستخدم الحالي"""
#         if not request.user.is_authenticated:
#             return Response({'detail': 'Authentication required'}, status=401)
        
#         businesses = Business.objects.filter(owner=request.user)
#         serializer = self.get_serializer(businesses, many=True)
#         return Response(serializer.data)


# class FavoriteViewSet(viewsets.ModelViewSet):
#     """Favorite ViewSet"""
#     permission_classes = [IsAuthenticated]
#     serializer_class = FavoriteSerializer
    
#     def get_queryset(self):
#         return Favorite.objects.filter(
#             user=self.request.user
#         ).select_related('business')
    
#     def perform_create(self, serializer):
#         serializer.save(user=self.request.user)
    
#     @action(detail=False, methods=['post'])
#     def toggle(self, request):
#         """تبديل حالة المفضلة"""
#         business_id = request.data.get('business_id')
        
#         if not business_id:
#             return Response(
#                 {'error': 'business_id is required'},
#                 status=status.HTTP_400_BAD_REQUEST
#             )
        
#         favorite = Favorite.objects.filter(
#             user=request.user,
#             business_id=business_id
#         ).first()
        
#         if favorite:
#             favorite.delete()
#             return Response({'status': 'removed', 'is_favorite': False})
#         else:
#             Favorite.objects.create(
#                 user=request.user,
#                 business_id=business_id
#             )
#             return Response({'status': 'added', 'is_favorite': True})
