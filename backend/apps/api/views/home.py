"""Aggregated data used by the Flutter home screen."""

from django.db.models import Count, Q
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema

from apps.deals.models import Deal
from apps.directory.models import Business, Category, Governorate
from apps.products.models import Product
from apps.api.serializers.deals import DealListSerializer
from apps.api.serializers.directory import (
    BusinessListSerializer,
    CategorySerializer,
    GovernorateSerializer,
)
from apps.api.serializers.products import ProductListSerializer


class MobileHomeView(APIView):
    """Return all initial home widgets in one request."""

    permission_classes = [AllowAny]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        now = timezone.now()

        # Return ALL active categories so Flutter's _CategoryStrip in
        # search_page.dart can display and filter by every available category.
        # The previous [:12] cap meant only 12 of 33 categories were visible.
        categories = Category.objects.filter(is_active=True).annotate(
            public_business_count=Count(
                'business',
                filter=Q(business__is_active=True, business__is_verified=True),
            )
        ).order_by('order', 'name_ar')

        businesses = Business.objects.filter(
            is_active=True,
            is_verified=True,
            is_featured=True,
        ).select_related(
            'category', 'district__city__governorate'
        ).prefetch_related('images').order_by('-created_at')[:10]

        products = Product.objects.filter(
            is_available=True,
            is_featured=True,
            business__is_active=True,
            business__is_verified=True,
        ).select_related(
            'business__category', 'business__district__city__governorate'
        ).prefetch_related('images').order_by('-created_at')[:10]

        deals = Deal.objects.filter(
            is_active=True,
            is_featured=True,
            start_date__lte=now,
            end_date__gte=now,
            business__is_active=True,
            business__is_verified=True,
        ).select_related(
            'business__category', 'business__district__city__governorate'
        ).order_by('end_date')[:10]

        governorates = Governorate.objects.filter(is_active=True).order_by('order', 'name_ar')

        return Response({
            'categories': CategorySerializer(categories, many=True, context={'request': request}).data,
            'featured_businesses': BusinessListSerializer(
                businesses, many=True, context={'request': request}
            ).data,
            'featured_products': ProductListSerializer(
                products, many=True, context={'request': request}
            ).data,
            'featured_deals': DealListSerializer(
                deals, many=True, context={'request': request}
            ).data,
            'governorates': GovernorateSerializer(
                governorates, many=True, context={'request': request}
            ).data,
        })
