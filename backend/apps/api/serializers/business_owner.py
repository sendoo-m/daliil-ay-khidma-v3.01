"""Business Owner API Serializers"""
from rest_framework import serializers
from django.utils import timezone

from apps.directory.models import Business, BusinessImage
from apps.products.models import Product, ProductImage
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.api.validators import validate_image_upload


class BusinessOwnerImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessImage
        exclude = ['business']
        read_only_fields = ['uploaded_at']

    def validate_image(self, value):
        return validate_image_upload(value)


class BusinessOwnerProductImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductImage
        exclude = ['product']
        read_only_fields = ['uploaded_at']

    def validate_image(self, value):
        return validate_image_upload(value)


class BusinessOwnerStatsSerializer(serializers.Serializer):
    total_businesses = serializers.IntegerField()
    verified_businesses = serializers.IntegerField()
    total_products = serializers.IntegerField()
    total_deals = serializers.IntegerField()
    active_deals = serializers.IntegerField()
    total_reviews = serializers.IntegerField()
    average_rating = serializers.FloatField()
    total_views = serializers.IntegerField()
    total_clicks = serializers.IntegerField()


class BusinessOwnerBusinessSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name_ar', read_only=True)
    business_type_display = serializers.CharField(source='get_business_type_display', read_only=True)
    products_count = serializers.SerializerMethodField()
    deals_count = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()

    class Meta:
        model = Business
        exclude = ['owner']
        read_only_fields = ['slug', 'view_count', 'click_count', 'created_at', 'updated_at']

    def get_products_count(self, obj) -> int:
        return obj.products.count()

    def get_deals_count(self, obj) -> int:
        return obj.deals.count()

    def get_reviews_count(self, obj) -> int:
        return obj.reviews.filter(is_approved=True).count()

    def get_average_rating(self, obj) -> float:
        return float(obj.average_rating or 0)

    def validate_logo(self, value):
        return validate_image_upload(value)

    def validate_cover_image(self, value):
        return validate_image_upload(value)


class BusinessOwnerProductSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    product_type_display = serializers.CharField(source='get_product_type_display', read_only=True)

    class Meta:
        model = Product
        exclude = ['business']
        read_only_fields = ['slug', 'created_at', 'updated_at']


class BusinessOwnerDealSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    deal_type_display = serializers.CharField(source='get_deal_type_display', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    days_remaining = serializers.SerializerMethodField()
    usage_percentage = serializers.SerializerMethodField()

    class Meta:
        model = Deal
        exclude = ['business']
        read_only_fields = ['slug', 'used_count', 'created_at', 'updated_at']

    def get_days_remaining(self, obj) -> int | None:
        if obj.end_date:
            delta = obj.end_date - timezone.now().date()
            return delta.days if delta.days > 0 else 0
        return None

    def get_usage_percentage(self, obj) -> float:
        if obj.max_uses and obj.max_uses > 0:
            return round((obj.used_count / obj.max_uses) * 100, 2)
        return 0

    def validate_image(self, value):
        return validate_image_upload(value)


class BusinessOwnerReviewSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    business_name = serializers.CharField(source='business.name_ar', read_only=True)

    class Meta:
        model = Review
        fields = '__all__'
        read_only_fields = ['user', 'business', 'is_approved', 'approved_at', 'approved_by', 'created_at', 'updated_at']
