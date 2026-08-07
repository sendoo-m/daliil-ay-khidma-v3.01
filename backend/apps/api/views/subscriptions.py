"""
Subscriptions API Views
=======================
ViewSets for plans, subscriptions and change requests.
"""

from django.db import IntegrityError
from django.utils import timezone
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response

from apps.api.serializers.subscriptions import (
    SubscriptionChangeRequestSerializer,
    SubscriptionPlanSerializer,
    SubscriptionSerializer,
)
from apps.subscriptions.models import (
    Subscription,
    SubscriptionChangeRequest,
    SubscriptionPlan,
)
from apps.subscriptions.services import (
    apply_change_request,
    build_change_preview,
    change_type,
    notify_staff_new_request,
    reject_change_request,
)


class SubscriptionPlanViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SubscriptionPlan.objects.filter(is_active=True)
    serializer_class = SubscriptionPlanSerializer
    filter_backends = [filters.OrderingFilter]
    ordering = ['order', 'price_monthly']

    @action(detail=True, methods=['get'])
    def pricing(self, request, pk=None):
        plan = self.get_object()
        return Response(
            {
                'monthly': float(plan.price_monthly),
                'quarterly': float(plan.price_quarterly),
                'semi_annual': float(plan.price_semi_annual),
                'annual': float(plan.price_annual),
            }
        )


class SubscriptionViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SubscriptionSerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Subscription.objects.none()
        queryset = Subscription.objects.select_related('plan', 'business', 'business__owner')
        if self.request.user.is_staff:
            return queryset
        return queryset.filter(business__owner=self.request.user)

    @action(detail=False, methods=['get'])
    def my_subscription(self, request):
        subscription = self.get_queryset().filter(status='active').first()
        if subscription:
            return Response(self.get_serializer(subscription).data)
        return Response(
            {'detail': 'No active subscription found'},
            status=status.HTTP_404_NOT_FOUND,
        )


class SubscriptionChangeRequestViewSet(viewsets.ModelViewSet):
    """طلبات الترقية/التخفيض مع معاينة الأثر قبل الموافقة."""

    serializer_class = SubscriptionChangeRequestSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    def get_permissions(self):
        if self.action in {'approve', 'reject'}:
            return [IsAdminUser()]
        return [IsAuthenticated()]

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return SubscriptionChangeRequest.objects.none()
        queryset = SubscriptionChangeRequest.objects.select_related(
            'owner',
            'subscription',
            'subscription__business',
            'current_plan',
            'target_plan',
            'reviewed_by',
        )
        if self.request.user.is_staff:
            return queryset
        return queryset.filter(owner=self.request.user)

    @action(detail=False, methods=['post'])
    def preview(self, request):
        try:
            subscription_id = int(request.data.get('subscription_id'))
            target_plan_id = int(request.data.get('target_plan_id'))
        except (TypeError, ValueError):
            return Response(
                {'detail': 'subscription_id and target_plan_id are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        subscriptions = Subscription.objects.select_related('plan', 'business', 'business__owner')
        if not request.user.is_staff:
            subscriptions = subscriptions.filter(business__owner=request.user)
        try:
            subscription = subscriptions.get(pk=subscription_id)
            target_plan = SubscriptionPlan.objects.get(pk=target_plan_id, is_active=True)
        except (Subscription.DoesNotExist, SubscriptionPlan.DoesNotExist):
            return Response({'detail': 'Subscription or plan not found.'}, status=404)

        billing_period = request.data.get('billing_period', 'monthly')
        if billing_period not in dict(SubscriptionPlan.DURATION_CHOICES):
            return Response({'detail': 'Invalid billing period.'}, status=400)

        preview = build_change_preview(
            owner=subscription.business.owner,
            subscription=subscription,
            target_plan=target_plan,
            billing_period=billing_period,
        )
        return Response(preview)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription = serializer.validated_data['subscription']
        target_plan = serializer.validated_data['target_plan']
        owner = subscription.business.owner

        if not request.user.is_staff and owner.id != request.user.id:
            return Response({'detail': 'This subscription does not belong to you.'}, status=403)
        if subscription.plan_id == target_plan.id:
            return Response({'detail': 'Target plan is already active.'}, status=400)
        if SubscriptionChangeRequest.objects.filter(
            subscription=subscription,
            status='pending',
        ).exists():
            return Response(
                {'detail': 'There is already a pending change request.'},
                status=status.HTTP_409_CONFLICT,
            )

        billing_period = serializer.validated_data.get('billing_period', 'monthly')
        preview = build_change_preview(
            owner=owner,
            subscription=subscription,
            target_plan=target_plan,
            billing_period=billing_period,
        )
        try:
            change_request = serializer.save(
                owner=owner,
                current_plan=subscription.plan,
                change_type=change_type(subscription.plan, target_plan),
                preview=preview,
                requested_amount=target_plan.get_price(billing_period),
            )
        except IntegrityError:
            return Response(
                {'detail': 'There is already a pending change request.'},
                status=status.HTTP_409_CONFLICT,
            )
        notify_staff_new_request(change_request)
        headers = self.get_success_headers(serializer.data)
        return Response(
            self.get_serializer(change_request).data,
            status=status.HTTP_201_CREATED,
            headers=headers,
        )

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        change_request = self.get_object()
        if change_request.status != 'pending':
            return Response({'detail': 'Request is not pending.'}, status=409)

        payment_confirmed = bool(request.data.get('payment_confirmed', False))
        change_request.payment_confirmed = payment_confirmed
        change_request.payment_method = str(request.data.get('payment_method', '')).strip()
        change_request.transaction_id = str(request.data.get('transaction_id', '')).strip()
        change_request.admin_notes = str(request.data.get('admin_notes', '')).strip()
        change_request.status = 'approved'
        change_request.reviewed_by = request.user
        change_request.reviewed_at = timezone.now()
        change_request.save(
            update_fields=[
                'payment_confirmed',
                'payment_method',
                'transaction_id',
                'admin_notes',
                'status',
                'reviewed_by',
                'reviewed_at',
                'updated_at',
            ]
        )
        try:
            applied = apply_change_request(change_request, reviewer=request.user)
        except ValueError as exc:
            change_request.status = 'pending'
            change_request.save(update_fields=['status', 'updated_at'])
            return Response({'detail': str(exc)}, status=400)
        return Response(self.get_serializer(applied).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        change_request = self.get_object()
        reason = str(request.data.get('reason', '')).strip()
        if not reason:
            return Response({'detail': 'Rejection reason is required.'}, status=400)
        try:
            rejected = reject_change_request(
                change_request,
                reviewer=request.user,
                reason=reason,
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=409)
        return Response(self.get_serializer(rejected).data)
