from django.contrib import admin
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from django.utils import timezone
from .models import Deal, DealClaim


@admin.register(Deal)
class DealAdmin(admin.ModelAdmin):
    list_display = (
        'title_en',
        'business',
        'deal_type',
        'status_badge',
        'discount_display',
        'validity_period',
        'uses_display',
        'is_featured',
        'view_count'
    )
    
    list_filter = (
        'deal_type',
        'is_active',
        'is_featured',
        'start_date',
        'end_date',
        'created_at'
    )
    
    search_fields = (
        'title_en',
        'title_ar',
        'description_en',
        'description_ar',
        'business__name_en',
        'business__name_ar',
        'slug'
    )
    
    readonly_fields = (
        'slug',
        'current_uses',
        'view_count',
        'created_at',
        'updated_at',
        'preview_url'
    )
    
    fieldsets = (
        ('Basic Information', {
            'fields': (
                'business',
                'title_en',
                'title_ar',
                'slug',
                'description_en',
                'description_ar',
                'preview_url'
            )
        }),
        ('Deal Details', {
            'fields': (
                'deal_type',
                'discount_percentage',
                'discount_amount',
                'original_price',
                'final_price'
            )
        }),
        ('Validity', {
            'fields': (
                'start_date',
                'end_date'
            )
        }),
        ('Terms & Conditions', {
            'fields': (
                'terms_en',
                'terms_ar'
            ),
            'classes': ('collapse',)
        }),
        ('Image', {
            'fields': ('image',)
        }),
        ('Limits', {
            'fields': (
                'max_uses',
                'current_uses',
                'max_uses_per_user'
            )
        }),
        ('Display Settings', {
            'fields': (
                'is_active',
                'is_featured',
                'order'
            )
        }),
        ('Statistics', {
            'fields': (
                'view_count',
                'created_at',
                'updated_at'
            ),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['activate_deals', 'deactivate_deals', 'feature_deals', 'unfeature_deals']
    
    def preview_url(self, obj):
        """Show preview URL"""
        if obj.pk:
            url = obj.get_absolute_url()
            return mark_safe(f'<a href="{url}" target="_blank">{url}</a>')
        return '-'
    preview_url.short_description = 'Preview URL'
    
    def status_badge(self, obj):
        """Display status badge"""
        if obj.is_expired:
            return mark_safe(
                '<span style="background: #dc3545; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Expired</span>'
            )
        elif obj.is_upcoming:
            return mark_safe(
                '<span style="background: #17a2b8; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Upcoming</span>'
            )
        elif obj.is_valid:
            return mark_safe(
                '<span style="background: #28a745; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Active</span>'
            )
        else:
            return mark_safe(
                '<span style="background: #6c757d; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Inactive</span>'
            )
    status_badge.short_description = 'Status'
    
    def discount_display(self, obj):
        """Display discount"""
        if obj.deal_type == 'percentage' and obj.discount_percentage:
            return f"{obj.discount_percentage}%"
        elif obj.deal_type == 'fixed' and obj.discount_amount:
            return f"{obj.discount_amount} EGP"
        else:
            return '-'
    discount_display.short_description = 'Discount'
    
    def validity_period(self, obj):
        """Display validity period"""
        return f"{obj.start_date.strftime('%Y-%m-%d')} → {obj.end_date.strftime('%Y-%m-%d')}"
    validity_period.short_description = 'Validity'
    
    def uses_display(self, obj):
        """Display uses"""
        if obj.max_uses:
            percentage = (obj.current_uses / obj.max_uses) * 100
            color = '#28a745' if percentage < 80 else '#ffc107' if percentage < 100 else '#dc3545'
            return mark_safe(
                f'<span style="color: {color}; font-weight: bold;">'
                f'{obj.current_uses}/{obj.max_uses}</span>'
            )
        return f"{obj.current_uses}/∞"
    uses_display.short_description = 'Uses'
    
    def activate_deals(self, request, queryset):
        """Activate selected deals"""
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} deal(s) activated successfully.')
    activate_deals.short_description = 'Activate selected deals'
    
    def deactivate_deals(self, request, queryset):
        """Deactivate selected deals"""
        updated = queryset.update(is_active=False)
        self.message_user(request, f'{updated} deal(s) deactivated successfully.')
    deactivate_deals.short_description = 'Deactivate selected deals'
    
    def feature_deals(self, request, queryset):
        """Feature selected deals"""
        updated = queryset.update(is_featured=True)
        self.message_user(request, f'{updated} deal(s) featured successfully.')
    feature_deals.short_description = 'Feature selected deals'
    
    def unfeature_deals(self, request, queryset):
        """Unfeature selected deals"""
        updated = queryset.update(is_featured=False)
        self.message_user(request, f'{updated} deal(s) unfeatured successfully.')
    unfeature_deals.short_description = 'Unfeature selected deals'
    
    def get_queryset(self, request):
        """Optimize queryset"""
        return super().get_queryset(request).select_related('business')


@admin.register(DealClaim)
class DealClaimAdmin(admin.ModelAdmin):
    list_display = (
        'deal',
        'user',
        'claimed_at',
        'status_badge',
        'used_at'
    )
    
    list_filter = (
        'is_used',
        'claimed_at',
        'used_at'
    )
    
    search_fields = (
        'deal__title_en',
        'deal__title_ar',
        'user__username',
        'user__email',
        'user__first_name',
        'user__last_name'
    )
    
    readonly_fields = ('claimed_at', 'used_at')
    
    date_hierarchy = 'claimed_at'
    
    def status_badge(self, obj):
        """Display status"""
        if obj.is_used:
            return mark_safe(
                '<span style="background: #28a745; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Used</span>'
            )
        elif obj.deal.is_expired:
            return mark_safe(
                '<span style="background: #dc3545; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Expired</span>'
            )
        else:
            return mark_safe(
                '<span style="background: #17a2b8; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Active</span>'
            )
    status_badge.short_description = 'Status'
    
    def get_queryset(self, request):
        """Optimize queryset"""
        return super().get_queryset(request).select_related('deal', 'user')
