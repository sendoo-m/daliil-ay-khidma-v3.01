# apps/dashboard/api/serializers/owner_serializers.py

from rest_framework import serializers
from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review


class OwnerBusinessSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name_ar', read_only=True)
    reviews_count = serializers.IntegerField(source='total_reviews',  read_only=True)

    class Meta:
        model  = Business
        fields = [
            'id', 'name_ar', 'name_en', 'slug', 'category_name',
            'is_active', 'is_verified', 'is_featured',
            'view_count', 'click_count', 'average_rating', 'reviews_count',
            'logo', 'created_at',
        ]
        read_only_fields = ['is_verified', 'view_count', 'click_count']


class OwnerProductSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Product
        fields = [
            'id', 'name_ar', 'name_en', 'price',
            'is_available', 'is_featured',
            'image', 'created_at',
        ]


class OwnerDealSerializer(serializers.ModelSerializer):
    is_expired = serializers.SerializerMethodField()

    class Meta:
        model  = Deal
        fields = [
            'id', 'title_ar', 'title_en',
            'discount_type', 'discount_value',
            'start_date', 'end_date',
            'is_active', 'is_expired',
            'current_uses', 'max_uses',
            'created_at',
        ]

    def get_is_expired(self, obj):
        from django.utils import timezone
        return obj.end_date < timezone.now()


class OwnerReviewSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    business_name = serializers.CharField(source='business.name_ar', read_only=True)

    class Meta:
        model  = Review
        fields = [
            'id', 'business_name', 'user_username',
            'rating', 'comment', 'is_approved', 'created_at',
        ]


class OwnerStatsSerializer(serializers.Serializer):
    total_businesses  = serializers.IntegerField()
    active_businesses = serializers.IntegerField()
    verified_count    = serializers.IntegerField()
    total_products    = serializers.IntegerField()
    active_products   = serializers.IntegerField()
    total_deals       = serializers.IntegerField()
    active_deals      = serializers.IntegerField()
    total_reviews     = serializers.IntegerField()
    average_rating    = serializers.FloatField()
    total_views       = serializers.IntegerField()
    total_clicks      = serializers.IntegerField()
