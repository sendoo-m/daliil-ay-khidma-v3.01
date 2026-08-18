"""
Custom User Model
=================
نموذج المستخدم المخصص مع حقول إضافية
"""

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.validators import RegexValidator
from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    """
    Custom User Model
    نموذج مستخدم مخصص مع حقول إضافية للهاتف والصورة
    """

    phone_regex = RegexValidator(
        regex=r'^01[0-2,5]{1}[0-9]{8}$',
        message="أدخل رقم هاتف مصري صحيح (مثال: 01234567890)"
    )

    phone = models.CharField(
        _('Phone Number'),
        max_length=15,
        unique=True,
        validators=[phone_regex],
        help_text='رقم الهاتف المصري (01234567890)'
    )

    profile_picture = models.ImageField(
        _('Profile Picture'),
        upload_to='profiles/%Y/%m/',
        blank=True,
        null=True,
        help_text='صورة شخصية (اختياري)'
    )

    bio = models.TextField(
        _('Bio'),
        blank=True,
        max_length=500,
        help_text='نبذة عنك (اختياري)'
    )

    city = models.CharField(
        _('City'),
        max_length=100,
        blank=True,
        help_text='المدينة'
    )

    email_verified = models.BooleanField(
        _('Email Verified'),
        default=False,
        help_text='تم التحقق من البريد الإلكتروني'
    )

    is_business_owner = models.BooleanField(
        _('Business Owner'),
        default=False,
        help_text='صاحب محل'
    )

    created_at = models.DateTimeField(_('Created At'), auto_now_add=True)
    updated_at = models.DateTimeField(_('Updated At'), auto_now=True)

    class Meta:
        verbose_name = _('User')
        verbose_name_plural = _('Users')
        ordering = ['-date_joined']
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['phone']),
            models.Index(fields=['is_business_owner']),
        ]

    def __str__(self):
        return self.username

    @property
    def full_name(self):
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        return self.username

    @property
    def has_businesses(self):
        return self.businesses.filter(is_active=True).exists()

    @property
    def total_businesses(self):
        return self.businesses.filter(is_active=True).count()

    def get_profile_picture_url(self):
        if self.profile_picture:
            return self.profile_picture.url
        return '/static/images/default-avatar.png'


class AccountDeletionRequest(models.Model):
    """Auditable request to delete a user's account without unsafe cascades."""

    class Status(models.TextChoices):
        PENDING = 'pending', _('Pending')
        COMPLETED = 'completed', _('Completed')
        CANCELLED = 'cancelled', _('Cancelled')

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='account_deletion_request',
    )
    user_id_snapshot = models.PositiveBigIntegerField()
    email_snapshot = models.EmailField(blank=True)
    username_snapshot = models.CharField(max_length=150)
    reason = models.TextField(blank=True, max_length=1000)
    source = models.CharField(max_length=20, default='mobile')
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    requested_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-requested_at']

    def __str__(self):
        return f'{self.username_snapshot} — {self.status}'
