"""Public deals API views."""

from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction
from django.utils import timezone

from apps.deals.models import Deal, DealClaim
from apps.api.serializers.deals import (
    DealListSerializer, DealDetailSerializer, DealClaimSerializer
)
from apps.api.pagination import StandardResultsSetPagination
from apps.api.filters import DealFilter


class DealViewSet(viewsets.ReadOnlyModelViewSet):
    """Public read-only deals catalogue with authenticated claiming."""
    permission_classes = [AllowAny]
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = DealFilter
    search_fields = ['title_en', 'title_ar', 'description_en', 'description_ar']
    ordering_fields = ['start_date', 'end_date', 'view_count', 'created_at']
    ordering = ['-is_featured', '-created_at']
    lookup_field = 'slug'

    def get_queryset(self):
        now = timezone.now()
        qs = Deal.objects.filter(
            business__is_active=True,
            business__is_verified=True,
        ).select_related('business')

        # ✅ الأدمن والمالك يشوف كل العروض
        if self.request.user.is_authenticated and self.request.user.is_staff:
            return qs

        # المستخدم العادي يشوف العروض النشطة فقط
        return qs.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now
        )

    def get_serializer_class(self):
        if self.action == 'list':
            return DealListSerializer
        return DealDetailSerializer

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def claim(self, request, slug=None):
        """Claim a deal"""
        public_deal = self.get_object()

        with transaction.atomic():
            deal = Deal.objects.select_for_update().get(pk=public_deal.pk)
            if not deal.is_valid:
                return Response(
                    {'error': 'العرض غير متاح حالياً'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user_claims = DealClaim.objects.filter(deal=deal, user=request.user).count()
            if deal.max_uses_per_user and user_claims >= deal.max_uses_per_user:
                return Response(
                    {'error': 'وصلت للحد الأقصى من المطالبات لهذا العرض'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            claim = DealClaim.objects.create(deal=deal, user=request.user)
            deal.current_uses += 1
            deal.save(update_fields=['current_uses'])

        serializer = DealClaimSerializer(claim)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def increment_view(self, request, slug=None):
        deal = self.get_object()
        deal.increment_view_count()
        return Response({'view_count': deal.view_count})

    @action(detail=False, methods=['get'])
    def featured(self, request):
        deals = self.get_queryset().filter(is_featured=True)[:10]
        serializer = self.get_serializer(deals, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def ending_soon(self, request):
        now = timezone.now()
        three_days = now + timezone.timedelta(days=3)
        deals = self.get_queryset().filter(
            end_date__lte=three_days,
            end_date__gte=now
        )[:10]
        serializer = self.get_serializer(deals, many=True)
        return Response(serializer.data)


class DealClaimViewSet(viewsets.ReadOnlyModelViewSet):
    """Deal Claim ViewSet"""
    permission_classes = [IsAuthenticated]
    serializer_class = DealClaimSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['is_used', 'deal']
    ordering = ['-claimed_at']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return DealClaim.objects.none()
        return DealClaim.objects.filter(
            user=self.request.user
        ).select_related('deal', 'deal__business')


# from rest_framework import viewsets, filters, status
# from rest_framework.decorators import action
# from rest_framework.response import Response
# from rest_framework.permissions import IsAuthenticatedOrReadOnly, IsAuthenticated
# from django_filters.rest_framework import DjangoFilterBackend
# from django.utils import timezone

# from apps.deals.models import Deal, DealClaim
# from apps.api.serializers.deals import (
#     DealListSerializer, DealDetailSerializer, DealClaimSerializer
# )
# from apps.api.permissions import IsBusinessOwner


# class DealViewSet(viewsets.ModelViewSet):
#     """Deal ViewSet"""
#     permission_classes = [IsAuthenticatedOrReadOnly, IsBusinessOwner]
#     filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
#     filterset_fields = ['deal_type', 'business', 'is_active', 'is_featured']
#     search_fields = ['title_en', 'title_ar', 'description_en', 'description_ar']
#     ordering_fields = ['start_date', 'end_date', 'view_count', 'created_at']
#     ordering = ['-is_featured', '-created_at']
#     lookup_field = 'slug'
    
#     def get_queryset(self):
#         now = timezone.now()
#         return Deal.objects.filter(
#             is_active=True,
#             start_date__lte=now,
#             end_date__gte=now,
#             business__is_active=True
#         ).select_related('business')
    
#     def get_serializer_class(self):
#         if self.action == 'list':
#             return DealListSerializer
#         return DealDetailSerializer
    
#     @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
#     def claim(self, request, slug=None):
#         """Claim a deal"""
#         deal = self.get_object()
        
#         # Check if valid
#         if not deal.is_valid:
#             return Response(
#                 {'error': 'Deal is not valid'},
#                 status=status.HTTP_400_BAD_REQUEST
#             )
        
#         # Check user claims
#         user_claims = DealClaim.objects.filter(
#             deal=deal,
#             user=request.user
#         ).count()
        
#         if user_claims >= deal.max_uses_per_user:
#             return Response(
#                 {'error': 'Maximum claims reached'},
#                 status=status.HTTP_400_BAD_REQUEST
#             )
        
#         # Create claim
#         claim = DealClaim.objects.create(
#             deal=deal,
#             user=request.user
#         )
        
#         # Increment uses
#         if deal.increment_uses():
#             serializer = DealClaimSerializer(claim)
#             return Response(serializer.data, status=status.HTTP_201_CREATED)
#         else:
#             claim.delete()
#             return Response(
#                 {'error': 'Deal has reached maximum uses'},
#                 status=status.HTTP_400_BAD_REQUEST
#             )
    
#     @action(detail=True, methods=['post'])
#     def increment_view(self, request, slug=None):
#         """Increment view count"""
#         deal = self.get_object()
#         deal.increment_view_count()
#         return Response({'view_count': deal.view_count})
    
#     @action(detail=False, methods=['get'])
#     def featured(self, request):
#         """Get featured deals"""
#         deals = self.get_queryset().filter(is_featured=True)[:10]
#         serializer = self.get_serializer(deals, many=True)
#         return Response(serializer.data)
    
#     @action(detail=False, methods=['get'])
#     def ending_soon(self, request):
#         """Get deals ending soon (within 3 days)"""
#         now = timezone.now()
#         three_days = now + timezone.timedelta(days=3)
#         deals = self.get_queryset().filter(
#             end_date__lte=three_days,
#             end_date__gte=now
#         )[:10]
#         serializer = self.get_serializer(deals, many=True)
#         return Response(serializer.data)


# class DealClaimViewSet(viewsets.ReadOnlyModelViewSet):
#     """Deal Claim ViewSet (Read-only for users)"""
#     permission_classes = [IsAuthenticated]
#     serializer_class = DealClaimSerializer
#     filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
#     filterset_fields = ['is_used', 'deal']
#     ordering = ['-claimed_at']
    
#     def get_queryset(self):
#         return DealClaim.objects.filter(
#             user=self.request.user
#         ).select_related('deal', 'deal__business')
