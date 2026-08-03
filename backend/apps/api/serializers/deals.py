"""
Deals Serializers
=================
Serializers for Deals & Offers
"""

from rest_framework import serializers
from apps.deals.models import Deal, DealClaim
from .directory import BusinessListSerializer


class DealListSerializer(serializers.ModelSerializer):
    """Deal List Serializer (minimal)"""
    business = BusinessListSerializer(read_only=True)
    discount_percentage = serializers.ReadOnlyField()
    days_remaining = serializers.ReadOnlyField()
    is_valid = serializers.ReadOnlyField()
    remaining_uses = serializers.ReadOnlyField()
    
    class Meta:
        model = Deal
        fields = [
            'id', 'title_en', 'title_ar', 'slug',
            'deal_type', 'discount_percentage',
            'original_price', 'final_price',
            'start_date', 'end_date',
            'days_remaining', 'is_valid',
            'business', 'image', 'is_featured',
            'remaining_uses', 'view_count'
        ]


class DealDetailSerializer(serializers.ModelSerializer):
    """Deal Detail Serializer (full)"""
    business = BusinessListSerializer(read_only=True)
    discount_percentage = serializers.ReadOnlyField()
    days_remaining = serializers.ReadOnlyField()
    is_valid = serializers.ReadOnlyField()
    is_expired = serializers.ReadOnlyField()
    is_upcoming = serializers.ReadOnlyField()
    remaining_uses = serializers.ReadOnlyField()
    savings_amount = serializers.ReadOnlyField()
    
    class Meta:
        model = Deal
        fields = '__all__'
        read_only_fields = ['slug', 'current_uses', 'view_count']


class DealClaimSerializer(serializers.ModelSerializer):
    """Deal Claim Serializer"""
    deal = DealListSerializer(read_only=True)
    deal_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = DealClaim
        fields = [
            'id', 'deal', 'deal_id',
            'claimed_at', 'is_used', 'used_at', 'notes'
        ]
        read_only_fields = ['claimed_at', 'used_at']
