from django.contrib import admin, messages
from django.utils.html import format_html

from .models import Subscription, SubscriptionChangeRequest, SubscriptionPlan
from .services import apply_change_request, reject_change_request


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = (
        'display_name_en',
        'display_name_ar',
        'name',
        'price_monthly',
        'price_annual',
        'max_businesses',
        'max_products',
        'is_active',
        'is_popular',
        'order',
    )
    list_filter = (
        'is_active',
        'is_popular',
        'featured_in_search',
        'can_create_deals',
    )
    search_fields = (
        'display_name_en',
        'display_name_ar',
        'description_en',
        'description_ar',
    )
    fieldsets = (
        ('Basic Information', {
            'fields': (
                'name', 'display_name_en', 'display_name_ar',
                'description_en', 'description_ar',
            )
        }),
        ('Pricing', {
            'fields': (
                'price_monthly', 'price_quarterly',
                'price_semi_annual', 'price_annual',
            )
        }),
        ('Features - Limits', {
            'fields': (
                'max_businesses', 'max_products',
                'max_images_per_product', 'max_business_images',
            )
        }),
        ('Features - Permissions', {
            'fields': (
                'can_upload_images', 'can_show_prices',
                'has_delivery_options', 'has_analytics',
                'featured_in_search', 'can_create_deals',
                'has_social_media_links', 'has_verified_badge',
            )
        }),
        ('Display Settings', {
            'fields': ('color', 'icon', 'order', 'is_active', 'is_popular')
        }),
    )


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = (
        'business', 'plan', 'status_badge', 'start_date', 'end_date',
        'days_remaining_display', 'amount_paid', 'auto_renew',
    )
    list_filter = ('status', 'plan', 'auto_renew', 'start_date', 'end_date')
    search_fields = ('business__name_en', 'business__name_ar', 'transaction_id')
    readonly_fields = ('created_at', 'updated_at', 'cancelled_at')
    fieldsets = (
        ('Subscription Info', {
            'fields': ('business', 'plan', 'status', 'start_date', 'end_date', 'auto_renew')
        }),
        ('Payment Details', {
            'fields': ('amount_paid', 'payment_method', 'transaction_id')
        }),
        ('Notes', {'fields': ('admin_notes',)}),
        ('Timestamps', {'fields': ('created_at', 'updated_at', 'cancelled_at')}),
    )

    def status_badge(self, obj):
        colors = {
            'active': '#28a745', 'expired': '#dc3545',
            'cancelled': '#6c757d', 'pending': '#ffc107',
        }
        return format_html(
            '<span style="background: {}; color: white; padding: 3px 10px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            colors.get(obj.status, '#6c757d'),
            obj.get_status_display(),
        )
    status_badge.short_description = 'Status'

    def days_remaining_display(self, obj):
        days = obj.days_remaining
        color = '#28a745' if days > 7 else '#ffc107' if days > 0 else '#dc3545'
        return format_html(
            '<span style="color: {}; font-weight: bold;">{} days</span>',
            color,
            days,
        )
    days_remaining_display.short_description = 'Days Remaining'

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('business', 'plan')

    actions = ['activate_subscriptions', 'cancel_subscriptions']

    @admin.action(description='Activate selected subscriptions')
    def activate_subscriptions(self, request, queryset):
        for subscription in queryset:
            subscription.activate()
        self.message_user(request, f'{queryset.count()} subscription(s) activated.')

    @admin.action(description='Cancel selected subscriptions')
    def cancel_subscriptions(self, request, queryset):
        for subscription in queryset:
            subscription.cancel()
        self.message_user(request, f'{queryset.count()} subscription(s) cancelled.')


@admin.register(SubscriptionChangeRequest)
class SubscriptionChangeRequestAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'owner', 'change_path', 'change_type', 'billing_period',
        'requested_amount', 'status_badge', 'payment_confirmed', 'created_at',
    )
    list_filter = (
        'status', 'change_type', 'billing_period', 'payment_confirmed',
        'target_plan', 'created_at',
    )
    search_fields = (
        'owner__username', 'owner__email',
        'subscription__business__name_ar', 'subscription__business__name_en',
        'transaction_id',
    )
    readonly_fields = (
        'owner', 'subscription', 'current_plan', 'target_plan', 'change_type',
        'billing_period', 'keep_business_ids', 'keep_product_ids', 'preview',
        'applied_changes', 'requested_amount', 'status', 'reviewed_by',
        'reviewed_at', 'applied_at', 'created_at', 'updated_at',
    )
    fieldsets = (
        ('Request', {
            'fields': (
                'owner', 'subscription', 'current_plan', 'target_plan',
                'change_type', 'billing_period', 'status', 'requested_amount',
            )
        }),
        ('Owner selection', {
            'fields': ('keep_business_ids', 'keep_product_ids', 'preview')
        }),
        ('Payment confirmation', {
            'fields': ('payment_confirmed', 'payment_method', 'transaction_id')
        }),
        ('Admin review', {
            'fields': ('admin_notes', 'rejection_reason', 'reviewed_by', 'reviewed_at')
        }),
        ('Applied result / Audit', {
            'fields': ('applied_changes', 'applied_at', 'created_at', 'updated_at')
        }),
    )
    actions = ['approve_and_apply', 'reject_selected']

    def change_path(self, obj):
        return f'{obj.current_plan.display_name_en} → {obj.target_plan.display_name_en}'
    change_path.short_description = 'Plan change'

    def status_badge(self, obj):
        colors = {
            'pending': '#ffc107', 'approved': '#17a2b8', 'applied': '#28a745',
            'rejected': '#dc3545', 'cancelled': '#6c757d',
        }
        return format_html(
            '<span style="background: {}; color: white; padding: 3px 10px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            colors.get(obj.status, '#6c757d'),
            obj.get_status_display(),
        )
    status_badge.short_description = 'Status'

    @admin.action(description='Approve & apply selected requests')
    def approve_and_apply(self, request, queryset):
        applied = 0
        for change_request in queryset.filter(status='pending'):
            try:
                apply_change_request(change_request, reviewer=request.user)
                applied += 1
            except ValueError as exc:
                self.message_user(
                    request,
                    f'Request #{change_request.pk}: {exc}',
                    level=messages.ERROR,
                )
        if applied:
            self.message_user(request, f'{applied} request(s) applied successfully.')

    @admin.action(description='Reject selected requests')
    def reject_selected(self, request, queryset):
        rejected = 0
        for change_request in queryset.filter(status='pending'):
            reject_change_request(
                change_request,
                reviewer=request.user,
                reason='Rejected by administration.',
            )
            rejected += 1
        if rejected:
            self.message_user(request, f'{rejected} request(s) rejected.')
