"""
Subscriptions API Views
=======================
ViewSets for Subscription Plans
"""

from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from apps.subscriptions.models import SubscriptionPlan, Subscription
from apps.api.serializers.subscriptions import (
    SubscriptionPlanSerializer, SubscriptionSerializer
)


class SubscriptionPlanViewSet(viewsets.ReadOnlyModelViewSet):
    """Subscription Plan ViewSet (Read-only)"""
    queryset = SubscriptionPlan.objects.filter(is_active=True)
    serializer_class = SubscriptionPlanSerializer
    filter_backends = [filters.OrderingFilter]
    ordering = ['order', 'price_monthly']
    
    @action(detail=True, methods=['get'])
    def pricing(self, request, pk=None):
        """Get pricing for all durations"""
        plan = self.get_object()
        return Response({
            'monthly': float(plan.price_monthly),
            'quarterly': float(plan.price_quarterly),
            'semi_annual': float(plan.price_semi_annual),
            'annual': float(plan.price_annual),
        })


class SubscriptionViewSet(viewsets.ReadOnlyModelViewSet):
    """Subscription ViewSet (Read-only for users)"""
    permission_classes = [IsAuthenticated]
    serializer_class = SubscriptionSerializer
    
    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Subscription.objects.none()
        return Subscription.objects.filter(
            business__owner=self.request.user
        ).select_related('plan', 'business')
    
    @action(detail=False, methods=['get'])
    def my_subscription(self, request):
        """Get current user's active subscription"""
        subscription = self.get_queryset().filter(
            status='active'
        ).first()
        
        if subscription:
            serializer = self.get_serializer(subscription)
            return Response(serializer.data)
        
        return Response(
            {'detail': 'No active subscription found'},
            status=status.HTTP_404_NOT_FOUND
        )
