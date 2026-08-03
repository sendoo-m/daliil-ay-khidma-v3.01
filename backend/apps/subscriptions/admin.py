from django.contrib import admin
from django.utils.html import format_html
from .models import SubscriptionPlan, Subscription


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = (
        'display_name_en',
        'display_name_ar',
        'name',
        'price_monthly',
        'price_annual',
        'max_products',
        'is_active',
        'is_popular',
        'order'
    )
    
    list_filter = (
        'is_active',
        'is_popular',
        'featured_in_search',
        'can_create_deals'
    )
    
    search_fields = (
        'display_name_en',
        'display_name_ar',
        'description_en',
        'description_ar'
    )
    
    fieldsets = (
        ('Basic Information', {
            'fields': (
                'name',
                'display_name_en',
                'display_name_ar',
                'description_en',
                'description_ar'
            )
        }),
        ('Pricing', {
            'fields': (
                'price_monthly',
                'price_quarterly',
                'price_semi_annual',
                'price_annual'
            )
        }),
        ('Features - Limits', {
            'fields': (
                'max_products',
                'max_images_per_product',
                'max_business_images'
            )
        }),
        ('Features - Permissions', {
            'fields': (
                'can_upload_images',
                'can_show_prices',
                'has_delivery_options',
                'has_analytics',
                'featured_in_search',
                'can_create_deals',
                'has_social_media_links',
                'has_verified_badge'
            )
        }),
        ('Display Settings', {
            'fields': (
                'color',
                'icon',
                'order',
                'is_active',
                'is_popular'
            )
        }),
    )


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = (
        'business',
        'plan',
        'status_badge',
        'start_date',
        'end_date',
        'days_remaining_display',
        'amount_paid',
        'auto_renew'
    )
    
    list_filter = (
        'status',
        'plan',
        'auto_renew',
        'start_date',
        'end_date'
    )
    
    search_fields = (
        'business__name_en',
        'business__name_ar',
        'transaction_id'
    )
    
    readonly_fields = (
        'created_at',
        'updated_at',
        'cancelled_at'
    )
    
    fieldsets = (
        ('Subscription Info', {
            'fields': (
                'business',
                'plan',
                'status',
                'start_date',
                'end_date',
                'auto_renew'
            )
        }),
        ('Payment Details', {
            'fields': (
                'amount_paid',
                'payment_method',
                'transaction_id'
            )
        }),
        ('Notes', {
            'fields': (
                'admin_notes',
            )
        }),
        ('Timestamps', {
            'fields': (
                'created_at',
                'updated_at',
                'cancelled_at'
            )
        }),
    )
    
    def status_badge(self, obj):
        colors = {
            'active': '#28a745',
            'expired': '#dc3545',
            'cancelled': '#6c757d',
            'pending': '#ffc107',
        }
        color = colors.get(obj.status, '#6c757d')
        return format_html(
            '<span style="background: {}; color: white; padding: 3px 10px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color,
            obj.get_status_display()
        )
    status_badge.short_description = 'Status'
    
    def days_remaining_display(self, obj):
        days = obj.days_remaining
        if days > 7:
            color = '#28a745'
        elif days > 0:
            color = '#ffc107'
        else:
            color = '#dc3545'
        
        return format_html(
            '<span style="color: {}; font-weight: bold;">{} days</span>',
            color,
            days
        )
    days_remaining_display.short_description = 'Days Remaining'
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related(
            'business',
            'plan'
        )
    
    actions = ['activate_subscriptions', 'cancel_subscriptions']
    
    def activate_subscriptions(self, request, queryset):
        count = 0
        for sub in queryset:
            sub.activate()
            count += 1
        self.message_user(request, f'{count} subscription(s) activated.')
    activate_subscriptions.short_description = 'Activate selected subscriptions'
    
    def cancel_subscriptions(self, request, queryset):
        count = 0
        for sub in queryset:
            sub.cancel()
            count += 1
        self.message_user(request, f'{count} subscription(s) cancelled.')
    cancel_subscriptions.short_description = 'Cancel selected subscriptions'
