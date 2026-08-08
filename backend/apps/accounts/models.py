"""
Custom User Model
=================
نموذج المستخدم المخصص مع حقول إضافية
"""

from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.validators import RegexValidator
from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    """
    Custom User Model
    نموذج مستخدم مخصص مع حقول إضافية للهاتف والصورة
    """
    
    # Egyptian Phone Validator
    phone_regex = RegexValidator(
        regex=r'^01[0-2,5]{1}[0-9]{8}$',
        message="أدخل رقم هاتف مصري صحيح (مثال: 01234567890)"
    )
    
    # Additional Fields
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
    
    # Location
    city = models.CharField(
        _('City'),
        max_length=100,
        blank=True,
        help_text='المدينة'
    )
    
    # Email Verification
    email_verified = models.BooleanField(
        _('Email Verified'),
        default=False,
        help_text='تم التحقق من البريد الإلكتروني'
    )
    
    # Account Type
    is_business_owner = models.BooleanField(
        _('Business Owner'),
        default=False,
        help_text='صاحب محل'
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        _('Created At'),
        auto_now_add=True
    )
    
    updated_at = models.DateTimeField(
        _('Updated At'),
        auto_now=True
    )
    
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
        """الحصول على الاسم الكامل"""
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        return self.username
    
    @property
    def has_businesses(self):
        """التحقق من وجود محلات"""
        return self.businesses.filter(is_active=True).exists()
    
    @property
    def total_businesses(self):
        """عدد المحلات"""
        return self.businesses.filter(is_active=True).count()
    
    def get_profile_picture_url(self):
        """الحصول على رابط الصورة الشخصية"""
        if self.profile_picture:
            return self.profile_picture.url
        return '/static/images/default-avatar.png'  # Default avatar
