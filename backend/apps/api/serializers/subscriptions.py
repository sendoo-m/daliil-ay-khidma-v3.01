"""
Subscriptions Serializers
=========================
Serializers for Subscription Plans
"""

from rest_framework import serializers
from apps.subscriptions.models import SubscriptionPlan, Subscription


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    """Subscription Plan Serializer"""
    
    class Meta:
        model = SubscriptionPlan
        fields = '__all__'


class SubscriptionSerializer(serializers.ModelSerializer):
    """Subscription Serializer"""
    plan = SubscriptionPlanSerializer(read_only=True)
    plan_id = serializers.IntegerField(write_only=True)
    is_active = serializers.ReadOnlyField()
    days_remaining = serializers.ReadOnlyField()
    is_expiring_soon = serializers.ReadOnlyField()
    
    class Meta:
        model = Subscription
        fields = '__all__'
        read_only_fields = ['cancelled_at']
