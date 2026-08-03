# apps/dashboard/api/serializers/admin_serializers.py

from rest_framework import serializers
from apps.accounts.models import User
from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.categories.models import Category


class AdminUserSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    businesses_count = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = [
            'id', 'username', 'email', 'full_name', 'phone',
            'is_active', 'is_staff', 'is_business_owner',
            'date_joined', 'businesses_count',
        ]

    def get_full_name(self, obj):
        return obj.get_full_name() or obj.username

    def get_businesses_count(self, obj):
        return Business.objects.filter(owner=obj).count()


class AdminBusinessSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source='owner.username', read_only=True)
    category_name  = serializers.CharField(source='category.name_ar', read_only=True)

    class Meta:
        model  = Business
        fields = [
            'id', 'name_ar', 'name_en', 'slug',
            'owner_username', 'category_name',
            'is_active', 'is_verified', 'is_featured', 'is_promoted',
            'view_count', 'click_count', 'average_rating', 'total_reviews',
            'created_at',
        ]


class AdminReviewSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    user_username = serializers.CharField(source='user.username',    read_only=True)

    class Meta:
        model  = Review
        fields = [
            'id', 'business_name', 'user_username',
            'rating', 'comment', 'is_approved', 'created_at',
        ]


class AdminStatsSerializer(serializers.Serializer):
    # Users
    total_users         = serializers.IntegerField()
    active_users        = serializers.IntegerField()
    new_users_week      = serializers.IntegerField()
    # Businesses
    total_businesses    = serializers.IntegerField()
    verified_businesses = serializers.IntegerField()
    pending_verification= serializers.IntegerField()
    new_businesses_week = serializers.IntegerField()
    # Products
    total_products      = serializers.IntegerField()
    active_products     = serializers.IntegerField()
    # Deals
    total_deals         = serializers.IntegerField()
    active_deals        = serializers.IntegerField()
    # Reviews
    total_reviews       = serializers.IntegerField()
    pending_reviews     = serializers.IntegerField()
    average_rating      = serializers.FloatField()
    # Engagement
    total_views         = serializers.IntegerField()
    total_clicks        = serializers.IntegerField()
