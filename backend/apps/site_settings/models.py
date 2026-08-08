"""
SiteSettings — Singleton model.
Only one row ever exists (pk=1). Use SiteSettings.get() everywhere.
"""

from django.db import models


class SiteSettings(models.Model):
    app_store_url = models.URLField(
        blank=True,
        verbose_name='رابط App Store (iOS)',
        help_text='رابط تحميل التطبيق من متجر Apple — اتركه فارغاً لإخفاء الزر',
    )
    google_play_url = models.URLField(
        blank=True,
        verbose_name='رابط Google Play (Android)',
        help_text='رابط تحميل التطبيق من Google Play — اتركه فارغاً لإخفاء الزر',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'إعدادات الموقع'
        verbose_name_plural = 'إعدادات الموقع'

    def __str__(self):
        return 'إعدادات الموقع'

    @classmethod
    def get(cls):
        """Always returns the single settings row, creating it if needed."""
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
