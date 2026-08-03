from django.conf import settings
from django.db import models
from django.utils import timezone


class DeviceRegistration(models.Model):
    PLATFORM_CHOICES = [('android', 'Android'), ('ios', 'iOS')]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='mobile_devices',
    )
    token = models.CharField(max_length=4096, unique=True)
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES)
    device_id = models.CharField(max_length=255, blank=True, db_index=True)
    app_version = models.CharField(max_length=20, blank=True)
    language = models.CharField(max_length=5, default='ar')
    is_active = models.BooleanField(default=True, db_index=True)
    last_seen_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-last_seen_at']
        indexes = [models.Index(fields=['user', 'is_active'])]


class Notification(models.Model):
    TYPE_CHOICES = [
        ('general', 'General'),
        ('deal', 'Deal'),
        ('business', 'Business'),
        ('review', 'Review'),
        ('system', 'System'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='mobile_notifications',
    )
    notification_type = models.CharField(
        max_length=20, choices=TYPE_CHOICES, default='general', db_index=True
    )
    title_ar = models.CharField(max_length=200)
    title_en = models.CharField(max_length=200, blank=True)
    body_ar = models.TextField()
    body_en = models.TextField(blank=True)
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False, db_index=True)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'is_read', '-created_at'])]

    def mark_as_read(self):
        if not self.is_read:
            self.is_read = True
            self.read_at = timezone.now()
            self.save(update_fields=['is_read', 'read_at'])
