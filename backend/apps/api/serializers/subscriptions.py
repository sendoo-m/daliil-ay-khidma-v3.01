"""
Subscriptions Serializers
=========================
Serializers for Subscription Plans and change workflow.
"""

from rest_framework import serializers

from apps.subscriptions.models import (
    Subscription,
    SubscriptionChangeRequest,
    SubscriptionPlan,
)
from apps.subscriptions.services import validate_keep_selection


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = '__all__'


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)
    plan_id = serializers.IntegerField(write_only=True)
    is_active = serializers.ReadOnlyField()
    days_remaining = serializers.ReadOnlyField()
    is_expiring_soon = serializers.ReadOnlyField()

    class Meta:
        model = Subscription
        fields = '__all__'
        read_only_fields = ['cancelled_at']


class SubscriptionChangeRequestSerializer(serializers.ModelSerializer):
    current_plan = SubscriptionPlanSerializer(read_only=True)
    target_plan = SubscriptionPlanSerializer(read_only=True)
    target_plan_id = serializers.PrimaryKeyRelatedField(
        source='target_plan',
        queryset=SubscriptionPlan.objects.filter(is_active=True),
        write_only=True,
    )
    subscription_id = serializers.PrimaryKeyRelatedField(
        source='subscription',
        queryset=Subscription.objects.all(),
        write_only=True,
    )
    reviewed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = SubscriptionChangeRequest
        fields = [
            'id',
            'owner',
            'subscription',
            'subscription_id',
            'current_plan',
            'target_plan',
            'target_plan_id',
            'change_type',
            'billing_period',
            'status',
            'keep_business_ids',
            'keep_product_ids',
            'preview',
            'applied_changes',
            'requested_amount',
            'payment_confirmed',
            'payment_method',
            'transaction_id',
            'rejection_reason',
            'admin_notes',
            'reviewed_by',
            'reviewed_by_name',
            'reviewed_at',
            'applied_at',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'owner',
            'subscription',
            'current_plan',
            'target_plan',
            'change_type',
            'status',
            'preview',
            'applied_changes',
            'requested_amount',
            'payment_confirmed',
            'payment_method',
            'transaction_id',
            'rejection_reason',
            'admin_notes',
            'reviewed_by',
            'reviewed_at',
            'applied_at',
            'created_at',
            'updated_at',
        ]

    def get_reviewed_by_name(self, obj):
        if not obj.reviewed_by:
            return ''
        return obj.reviewed_by.get_full_name() or obj.reviewed_by.get_username()

    def validate_subscription_id(self, subscription):
        request = self.context['request']
        if not request.user.is_staff and subscription.business.owner_id != request.user.id:
            raise serializers.ValidationError('This subscription does not belong to you.')
        return subscription

    def validate(self, attrs):
        subscription = attrs['subscription']
        target_plan = attrs['target_plan']
        owner = subscription.business.owner
        keep_business_ids = attrs.get('keep_business_ids', [])
        keep_product_ids = attrs.get('keep_product_ids', [])
        try:
            businesses, products = validate_keep_selection(
                owner=owner,
                target_plan=target_plan,
                keep_business_ids=keep_business_ids,
                keep_product_ids=keep_product_ids,
            )
        except ValueError as exc:
            raise serializers.ValidationError(str(exc)) from exc
        attrs['keep_business_ids'] = businesses
        attrs['keep_product_ids'] = products
        return attrs
