"""
Products API Views
==================
ViewSets for Products & Services
"""

from rest_framework import viewsets, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django_filters.rest_framework import DjangoFilterBackend

from apps.products.models import Product
from apps.api.serializers.products import (
    ProductListSerializer, ProductDetailSerializer,
)
from apps.api.filters import ProductFilter


class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    """Public read-only products and services catalogue."""
    permission_classes = [AllowAny]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = ProductFilter
    search_fields = ['name_en', 'name_ar', 'description_en', 'description_ar']
    ordering_fields = ['price', 'view_count', 'created_at']
    ordering = ['-is_featured', '-created_at']
    lookup_field = 'slug'
    
    def get_queryset(self):
        return Product.objects.filter(
            is_available=True,
            business__is_active=True
        ).select_related('business').prefetch_related('images')
    
    def get_serializer_class(self):
        if self.action == 'list':
            return ProductListSerializer
        return ProductDetailSerializer
    
    @action(detail=True, methods=['post'])
    def increment_view(self, request, slug=None):
        """Increment view count"""
        product = self.get_object()
        product.increment_view_count()
        return Response({'view_count': product.view_count})
    
    @action(detail=False, methods=['get'])
    def featured(self, request):
        """Get featured products"""
        products = self.get_queryset().filter(is_featured=True)[:10]
        serializer = self.get_serializer(products, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def on_sale(self, request):
        """Get products on sale (with discount)"""
        products = self.get_queryset().exclude(old_price__isnull=True).filter(
            old_price__gt=0
        )[:20]
        serializer = self.get_serializer(products, many=True)
        return Response(serializer.data)
