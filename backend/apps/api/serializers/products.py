"""
Products Serializers
====================
Serializers for Products & Services
"""

from rest_framework import serializers
from apps.products.models import Product, ProductImage
from .directory import BusinessListSerializer


class ProductImageSerializer(serializers.ModelSerializer):
    """Product Image Serializer"""
    
    class Meta:
        model = ProductImage
        fields = [
            'id', 'image', 'alt_text_en', 'alt_text_ar',
            'is_primary', 'order', 'uploaded_at'
        ]


class ProductListSerializer(serializers.ModelSerializer):
    """Product List Serializer (minimal)"""
    business = BusinessListSerializer(read_only=True)
    primary_image = serializers.SerializerMethodField()
    discount_percentage = serializers.ReadOnlyField()
    has_discount = serializers.ReadOnlyField()
    
    class Meta:
        model = Product
        fields = [
            'id', 'name_en', 'name_ar', 'slug',
            'product_type', 'price', 'old_price',
            'discount_percentage', 'has_discount',
            'is_available', 'is_featured',
            'business', 'primary_image', 'view_count'
        ]
    
    def get_primary_image(self, obj) -> dict | None:
        primary = obj.images.filter(is_primary=True).first()
        if primary:
            return ProductImageSerializer(primary).data
        first_image = obj.images.first()
        if first_image:
            return ProductImageSerializer(first_image).data
        return None


class ProductDetailSerializer(serializers.ModelSerializer):
    """Product Detail Serializer (full)"""
    business = BusinessListSerializer(read_only=True)
    images = ProductImageSerializer(many=True, read_only=True)
    discount_percentage = serializers.ReadOnlyField()
    has_discount = serializers.ReadOnlyField()
    is_in_stock = serializers.ReadOnlyField()
    
    class Meta:
        model = Product
        fields = '__all__'
        read_only_fields = ['slug', 'view_count']


class ProductCreateUpdateSerializer(serializers.ModelSerializer):
    """Product Create/Update Serializer"""
    
    class Meta:
        model = Product
        exclude = ['slug', 'view_count']
