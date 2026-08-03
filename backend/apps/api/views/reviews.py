"""Reviews API Views"""
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Count, Q

from apps.reviews.models import Review, ReviewLike, ReviewReport
from apps.api.serializers.reviews import ReviewSerializer, ReviewCreateSerializer
from apps.api.pagination import StandardResultsSetPagination
from apps.api.permissions import IsOwnerOrReadOnly


class ReviewViewSet(viewsets.ModelViewSet):
    """Review ViewSet for public API"""
    queryset = Review.objects.filter(
        is_approved=True,
        business__is_active=True,
        business__is_verified=True,
    ).select_related('user', 'business').annotate(likes_count=Count('likes')).order_by('-created_at')
    pagination_class = StandardResultsSetPagination
    filterset_fields = ['business', 'rating', 'is_approved']
    search_fields = ['comment', 'user__username', 'business__name_ar', 'business__name_en']
    ordering_fields = ['created_at', 'rating']
    
    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return ReviewCreateSerializer
        return ReviewSerializer
    
    def get_permissions(self):
        if self.action in ['create']:
            return [permissions.IsAuthenticated()]
        elif self.action in ['update', 'partial_update', 'destroy']:
            return [IsOwnerOrReadOnly()]
        return [permissions.AllowAny()]
    
    def get_queryset(self):
        visibility = Q(
            is_approved=True,
            business__is_active=True,
            business__is_verified=True,
        )
        if self.request.user.is_authenticated:
            visibility |= Q(user=self.request.user)
        return Review.objects.filter(visibility).select_related(
            'user', 'business'
        ).annotate(likes_count=Count('likes')).distinct().order_by('-created_at')
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user, is_approved=False)
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def like(self, request, pk=None):
        """Toggle a like without allowing users to like their own review."""
        review = self.get_object()
        if review.user_id == request.user.id:
            return Response(
                {'error': 'لا يمكنك الإعجاب بتقييمك'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        like, created = ReviewLike.objects.get_or_create(review=review, user=request.user)
        if not created:
            like.delete()
        return Response({
            'is_liked': created,
            'likes_count': review.likes.count(),
        })
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def report(self, request, pk=None):
        """Create one report per user and review."""
        review = self.get_object()
        reason = request.data.get('reason', '').strip()
        if not reason:
            return Response(
                {'error': 'سبب البلاغ مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(reason) > 500:
            return Response(
                {'error': 'سبب البلاغ يجب ألا يتجاوز 500 حرف'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        report, created = ReviewReport.objects.get_or_create(
            review=review,
            user=request.user,
            defaults={'reason': reason},
        )
        return Response(
            {'status': 'reported' if created else 'already_reported'},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
