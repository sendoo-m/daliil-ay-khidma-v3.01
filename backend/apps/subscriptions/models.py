"""
Subscriptions Models
====================
نظام الاشتراكات الكامل مع خطط متعددة
"""

from django.db import models
from django.utils import timezone
from django.core.validators import MinValueValidator
from datetime import timedelta

from apps.directory.models import Business


class SubscriptionPlan(models.Model):
    """نموذج خطط الاشتراك"""
    
    PLAN_CHOICES = [
        ('free', 'Free / مجاني'),
        ('basic', 'Basic / أساسي'),
        ('premium', 'Premium / مميز'),
        ('vip', 'VIP / نخبة'),
    ]
    
    DURATION_CHOICES = [
        ('monthly', 'Monthly / شهري'),
        ('quarterly', 'Quarterly / ربع سنوي'),
        ('semi_annual', 'Semi-Annual / نصف سنوي'),
        ('annual', 'Annual / سنوي'),
    ]
    
    # ========================================
    # Basic Info
    # ========================================
    name = models.CharField(
        max_length=20,
        choices=PLAN_CHOICES,
        unique=True,
        verbose_name='Plan Name'
    )
    
    display_name_en = models.CharField(
        max_length=50,
        verbose_name='Display Name (English)'
    )
    
    display_name_ar = models.CharField(
        max_length=50,
        verbose_name='الاسم المعروض'
    )
    
    description_en = models.TextField(
        blank=True,
        verbose_name='Description (English)'
    )
    
    description_ar = models.TextField(
        blank=True,
        verbose_name='الوصف'
    )
    
    # ========================================
    # Pricing
    # ========================================
    price_monthly = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Monthly Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    price_quarterly = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Quarterly Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    price_semi_annual = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Semi-Annual Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    price_annual = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Annual Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    # ========================================
    # Features Limits
    # ========================================
    max_products = models.PositiveIntegerField(
        default=0,
        verbose_name='Max Products',
        help_text='0 = Unlimited'
    )
    
    max_images_per_product = models.PositiveIntegerField(
        default=1,
        verbose_name='Max Images per Product',
        help_text='Number of images allowed per product'
    )
    
    max_business_images = models.PositiveIntegerField(
        default=3,
        verbose_name='Max Business Gallery Images',
        help_text='Number of gallery images for business'
    )
    
    # ========================================
    # Features Flags
    # ========================================
    can_upload_images = models.BooleanField(
        default=False,
        verbose_name='Can Upload Images'
    )
    
    can_show_prices = models.BooleanField(
        default=False,
        verbose_name='Can Show Prices'
    )
    
    has_delivery_options = models.BooleanField(
        default=False,
        verbose_name='Delivery Options Available'
    )
    
    has_analytics = models.BooleanField(
        default=False,
        verbose_name='Analytics Dashboard'
    )
    
    featured_in_search = models.BooleanField(
        default=False,
        verbose_name='Featured in Search Results',
        help_text='Higher priority in search results'
    )
    
    can_create_deals = models.BooleanField(
        default=False,
        verbose_name='Can Create Deals/Offers'
    )
    
    has_social_media_links = models.BooleanField(
        default=True,
        verbose_name='Social Media Links'
    )
    
    has_verified_badge = models.BooleanField(
        default=False,
        verbose_name='Verified Badge'
    )
    
    # ========================================
    # Display Settings
    # ========================================
    color = models.CharField(
        max_length=7,
        default='#6c757d',
        verbose_name='Badge Color',
        help_text='Hex color code (e.g., #007bff)'
    )
    
    icon = models.CharField(
        max_length=50,
        default='fas fa-tag',
        verbose_name='Font Awesome Icon'
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name='Display Order'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='Active'
    )
    
    is_popular = models.BooleanField(
        default=False,
        verbose_name='Popular Plan',
        help_text='Display "Most Popular" badge'
    )
    
    # ========================================
    # Timestamps
    # ========================================
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Created At'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Updated At'
    )
    
    class Meta:
        verbose_name = 'Subscription Plan'
        verbose_name_plural = 'Subscription Plans'
        ordering = ['order', 'price_monthly']
    
    def __str__(self):
        return f"{self.display_name_en} / {self.display_name_ar}"
    
    @property
    def display_name(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.display_name_ar if lang == 'ar' else self.display_name_en
    
    @property
    def description(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.description_ar if lang == 'ar' else self.description_en
    
    def get_price(self, duration='monthly'):
        """الحصول على السعر حسب المدة"""
        price_map = {
            'monthly': self.price_monthly,
            'quarterly': self.price_quarterly,
            'semi_annual': self.price_semi_annual,
            'annual': self.price_annual,
        }
        return price_map.get(duration, self.price_monthly)


class Subscription(models.Model):
    """نموذج الاشتراكات"""
    
    STATUS_CHOICES = [
        ('active', 'Active / نشط'),
        ('expired', 'Expired / منتهي'),
        ('cancelled', 'Cancelled / ملغي'),
        ('pending', 'Pending Payment / بانتظار الدفع'),
    ]
    
    # ========================================
    # Relations
    # ========================================
    business = models.OneToOneField(
        Business,
        on_delete=models.CASCADE,
        related_name='subscription',
        verbose_name='Business'
    )
    
    plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        related_name='subscriptions',
        related_query_name='subscription',
        verbose_name='Plan'
    )
    
    # ========================================
    # Subscription Details
    # ========================================
    start_date = models.DateTimeField(
        verbose_name='Start Date'
    )
    
    end_date = models.DateTimeField(
        verbose_name='End Date'
    )
    
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name='Status',
        db_index=True
    )
    
    auto_renew = models.BooleanField(
        default=False,
        verbose_name='Auto Renew'
    )
    
    # ========================================
    # Payment Info
    # ========================================
    amount_paid = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Amount Paid (EGP)'
    )
    
    payment_method = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='Payment Method',
        help_text='e.g., Credit Card, PayPal, Bank Transfer'
    )
    
    transaction_id = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='Transaction ID'
    )
    
    # ========================================
    # Notes
    # ========================================
    admin_notes = models.TextField(
        blank=True,
        verbose_name='Admin Notes',
        help_text='Internal notes (not visible to user)'
    )
    
    # ========================================
    # Timestamps
    # ========================================
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Created At'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Updated At'
    )
    
    cancelled_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Cancelled At'
    )
    
    class Meta:
        verbose_name = 'Subscription'
        verbose_name_plural = 'Subscriptions'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['business', 'status']),
            models.Index(fields=['status', 'end_date']),
            models.Index(fields=['-created_at']),
        ]
    
    def __str__(self):
        return f"{self.business.name_en} - {self.plan.display_name_en}"
    
    # ========================================
    # Properties
    # ========================================
    @property
    def is_active(self) -> bool:
        """التحقق من نشاط الاشتراك"""
        return self.status == 'active' and self.end_date > timezone.now()
    
    @property
    def days_remaining(self) -> int:
        """عدد الأيام المتبقية"""
        if self.is_active:
            delta = self.end_date - timezone.now()
            return max(0, delta.days)
        return 0
    
    @property
    def is_expiring_soon(self) -> bool:
        """هل سينتهي قريباً؟ (7 أيام)"""
        return self.is_active and self.days_remaining <= 7
    
    # ========================================
    # Methods
    # ========================================
    def activate(self):
        """تفعيل الاشتراك"""
        self.status = 'active'
        self.save()
    
    def cancel(self):
        """إلغاء الاشتراك"""
        self.status = 'cancelled'
        self.cancelled_at = timezone.now()
        self.auto_renew = False
        self.save()
    
    def renew(self, duration_days=30):
        """تجديد الاشتراك"""
        self.end_date = timezone.now() + timedelta(days=duration_days)
        self.status = 'active'
        self.save()
    
    def check_expiration(self):
        """فحص الانتهاء وتحديث الحالة"""
        if self.status == 'active' and self.end_date <= timezone.now():
            self.status = 'expired'
            self.save()
