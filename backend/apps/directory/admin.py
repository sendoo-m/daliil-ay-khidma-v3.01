"""
Directory Admin Configuration
==============================
إعدادات Django Admin لجميع نماذج Directory
"""


from django.contrib import admin
from django.contrib.admin import widgets
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from django.utils.translation import gettext_lazy as _
from django.db.models import Count, Q
from django.urls import reverse
from django import forms


from .models import (
    Governorate,
    City,
    District,
    Business,
    BusinessImage,
    BusinessWorkingHours,
    Favorite
)


# ========================================
# Location Widget - خريطة تفاعلية
# ========================================
class LocationWidget(widgets.AdminTextInputWidget):
    """Widget with interactive map for selecting location"""
    
    class Media:
        css = {
            'all': ('https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',)
        }
        js = ('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',)
    
    def __init__(self, attrs=None):
        super().__init__(attrs)
        self.attrs.update({'style': 'width: 200px;'})
    
    def render(self, name, value, attrs=None, renderer=None):
        output = super().render(name, value, attrs, renderer)
        
        # Get lat/lng from value
        lat = float(value) if value else 30.0444
        lng = 31.2357  # Default longitude
        
        # Create unique ID for this field
        field_id = attrs.get('id', f'id_{name}') if attrs else f'id_{name}'
        map_id = f'map_{name}'
        
        map_html = f'''
        <div id="{map_id}" style="height: 400px; width: 100%; margin: 10px 0; border: 2px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);"></div>
        <p style="color: #666; font-size: 12px; margin-top: 5px;">
            <i class="fas fa-info-circle"></i> اسحب الـ Marker لتحديد الموقع بدقة
        </p>
        <script>
        (function() {{
            setTimeout(function() {{
                if (typeof L === 'undefined') {{
                    console.error('Leaflet not loaded');
                    return;
                }}
                
                // Get current values
                var latInput = document.getElementById('id_latitude');
                var lngInput = document.getElementById('id_longitude');
                
                var lat = parseFloat(latInput.value) || 30.0444;
                var lng = parseFloat(lngInput.value) || 31.2357;
                
                // Initialize map
                var map = L.map('{map_id}').setView([lat, lng], 13);
                
                // Add tile layer
                L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 19
                }}).addTo(map);
                
                // Add draggable marker
                var marker = L.marker([lat, lng], {{
                    draggable: true,
                    title: 'اسحبني لتحديد الموقع'
                }}).addTo(map);
                
                // Add popup
                marker.bindPopup('<b>موقع المحل</b><br>اسحب الـ Marker لتحديد الموقع').openPopup();
                
                // Update inputs on drag
                marker.on('dragend', function(e) {{
                    var pos = marker.getLatLng();
                    latInput.value = pos.lat.toFixed(6);
                    lngInput.value = pos.lng.toFixed(6);
                    marker.bindPopup('<b>الموقع الجديد</b><br>Lat: ' + pos.lat.toFixed(6) + '<br>Lng: ' + pos.lng.toFixed(6)).openPopup();
                }});
                
                // Update marker when inputs change
                function updateMarker() {{
                    var newLat = parseFloat(latInput.value);
                    var newLng = parseFloat(lngInput.value);
                    if (!isNaN(newLat) && !isNaN(newLng)) {{
                        marker.setLatLng([newLat, newLng]);
                        map.setView([newLat, newLng], 13);
                    }}
                }}
                
                latInput.addEventListener('change', updateMarker);
                lngInput.addEventListener('change', updateMarker);
                
                // Add search control (optional)
                var searchBtn = L.control({{position: 'topright'}});
                searchBtn.onAdd = function(map) {{
                    var div = L.DomUtil.create('div', 'leaflet-bar leaflet-control');
                    div.innerHTML = '<a href="#" style="background: white; padding: 5px 10px; display: block; text-decoration: none; color: #333;" title="حدد موقعي">📍</a>';
                    div.onclick = function() {{
                        if (navigator.geolocation) {{
                            navigator.geolocation.getCurrentPosition(function(position) {{
                                var pos = {{
                                    lat: position.coords.latitude,
                                    lng: position.coords.longitude
                                }};
                                map.setView([pos.lat, pos.lng], 15);
                                marker.setLatLng([pos.lat, pos.lng]);
                                latInput.value = pos.lat.toFixed(6);
                                lngInput.value = pos.lng.toFixed(6);
                            }});
                        }}
                        return false;
                    }};
                    return div;
                }};
                searchBtn.addTo(map);
                
            }}, 500);
        }})();
        </script>
        '''
        
        return mark_safe(output + map_html)


# ========================================
# Business Form with Location Widget
# ========================================
class BusinessAdminForm(forms.ModelForm):
    """Form with location widget"""
    
    class Meta:
        model = Business
        fields = '__all__'
        widgets = {
            'latitude': LocationWidget(),
        }
    
    class Media:
        css = {
            'all': ('https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',)
        }
        js = ('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',)


# ========================================
# Governorate Admin
# ========================================
@admin.register(Governorate)
class GovernorateAdmin(admin.ModelAdmin):
    list_display = [
        'icon_display',
        'name_display',
        'order',
        'is_active',
        'cities_count',
        'businesses_count',
        'created_at'
    ]
    list_filter = ['is_active', 'created_at']
    search_fields = ['name_en', 'name_ar']
    prepopulated_fields = {'slug': ('name_en',)}
    list_editable = ['order', 'is_active']
    ordering = ['order', 'name_en']
    list_per_page = 30
    
    fieldsets = (
        (_('Basic Information'), {
            'fields': (
                ('name_en', 'name_ar'),
                'slug'
            )
        }),
        (_('Settings'), {
            'fields': (('is_active', 'order'),)
        }),
        (_('Timestamps'), {
            'fields': (('created_at', 'updated_at'),),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['created_at', 'updated_at']
    
    @admin.display(description='Icon', ordering='name_en')
    def icon_display(self, obj):
        """Display icon"""
        return '🗺️'
    
    @admin.display(description='Name')
    def name_display(self, obj):
        """Display name in both languages"""
        return format_html(
            '<div><strong>{}</strong><br><small style="color: #666;">{}</small></div>',
            obj.name_en,
            obj.name_ar
        )
    
    @admin.display(description='Cities')
    def cities_count(self, obj):
        """Display cities count"""
        count = obj.cities.filter(is_active=True).count()
        return format_html('<span style="background: #2196f3; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold;">{}</span>', count)
    
    @admin.display(description='Businesses')
    def businesses_count(self, obj):
        """Display total businesses count"""
        count = Business.objects.filter(
            district__city__governorate=obj,
            is_active=True
        ).count()
        return format_html('<span style="background: #ff9800; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold;">{}</span>', count)


# ========================================
# City Admin
# ========================================
@admin.register(City)
class CityAdmin(admin.ModelAdmin):
    list_display = [
        'name_display',
        'governorate_link',
        'order',
        'is_active',
        'districts_count',
        'businesses_count'
    ]
    list_filter = ['governorate', 'is_active', 'created_at']
    search_fields = ['name_en', 'name_ar', 'governorate__name_en', 'governorate__name_ar']
    prepopulated_fields = {'slug': ('name_en',)}
    list_editable = ['order', 'is_active']
    list_per_page = 50
    autocomplete_fields = ['governorate']
    
    fieldsets = (
        (_('Basic Information'), {
            'fields': (
                'governorate',
                ('name_en', 'name_ar'),
                'slug'
            )
        }),
        (_('Settings'), {
            'fields': (('is_active', 'order'),)
        }),
        (_('Timestamps'), {
            'fields': (('created_at', 'updated_at'),),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['created_at', 'updated_at']
    
    @admin.display(description='Name', ordering='name_en')
    def name_display(self, obj):
        """Display name"""
        return format_html(
            '<div><strong>{}</strong><br><small style="color: #666;">{}</small></div>',
            obj.name_en,
            obj.name_ar
        )
    
    @admin.display(description='Governorate')
    def governorate_link(self, obj):
        """Link to governorate"""
        url = reverse('admin:directory_governorate_change', args=[obj.governorate.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.governorate.name_en)
    
    @admin.display(description='Districts')
    def districts_count(self, obj):
        """Display districts count"""
        count = obj.districts.filter(is_active=True).count()
        return format_html('<span style="background: #2196f3; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold;">{}</span>', count)
    
    @admin.display(description='Businesses')
    def businesses_count(self, obj):
        """Display businesses count"""
        count = Business.objects.filter(district__city=obj, is_active=True).count()
        return format_html('<span style="background: #ff9800; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold;">{}</span>', count)


# ========================================
# District Admin
# ========================================
@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = [
        'name_display',
        'city_link',
        'governorate_name',
        'order',
        'is_active',
        'businesses_count'
    ]
    list_filter = ['city__governorate', 'city', 'is_active', 'created_at']
    search_fields = ['name_en', 'name_ar', 'city__name_en', 'city__name_ar']
    prepopulated_fields = {'slug': ('name_en',)}
    list_editable = ['order', 'is_active']
    list_per_page = 50
    autocomplete_fields = ['city']
    
    fieldsets = (
        (_('Basic Information'), {
            'fields': (
                'city',
                ('name_en', 'name_ar'),
                'slug'
            )
        }),
        (_('Settings'), {
            'fields': (('is_active', 'order'),)
        }),
        (_('Timestamps'), {
            'fields': (('created_at', 'updated_at'),),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['created_at', 'updated_at']
    
    @admin.display(description='Name', ordering='name_en')
    def name_display(self, obj):
        """Display name"""
        return format_html(
            '<div><strong>{}</strong><br><small style="color: #666;">{}</small></div>',
            obj.name_en,
            obj.name_ar
        )
    
    @admin.display(description='City')
    def city_link(self, obj):
        """Link to city"""
        url = reverse('admin:directory_city_change', args=[obj.city.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.city.name_en)
    
    @admin.display(description='Governorate', ordering='city__governorate__name_en')
    def governorate_name(self, obj):
        """Display governorate name"""
        return obj.city.governorate.name_en
    
    @admin.display(description='Businesses')
    def businesses_count(self, obj):
        """Display businesses count"""
        count = obj.businesses.filter(is_active=True).count()
        return format_html('<span style="background: #ff9800; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold;">{}</span>', count)


# ========================================
# Business Inlines
# ========================================
class BusinessImageInline(admin.TabularInline):
    model = BusinessImage
    extra = 1
    fields = ['image', 'caption_en', 'caption_ar', 'order', 'is_active']
    classes = ['collapse']


class BusinessWorkingHoursInline(admin.TabularInline):
    model = BusinessWorkingHours
    extra = 0
    fields = ['day', 'opening_time', 'closing_time', 'is_closed']
    classes = ['collapse']


# ========================================
# Business Admin - مع خريطة تفاعلية
# ========================================
@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    form = BusinessAdminForm  # ← استخدام Form مع Widget الخريطة
    
    list_display = [
        'name_display',
        'business_type_badge',
        'category_link',
        'location_display',
        'owner_link',
        'status_badges',
        'stats_display',
        'created_at'
    ]
    list_filter = [
        'business_type',
        'is_active',
        'is_verified',
        'is_featured',
        'is_promoted',
        'district__city__governorate',
        'created_at'
    ]
    search_fields = [
        'name_en',
        'name_ar',
        'owner__username',
        'owner__email',
        'phone',
        'email'
    ]
    prepopulated_fields = {'slug': ('name_en',)}
    autocomplete_fields = ['owner', 'district', 'category']
    inlines = [BusinessImageInline, BusinessWorkingHoursInline]
    list_per_page = 25
    date_hierarchy = 'created_at'
    
    readonly_fields = [
        'view_count',
        'click_count',
        'created_at',
        'updated_at',
        'verified_at',
        'logo_preview',
        'cover_preview',
        'map_preview'
    ]
    
    fieldsets = (
        (_('Basic Information'), {
            'fields': (
                'owner',
                'business_type',
                ('name_en', 'name_ar'),
                'slug',
                ('category', 'district')
            )
        }),
        (_('Images'), {
            'fields': (
                ('logo', 'logo_preview'),
                ('cover_image', 'cover_preview')
            )
        }),
        (_('Contact Information'), {
            'fields': (
                ('phone', 'whatsapp'),
                ('email', 'website')
            )
        }),
        (_('Social Media'), {
            'fields': (
                ('facebook', 'instagram'),
                ('twitter', 'tiktok')
            ),
            'classes': ('collapse',)
        }),
        (_('Location - حدد الموقع من الخريطة'), {
            'fields': (
                'address_en',
                'address_ar',
                'location_url',
                ('latitude', 'longitude'),
                'map_preview'
            ),
            'description': '⬇️ اسحب الـ Marker على الخريطة لتحديد الموقع بدقة'
        }),
        (_('Description & Working Hours'), {
            'fields': (
                'description_en',
                'description_ar',
                'working_hours_en',
                'working_hours_ar'
            )
        }),
        (_('Status'), {
            'fields': (
                ('is_active', 'is_verified'),
                ('is_featured', 'is_promoted')
            )
        }),
        (_('Statistics'), {
            'fields': (
                ('view_count', 'click_count'),
                ('created_at', 'updated_at'),
                'verified_at'
            ),
            'classes': ('collapse',)
        }),
    )
    
    @admin.display(description='Name', ordering='name_en')
    def name_display(self, obj):
        """Display business name"""
        return format_html(
            '<div style="line-height: 1.6;"><strong style="color: #1976d2;">{}</strong><br>'
            '<small style="color: #666;">{}</small></div>',
            obj.name_en,
            obj.name_ar
        )
    
    @admin.display(description='Type')
    def business_type_badge(self, obj):
        """Display business type with icon"""
        colors = {
            'shop': '#3498db',
            'craft': '#e67e22',
            'public': '#2ecc71',
        }
        icons = {
            'shop': '🏪',
            'craft': '🔧',
            'public': '🏛️',
        }
        color = colors.get(obj.business_type, '#95a5a6')
        icon = icons.get(obj.business_type, '📍')
        
        return format_html(
            '<span style="background: {}; color: white; padding: 4px 10px; '
            'border-radius: 12px; font-size: 11px; font-weight: bold; display: inline-block;">{} {}</span>',
            color,
            icon,
            obj.get_business_type_display().split('/')[0].strip()
        )
    
    @admin.display(description='Category')
    def category_link(self, obj):
        """Link to category"""
        url = reverse('admin:categories_category_change', args=[obj.category.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.category.name_en)
    
    @admin.display(description='Location')
    def location_display(self, obj):
        """Display location"""
        has_coords = '📍' if obj.latitude and obj.longitude else '❌'
        return format_html(
            '<small>{} {}<br>{}</small>',
            has_coords,
            obj.district.name_en,
            obj.district.city.governorate.name_en
        )
    
    @admin.display(description='Owner')
    def owner_link(self, obj):
        """Link to owner"""
        url = reverse('admin:accounts_user_change', args=[obj.owner.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.owner.username)
    
    @admin.display(description='Status')
    def status_badges(self, obj):
        """Display status badges"""
        badges = []
        if obj.is_active:
            badges.append('<span style="background: #c8e6c9; color: #2e7d32; padding: 3px 8px; border-radius: 10px; font-size: 10px; font-weight: bold;">✓ Active</span>')
        if obj.is_verified:
            badges.append('<span style="background: #bbdefb; color: #1565c0; padding: 3px 8px; border-radius: 10px; font-size: 10px; font-weight: bold;">✓ Verified</span>')
        if obj.is_featured:
            badges.append('<span style="background: #fff3e0; color: #e65100; padding: 3px 8px; border-radius: 10px; font-size: 10px; font-weight: bold;">⭐ Featured</span>')
        if obj.is_promoted:
            badges.append('<span style="background: #f3e5f5; color: #6a1b9a; padding: 3px 8px; border-radius: 10px; font-size: 10px; font-weight: bold;">🚀 Promoted</span>')
        
        return mark_safe('<br>'.join(badges)) if badges else '-'
    
    @admin.display(description='Stats')
    def stats_display(self, obj):
        """Display statistics"""
        return format_html(
            '<div style="line-height: 1.8;">'
            '<small>👁️ {}</small><br>'
            '<small>👆 {}</small>'
            '</div>',
            obj.view_count,
            obj.click_count
        )
    
    @admin.display(description='Logo Preview')
    def logo_preview(self, obj):
        """Preview logo"""
        if obj.logo:
            return format_html('<img src="{}" style="max-height: 100px; border-radius: 8px;">', obj.logo.url)
        return '-'
    
    @admin.display(description='Cover Preview')
    def cover_preview(self, obj):
        """Preview cover"""
        if obj.cover_image:
            return format_html('<img src="{}" style="max-height: 100px; border-radius: 8px;">', obj.cover_image.url)
        return '-'
    
    @admin.display(description='Map Preview')
    def map_preview(self, obj):
        """Display current location on map"""
        if obj.latitude and obj.longitude:
            return format_html(
                '<div style="background: #e3f2fd; padding: 10px; border-radius: 8px; margin-top: 10px;">'
                '<strong>📍 الموقع الحالي:</strong><br>'
                'Latitude: {}<br>'
                'Longitude: {}<br>'
                '<a href="https://www.google.com/maps?q={},{}" target="_blank" style="color: #1976d2; text-decoration: underline;">عرض على Google Maps</a>'
                '</div>',
                obj.latitude,
                obj.longitude,
                obj.latitude,
                obj.longitude
            )
        return format_html('<p style="color: #f44336;">❌ لم يتم تحديد الموقع بعد</p>')
    
    actions = [
        'verify_businesses',
        'unverify_businesses',
        'feature_businesses',
        'unfeature_businesses',
        'activate_businesses',
        'deactivate_businesses'
    ]
    
    @admin.action(description='✓ Verify selected businesses')
    def verify_businesses(self, request, queryset):
        updated = queryset.update(is_verified=True)
        self.message_user(request, f"✓ {updated} businesses verified.", level='success')
    
    @admin.action(description='✕ Unverify selected businesses')
    def unverify_businesses(self, request, queryset):
        updated = queryset.update(is_verified=False)
        self.message_user(request, f"✕ {updated} businesses unverified.", level='warning')
    
    @admin.action(description='⭐ Feature selected businesses')
    def feature_businesses(self, request, queryset):
        updated = queryset.update(is_featured=True)
        self.message_user(request, f"⭐ {updated} businesses featured.", level='success')
    
    @admin.action(description='Remove feature from selected')
    def unfeature_businesses(self, request, queryset):
        updated = queryset.update(is_featured=False)
        self.message_user(request, f"{updated} businesses unfeatured.", level='warning')
    
    @admin.action(description='✓ Activate selected businesses')
    def activate_businesses(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f"✓ {updated} businesses activated.", level='success')
    
    @admin.action(description='✕ Deactivate selected businesses')
    def deactivate_businesses(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f"✕ {updated} businesses deactivated.", level='warning')


# ========================================
# Business Image Admin
# ========================================
@admin.register(BusinessImage)
class BusinessImageAdmin(admin.ModelAdmin):
    list_display = ['image_preview', 'business_link', 'caption_display', 'order', 'is_active', 'uploaded_at']
    list_filter = ['is_active', 'uploaded_at']
    search_fields = ['business__name_en', 'caption_en', 'caption_ar']
    list_editable = ['order', 'is_active']
    autocomplete_fields = ['business']
    list_per_page = 30
    
    @admin.display(description='Preview')
    def image_preview(self, obj):
        """Image preview"""
        if obj.image:
            return format_html('<img src="{}" style="max-height: 60px; border-radius: 4px;">', obj.image.url)
        return '-'
    
    @admin.display(description='Business')
    def business_link(self, obj):
        """Link to business"""
        url = reverse('admin:directory_business_change', args=[obj.business.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.business.name_en)
    
    @admin.display(description='Caption')
    def caption_display(self, obj):
        """Display caption"""
        return obj.caption_en or obj.caption_ar or '-'


# ========================================
# Business Working Hours Admin
# ========================================
@admin.register(BusinessWorkingHours)
class BusinessWorkingHoursAdmin(admin.ModelAdmin):
    list_display = ['business_link', 'day_display', 'time_display', 'status']
    list_filter = ['day', 'is_closed']
    search_fields = ['business__name_en', 'business__name_ar']
    autocomplete_fields = ['business']
    
    @admin.display(description='Business')
    def business_link(self, obj):
        """Link to business"""
        url = reverse('admin:directory_business_change', args=[obj.business.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.business.name_en)
    
    @admin.display(description='Day')
    def day_display(self, obj):
        """Display day"""
        return obj.get_day_display()
    
    @admin.display(description='Hours')
    def time_display(self, obj):
        """Display time"""
        if obj.is_closed:
            return mark_safe('<span style="color: red;">Closed</span>')
        return f"{obj.opening_time} - {obj.closing_time}"
    
    @admin.display(description='Status')
    def status(self, obj):
        """Display status"""
        if obj.is_closed:
            return mark_safe('<span style="background: #ffcdd2; color: #c62828; padding: 3px 8px; border-radius: 10px; font-size: 10px;">Closed</span>')
        return mark_safe('<span style="background: #c8e6c9; color: #2e7d32; padding: 3px 8px; border-radius: 10px; font-size: 10px;">Open</span>')


# ========================================
# Favorite Admin
# ========================================
@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ['user_link', 'business_link', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'user__email', 'business__name_en', 'business__name_ar']
    autocomplete_fields = ['user', 'business']
    date_hierarchy = 'created_at'
    list_per_page = 50
    
    @admin.display(description='User')
    def user_link(self, obj):
        """Link to user"""
        url = reverse('admin:accounts_user_change', args=[obj.user.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.user.username)
    
    @admin.display(description='Business')
    def business_link(self, obj):
        """Link to business"""
        url = reverse('admin:directory_business_change', args=[obj.business.pk])
        return format_html('<a href="{}" style="color: #1976d2;">{}</a>', url, obj.business.name_en)
