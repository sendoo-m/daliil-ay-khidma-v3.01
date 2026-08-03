"""
Category Admin Configuration
============================
إعدادات Django Admin للتصنيفات مع واجهة محسّنة
"""

from django.contrib import admin
from django.utils.html import format_html
from django.utils.translation import gettext_lazy as _
from django.db import models
from django.db.models import Count, Q
from django.urls import reverse
from django.utils.safestring import mark_safe

from apps.directory.models import Category


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    """إدارة التصنيفات في Admin بشكل احترافي"""
    
    # ========================================
    # LIST DISPLAY
    # ========================================
    list_display = [
        'icon_display',
        'name_display',
        'parent_link',
        'order',
        'business_count',
        'status_badge',
        'created_at',
    ]
    # خلي الرابط الأساسي هو اسم التصنيف بدل الأيقونة
    list_display_links = ['name_display']
    
    # ========================================
    # LIST FILTERS
    # ========================================
    list_filter = [
        'is_active',
        ('parent', admin.RelatedOnlyFieldListFilter),
        'created_at',
        'updated_at',
    ]
    
    # ========================================
    # SEARCH
    # ========================================
    search_fields = [
        'name_en',
        'name_ar',
        'slug',
        'description_en',
        'description_ar',
    ]
    
    # ========================================
    # EDITABLE
    # ========================================
    list_editable = ['order']
    
    # ========================================
    # PREPOPULATED FIELDS
    # ========================================
    prepopulated_fields = {'slug': ('name_en',)}
    
    # ========================================
    # ORDERING
    # ========================================
    ordering = ['order', 'name_en']
    
    # ========================================
    # PAGINATION
    # ========================================
    list_per_page = 50
    list_max_show_all = 200
    
    # ========================================
    # READONLY FIELDS (DYNAMIC)
    # ========================================
    def get_readonly_fields(self, request, obj=None):
        """Show readonly fields only when editing"""
        if obj:  # Editing existing object
            return ['created_at', 'updated_at', 'image_preview', 'business_stats']
        return ['created_at', 'updated_at']  # Adding new object
    
    # ========================================
    # FIELDSETS (DYNAMIC)
    # ========================================
    def get_fieldsets(self, request, obj=None):
        """Dynamic fieldsets based on add/edit"""
        if obj:  # Editing
            return (
                (_('Basic Information'), {
                    'fields': (
                        ('name_en', 'name_ar'),
                        'slug',
                        ('parent', 'is_active'),
                    ),
                }),
                (_('Descriptions'), {
                    'fields': (
                        'description_en',
                        'description_ar',
                    ),
                    'classes': ('collapse',),
                }),
                (_('Visual & Display'), {
                    'fields': (
                        'icon',
                        ('image', 'image_preview'),
                        'order',
                    ),
                }),
                (_('SEO & Meta'), {
                    'fields': (
                        'meta_keywords_en',
                        'meta_keywords_ar',
                    ),
                    'classes': ('collapse',),
                }),
                (_('Statistics'), {
                    'fields': (
                        'business_stats',
                    ),
                    'classes': ('collapse',),
                }),
                (_('Timestamps'), {
                    'fields': (
                        ('created_at', 'updated_at'),
                    ),
                    'classes': ('collapse',),
                }),
            )
        else:  # Adding
            return (
                (_('Basic Information'), {
                    'fields': (
                        ('name_en', 'name_ar'),
                        'slug',
                        ('parent', 'is_active'),
                    ),
                }),
                (_('Descriptions'), {
                    'fields': (
                        'description_en',
                        'description_ar',
                    ),
                    'classes': ('collapse',),
                }),
                (_('Visual & Display'), {
                    'fields': (
                        'icon',
                        'image',
                        'order',
                    ),
                }),
                (_('SEO & Meta'), {
                    'fields': (
                        'meta_keywords_en',
                        'meta_keywords_ar',
                    ),
                    'classes': ('collapse',),
                }),
            )
    
    # ========================================
    # CUSTOM DISPLAY METHODS
    # ========================================
    
    @admin.display(description='Icon')
    def icon_display(self, obj):
        """Display icon with fallback"""
        if obj.icon:
            return format_html(
                '<i class="{}" style="font-size: 24px; color: #1976d2;"></i>',
                obj.icon
            )
        return mark_safe('<span style="color: #ccc; font-size: 18px;">📁</span>')
    
    @admin.display(description='Name', ordering='name_en')
    def name_display(self, obj):
        """Display name in both languages"""
        name_en = obj.name_en or obj.name_ar
        name_ar = obj.name_ar if obj.name_en else ''
        return format_html(
            '<div style="line-height: 1.6;">'
            '<strong style="color: #1976d2; font-size: 14px;">{}</strong><br>'
            '<small style="color: #666;">{}</small>'
            '</div>',
            name_en,
            name_ar
        )
    
    @admin.display(description='Parent Category')
    def parent_link(self, obj):
        """Link to parent category"""
        if obj.parent:
            url = reverse('admin:directory_category_change', args=[obj.parent.pk])
            icon = obj.parent.icon or 'fa fa-folder'
            name = obj.parent.name_en or obj.parent.name_ar
            return format_html(
                '<a href="{}" style="color: #1976d2; text-decoration: none;">'
                '<i class="{}"></i> {}</a>',
                url,
                icon,
                name
            )
        return mark_safe('<span style="color: #4caf50; font-weight: bold;">● Main</span>')
    
    @admin.display(description='Business Count')
    def business_count(self, obj):
        """Business count with children"""
        direct = obj.get_business_count()
        total = obj.get_all_business_count()
        
        if total > direct:
            return format_html(
                '<div style="text-align: center;">'
                '<span style="background: #4caf50; color: white; padding: 3px 8px; '
                'border-radius: 10px; font-weight: bold; font-size: 12px;">{}</span>'
                '<br><small style="color: #666;">({} with children)</small>'
                '</div>',
                direct, total
            )
        return format_html(
            '<span style="background: #4caf50; color: white; padding: 3px 8px; '
            'border-radius: 10px; font-weight: bold; font-size: 12px;">{}</span>',
            direct
        )
    
    @admin.display(description='Status')
    def status_badge(self, obj):
        """Active status with badge"""
        if obj.is_active:
            return mark_safe(
                '<span style="background: #c8e6c9; color: #2e7d32; '
                'padding: 5px 12px; border-radius: 12px; font-size: 11px; '
                'font-weight: bold; display: inline-block;">✓ Active</span>'
            )
        return mark_safe(
            '<span style="background: #ffcdd2; color: #c62828; '
            'padding: 5px 12px; border-radius: 12px; font-size: 11px; '
            'font-weight: bold; display: inline-block;">✕ Inactive</span>'
        )
    
    @admin.display(description='Image Preview')
    def image_preview(self, obj):
        """Image preview with enhancements"""
        if not obj or not obj.pk:
            return '-'
        
        if obj.image:
            filename = obj.image.name.split('/')[-1]
            return format_html(
                '<div style="text-align: center;">'
                '<img src="{}" style="max-height: 200px; max-width: 300px; '
                'border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); '
                'border: 2px solid #e0e0e0;" />'
                '<br><small style="color: #666; margin-top: 5px; display: block;">{}</small>'
                '</div>',
                obj.image.url,
                filename
            )
        return mark_safe(
            '<div style="text-align: center; padding: 40px; background: #f5f5f5; '
            'border-radius: 8px; border: 2px dashed #ddd;">'
            '<span style="font-size: 48px; color: #ccc;">📷</span><br>'
            '<small style="color: #999;">No image</small>'
            '</div>'
        )
    
    @admin.display(description='Business Statistics')
    def business_stats(self, obj):
        """Detailed business statistics"""
        if not obj or not obj.pk:
            return '-'
        
        direct = obj.get_business_count()
        total = obj.get_all_business_count()
        children = obj.children.count()
        
        return format_html(
            '<div style="background: #f5f5f5; padding: 15px; border-radius: 8px; '
            'line-height: 2;">'
            '<strong style="color: #1976d2;">📊 Statistics:</strong><br>'
            '<span style="color: #4caf50;">● Direct Businesses: <strong>{}</strong></span><br>'
            '<span style="color: #ff9800;">● Total Businesses: <strong>{}</strong></span><br>'
            '<span style="color: #9c27b0;">● Sub-categories: <strong>{}</strong></span>'
            '</div>',
            direct, total, children
        )
    
    # ========================================
    # ACTIONS
    # ========================================
    actions = [
        'activate_categories',
        'deactivate_categories',
        'reset_order',
    ]
    
    @admin.action(description='✓ Activate selected categories')
    def activate_categories(self, request, queryset):
        """Activate categories"""
        updated = queryset.update(is_active=True)
        self.message_user(
            request,
            f"✓ Successfully activated {updated} categories.",
            level='success'
        )
    
    @admin.action(description='✕ Deactivate selected categories')
    def deactivate_categories(self, request, queryset):
        """Deactivate categories"""
        updated = queryset.update(is_active=False)
        self.message_user(
            request,
            f"✕ Deactivated {updated} categories.",
            level='warning'
        )
    
    @admin.action(description='🔄 Reset order')
    def reset_order(self, request, queryset):
        """Auto-reset category order"""
        for index, category in enumerate(queryset.order_by('name_en'), start=1):
            category.order = index * 10
            category.save(update_fields=['order'])
        
        self.message_user(
            request,
            f"🔄 Reordered {queryset.count()} categories.",
            level='success'
        )
    
    # ========================================
    # QUERYSET OPTIMIZATION
    # ========================================
    def get_queryset(self, request):
        """Optimize queries"""
        qs = super().get_queryset(request)
        return qs.select_related('parent').prefetch_related('children')
    
    # ========================================
    # FORM CUSTOMIZATION
    # ========================================
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        """Customize parent category field"""
        if db_field.name == "parent":
            kwargs["queryset"] = Category.objects.filter(
                parent__isnull=True
            ).order_by('order', 'name_en')
        return super().formfield_for_foreignkey(db_field, request, **kwargs)
    
    # ========================================
    # SAVE OPTIMIZATION
    # ========================================
    def save_model(self, request, obj, form, change):
        """Save with enhancements"""
        if not change:  # New addition
            # Auto-assign order
            if not obj.order:
                max_order = Category.objects.aggregate(
                    max_order=models.Max('order')
                )['max_order'] or 0
                obj.order = max_order + 10
        
        super().save_model(request, obj, form, change)
