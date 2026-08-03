from django.contrib import admin
from .models import Product, ProductImage


class ProductImageInline(admin.TabularInline):
    model = ProductImage
    extra = 1
    fields = ('image', 'alt_text_en', 'alt_text_ar', 'is_primary', 'order')


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = (
        'name_en',
        'name_ar',
        'business',
        'product_type',
        'price',
        'is_available',
        'is_featured',
        'view_count',
        'created_at'
    )
    
    list_filter = (
        'product_type',
        'is_available',
        'is_featured',
        'has_delivery',
        'created_at'
    )
    
    search_fields = (
        'name_en',
        'name_ar',
        'description_en',
        'description_ar',
        'business__name_en',
        'business__name_ar'
    )
    
    readonly_fields = ('slug', 'view_count', 'created_at', 'updated_at')
    
    fieldsets = (
        ('Basic Information', {
            'fields': (
                'business',
                'product_type',
                'name_en',
                'name_ar',
                'slug'
            )
        }),
        ('Description', {
            'fields': (
                'description_en',
                'description_ar'
            )
        }),
        ('Pricing', {
            'fields': (
                'price',
                'old_price'
            )
        }),
        ('Availability', {
            'fields': (
                'is_available',
                'stock_quantity'
            )
        }),
        ('Delivery', {
            'fields': (
                'has_delivery',
                'delivery_cost',
                'delivery_time_en',
                'delivery_time_ar'
            )
        }),
        ('Display Settings', {
            'fields': (
                'order',
                'is_featured'
            )
        }),
        ('Statistics', {
            'fields': (
                'view_count',
                'created_at',
                'updated_at'
            )
        }),
    )
    
    inlines = [ProductImageInline]
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('business')


@admin.register(ProductImage)
class ProductImageAdmin(admin.ModelAdmin):
    list_display = (
        'product',
        'is_primary',
        'order',
        'uploaded_at'
    )
    
    list_filter = (
        'is_primary',
        'uploaded_at'
    )
    
    search_fields = (
        'product__name_en',
        'product__name_ar',
        'alt_text_en',
        'alt_text_ar'
    )
