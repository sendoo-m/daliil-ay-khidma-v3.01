from django.contrib import admin
from .models import SiteSettings

@admin.register(SiteSettings)
class SiteSettingsAdmin(admin.ModelAdmin):
    fieldsets = (
        ("عام", {"fields": (
            "site_name_ar", "site_name_en",
            "site_description_ar", "site_description_en",
            "logo", "favicon",
            "contact_email", "contact_phone", "address"
        )}),
        ("سوشيال ميديا", {"fields": (
            "facebook", "instagram", "twitter", "whatsapp", "youtube"
        )}),
        ("إعدادات تقنية", {"fields": (
            "maintenance_mode", "allow_registration",
            "results_per_page", "allow_reviews", "require_review_approval"
        )}),
        ("SEO", {"fields": (
            "meta_description", "meta_keywords",
            "google_analytics_id", "google_maps_key"
        )}),
    )

    def has_add_permission(self, request):
        return not SiteSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False
