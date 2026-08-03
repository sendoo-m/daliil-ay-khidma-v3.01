"""
Directory Serializers
=====================
Serializers for Location & Business models
"""

from rest_framework import serializers
from apps.directory.models import (
    Governorate, City, District, Category,
    Business, BusinessImage, Favorite
)


class GovernorateSerializer(serializers.ModelSerializer):
    """Governorate Serializer"""
    
    class Meta:
        model = Governorate
        fields = [
            'id', 'name_en', 'name_ar', 'slug',
            'description_en', 'description_ar',
            'icon', 'image', 'is_active', 'order'
        ]
        read_only_fields = ['slug']


class CitySerializer(serializers.ModelSerializer):
    """City Serializer"""
    governorate = GovernorateSerializer(read_only=True)
    governorate_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = City
        fields = [
            'id', 'governorate', 'governorate_id',
            'name_en', 'name_ar', 'slug',
            'description_en', 'description_ar',
            'is_active', 'order'
        ]
        read_only_fields = ['slug']


class DistrictSerializer(serializers.ModelSerializer):
    """District Serializer"""
    city = CitySerializer(read_only=True)
    city_id = serializers.IntegerField(write_only=True)
    governorate = serializers.SerializerMethodField()
    
    class Meta:
        model = District
        fields = [
            'id', 'city', 'city_id', 'governorate',
            'name_en', 'name_ar', 'slug',
            'description_en', 'description_ar',
            'is_active', 'order'
        ]
        read_only_fields = ['slug']
    
    def get_governorate(self, obj) -> dict:
        return GovernorateSerializer(obj.governorate).data


class CategorySerializer(serializers.ModelSerializer):
    """Category Serializer"""
    business_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = [
            'id', 'name_en', 'name_ar', 'slug',
            'description_en', 'description_ar',
            'icon', 'image', 'is_active', 'order',
            'business_count'
        ]
        read_only_fields = ['slug']
    
    def get_business_count(self, obj) -> int:
        if hasattr(obj, 'public_business_count'):
            return obj.public_business_count
        # Use business_set which is the correct related_name
        return obj.business_set.filter(is_active=True, is_verified=True).count()


class BusinessImageSerializer(serializers.ModelSerializer):
    """Business Image Serializer"""
    
    class Meta:
        model = BusinessImage
        fields = [
            'id', 'image', 'caption_en', 'caption_ar',
            'order', 'is_active', 'uploaded_at'
        ]


class BusinessListSerializer(serializers.ModelSerializer):
    """Business List Serializer (minimal)"""
    category = CategorySerializer(read_only=True)
    district = DistrictSerializer(read_only=True)
    average_rating = serializers.ReadOnlyField()
    total_reviews = serializers.ReadOnlyField()
    business_type_display = serializers.CharField(source='get_business_type_display', read_only=True)
    business_type_icon = serializers.ReadOnlyField()
    is_shop = serializers.ReadOnlyField()
    is_craft = serializers.ReadOnlyField()
    is_public_service = serializers.ReadOnlyField()
    distance_km = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()
    
    class Meta:
        model = Business
        fields = [
            'id', 'name_en', 'name_ar', 'slug',
            'business_type', 'business_type_display', 'business_type_icon',
            'is_shop', 'is_craft', 'is_public_service',
            'logo', 'category', 'district',
            'phone', 'average_rating', 'total_reviews',
            'is_verified', 'is_featured', 'view_count',
            'latitude', 'longitude', 'distance_km', 'is_favorite'
        ]

    def get_distance_km(self, obj) -> float | None:
        distance = getattr(obj, 'distance_km', None)
        return round(distance, 2) if distance is not None else None

    def get_is_favorite(self, obj) -> bool:
        request = self.context.get('request')
        return bool(request) and request.user.is_authenticated and Favorite.objects.filter(
            user=request.user,
            business=obj,
        ).exists()


class BusinessDetailSerializer(serializers.ModelSerializer):
    """Business Detail Serializer (full)"""
    category = CategorySerializer(read_only=True)
    district = DistrictSerializer(read_only=True)
    images = BusinessImageSerializer(many=True, read_only=True)
    average_rating = serializers.ReadOnlyField()
    total_reviews = serializers.ReadOnlyField()
    city = serializers.SerializerMethodField()
    governorate = serializers.SerializerMethodField()
    business_type_display = serializers.CharField(source='get_business_type_display', read_only=True)
    business_type_icon = serializers.ReadOnlyField()
    is_shop = serializers.ReadOnlyField()
    is_craft = serializers.ReadOnlyField()
    is_public_service = serializers.ReadOnlyField()
    is_favorite = serializers.SerializerMethodField()
    
    class Meta:
        model = Business
        fields = '__all__'
        read_only_fields = ['slug', 'owner', 'view_count', 'click_count']
    
    def get_city(self, obj) -> dict | None:
        if obj.city:
            return CitySerializer(obj.city).data
        return None
    
    def get_governorate(self, obj) -> dict | None:
        if obj.governorate:
            return GovernorateSerializer(obj.governorate).data
        return None

    def get_is_favorite(self, obj) -> bool:
        request = self.context.get('request')
        return bool(request) and request.user.is_authenticated and Favorite.objects.filter(
            user=request.user,
            business=obj,
        ).exists()


class FavoriteSerializer(serializers.ModelSerializer):
    """Favorite Serializer"""
    business = BusinessListSerializer(read_only=True)
    business_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = Favorite
        fields = ['id', 'business', 'business_id', 'created_at']
        read_only_fields = ['created_at']

    def validate_business_id(self, value):
        business = Business.objects.filter(pk=value).first()
        if business is None or not (business.is_active and business.is_verified):
            raise serializers.ValidationError('النشاط غير موجود أو غير منشور')

        request = self.context.get('request')
        if request and Favorite.objects.filter(user=request.user, business_id=value).exists():
            raise serializers.ValidationError('النشاط موجود بالفعل في المفضلة')
        return value
