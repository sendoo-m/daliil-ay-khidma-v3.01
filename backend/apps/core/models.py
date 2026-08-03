from django.db import models

class SiteSettings(models.Model):
    # ── عام ──────────────────────────────────
    site_name_ar        = models.CharField(max_length=100, default="دليل أي خدمة")
    site_name_en        = models.CharField(max_length=100, default="Daliil Ay Khidma")
    site_description_ar = models.TextField(blank=True)
    site_description_en = models.TextField(blank=True)
    logo                = models.ImageField(upload_to='site/', blank=True, null=True)
    favicon             = models.ImageField(upload_to='site/', blank=True, null=True)
    contact_email       = models.EmailField(blank=True)
    contact_phone       = models.CharField(max_length=20, blank=True)
    address             = models.CharField(max_length=255, blank=True)

    # ── سوشيال ميديا ─────────────────────────
    facebook            = models.URLField(blank=True)
    instagram           = models.URLField(blank=True)
    twitter             = models.URLField(blank=True)
    whatsapp            = models.CharField(max_length=20, blank=True)
    youtube             = models.URLField(blank=True)

    # ── إعدادات تقنية ─────────────────────────
    maintenance_mode         = models.BooleanField(default=False)
    allow_registration       = models.BooleanField(default=True)
    results_per_page         = models.PositiveIntegerField(default=12)
    allow_reviews            = models.BooleanField(default=True)
    require_review_approval  = models.BooleanField(default=True)

    # ── SEO ──────────────────────────────────
    meta_description    = models.TextField(blank=True)
    meta_keywords       = models.CharField(max_length=255, blank=True)
    google_analytics_id = models.CharField(max_length=50, blank=True)
    google_maps_key     = models.CharField(max_length=100, blank=True)

    # ── إعدادات تطبيق الموبايل ─────────────────
    android_min_version = models.CharField(max_length=20, default='1.0.0')
    android_latest_version = models.CharField(max_length=20, default='1.0.0')
    android_store_url = models.URLField(blank=True)
    ios_min_version = models.CharField(max_length=20, default='1.0.0')
    ios_latest_version = models.CharField(max_length=20, default='1.0.0')
    ios_store_url = models.URLField(blank=True)
    force_update = models.BooleanField(default=False)
    notifications_enabled = models.BooleanField(default=True)
    support_url = models.URLField(blank=True)

    class Meta:
        verbose_name = "إعدادات الموقع"

    def __str__(self):
        return "إعدادات الموقع"

    def save(self, *args, **kwargs):
        # دايمًا صف واحد بس في الـ DB
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def get_settings(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
