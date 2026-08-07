"""
Subscriptions Models
====================
نظام الاشتراكات الكامل مع خطط متعددة
"""

from datetime import timedelta

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils import timezone

from apps.directory.models import Business


class SubscriptionPlan(models.Model):
    """نموذج خطط الاشتراك."""

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

    name = models.CharField(
        max_length=20,
        choices=PLAN_CHOICES,
        unique=True,
        verbose_name='Plan Name',
    )
    display_name_en = models.CharField(
        max_length=50,
        verbose_name='Display Name (English)',
    )
    display_name_ar = models.CharField(
        max_length=50,
        verbose_name='الاسم المعروض',
    )
    description_en = models.TextField(blank=True, verbose_name='Description (English)')
    description_ar = models.TextField(blank=True, verbose_name='الوصف')

    price_monthly = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Monthly Price (EGP)',
        validators=[MinValueValidator(0)],
    )
    price_quarterly = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Quarterly Price (EGP)',
        validators=[MinValueValidator(0)],
    )
    price_semi_annual = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Semi-Annual Price (EGP)',
        validators=[MinValueValidator(0)],
    )
    price_annual = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Annual Price (EGP)',
        validators=[MinValueValidator(0)],
    )

    max_products = models.PositiveIntegerField(
        default=0,
        verbose_name='Max Products',
        help_text='0 = Unlimited',
    )
    max_businesses = models.PositiveIntegerField(
        default=1,
        verbose_name='Max Businesses',
        help_text='Maximum active businesses for the owner. 0 = Unlimited.',
    )
    max_images_per_product = models.PositiveIntegerField(
        default=1,
        verbose_name='Max Images per Product',
        help_text='Number of images allowed per product',
    )
    max_business_images = models.PositiveIntegerField(
        default=3,
        verbose_name='Max Business Gallery Images',
        help_text='Number of gallery images for business',
    )

    can_upload_images = models.BooleanField(default=False, verbose_name='Can Upload Images')
    can_show_prices = models.BooleanField(default=False, verbose_name='Can Show Prices')
    has_delivery_options = models.BooleanField(
        default=False,
        verbose_name='Delivery Options Available',
    )
    has_analytics = models.BooleanField(default=False, verbose_name='Analytics Dashboard')
    featured_in_search = models.BooleanField(
        default=False,
        verbose_name='Featured in Search Results',
        help_text='Higher priority in search results',
    )
    can_create_deals = models.BooleanField(
        default=False,
        verbose_name='Can Create Deals/Offers',
    )
    has_social_media_links = models.BooleanField(
        default=True,
        verbose_name='Social Media Links',
    )
    has_verified_badge = models.BooleanField(default=False, verbose_name='Verified Badge')

    color = models.CharField(
        max_length=7,
        default='#6c757d',
        verbose_name='Badge Color',
        help_text='Hex color code (e.g., #007bff)',
    )
    icon = models.CharField(
        max_length=50,
        default='fas fa-tag',
        verbose_name='Font Awesome Icon',
    )
    order = models.IntegerField(default=0, verbose_name='Display Order')
    is_active = models.BooleanField(default=True, verbose_name='Active')
    is_popular = models.BooleanField(
        default=False,
        verbose_name='Popular Plan',
        help_text='Display "Most Popular" badge',
    )

    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Created At')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated At')

    class Meta:
        verbose_name = 'Subscription Plan'
        verbose_name_plural = 'Subscription Plans'
        ordering = ['order', 'price_monthly']

    def __str__(self):
        return f'{self.display_name_en} / {self.display_name_ar}'

    @property
    def display_name(self):
        from django.utils.translation import get_language

        return self.display_name_ar if get_language() == 'ar' else self.display_name_en

    @property
    def description(self):
        from django.utils.translation import get_language

        return self.description_ar if get_language() == 'ar' else self.description_en

    def get_price(self, duration='monthly'):
        price_map = {
            'monthly': self.price_monthly,
            'quarterly': self.price_quarterly,
            'semi_annual': self.price_semi_annual,
            'annual': self.price_annual,
        }
        return price_map.get(duration, self.price_monthly)


class Subscription(models.Model):
    """نموذج الاشتراكات."""

    STATUS_CHOICES = [
        ('active', 'Active / نشط'),
        ('expired', 'Expired / منتهي'),
        ('cancelled', 'Cancelled / ملغي'),
        ('pending', 'Pending Payment / بانتظار الدفع'),
    ]

    business = models.OneToOneField(
        Business,
        on_delete=models.CASCADE,
        related_name='subscription',
        verbose_name='Business',
    )
    plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        related_name='subscriptions',
        related_query_name='subscription',
        verbose_name='Plan',
    )
    start_date = models.DateTimeField(verbose_name='Start Date')
    end_date = models.DateTimeField(verbose_name='End Date')
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name='Status',
        db_index=True,
    )
    auto_renew = models.BooleanField(default=False, verbose_name='Auto Renew')

    amount_paid = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Amount Paid (EGP)',
    )
    payment_method = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='Payment Method',
        help_text='e.g., Credit Card, PayPal, Bank Transfer',
    )
    transaction_id = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='Transaction ID',
    )
    admin_notes = models.TextField(
        blank=True,
        verbose_name='Admin Notes',
        help_text='Internal notes (not visible to user)',
    )

    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Created At')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated At')
    cancelled_at = models.DateTimeField(null=True, blank=True, verbose_name='Cancelled At')

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
        return f'{self.business.name_en} - {self.plan.display_name_en}'

    @property
    def is_active(self) -> bool:
        return self.status == 'active' and self.end_date > timezone.now()

    @property
    def days_remaining(self) -> int:
        if self.is_active:
            return max(0, (self.end_date - timezone.now()).days)
        return 0

    @property
    def is_expiring_soon(self) -> bool:
        return self.is_active and self.days_remaining <= 7

    def activate(self):
        self.status = 'active'
        self.save()

    def cancel(self):
        self.status = 'cancelled'
        self.cancelled_at = timezone.now()
        self.auto_renew = False
        self.save()

    def renew(self, duration_days=30):
        self.end_date = timezone.now() + timedelta(days=duration_days)
        self.status = 'active'
        self.save()

    def check_expiration(self):
        if self.status == 'active' and self.end_date <= timezone.now():
            self.status = 'expired'
            self.save()


class SubscriptionChangeRequest(models.Model):
    """طلب ترقية/تخفيض الخطة قبل تطبيق أي تغيير على بيانات صاحب النشاط."""

    STATUS_CHOICES = [
        ('pending', 'Pending Review / بانتظار المراجعة'),
        ('approved', 'Approved / تمت الموافقة'),
        ('rejected', 'Rejected / مرفوض'),
        ('cancelled', 'Cancelled / ملغي'),
        ('applied', 'Applied / تم التطبيق'),
    ]
    CHANGE_CHOICES = [
        ('upgrade', 'Upgrade / ترقية'),
        ('downgrade', 'Downgrade / تخفيض'),
        ('same', 'Plan Change / تغيير'),
    ]

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='subscription_change_requests',
    )
    subscription = models.ForeignKey(
        Subscription,
        on_delete=models.CASCADE,
        related_name='change_requests',
    )
    current_plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        related_name='change_requests_from',
    )
    target_plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        related_name='change_requests_to',
    )
    change_type = models.CharField(max_length=12, choices=CHANGE_CHOICES)
    billing_period = models.CharField(
        max_length=20,
        choices=SubscriptionPlan.DURATION_CHOICES,
        default='monthly',
    )
    status = models.CharField(
        max_length=12,
        choices=STATUS_CHOICES,
        default='pending',
        db_index=True,
    )

    keep_business_ids = models.JSONField(default=list, blank=True)
    keep_product_ids = models.JSONField(default=list, blank=True)
    preview = models.JSONField(default=dict, blank=True)
    applied_changes = models.JSONField(default=dict, blank=True)

    requested_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
    )
    payment_confirmed = models.BooleanField(default=False)
    payment_method = models.CharField(max_length=50, blank=True)
    transaction_id = models.CharField(max_length=100, blank=True)

    rejection_reason = models.TextField(blank=True)
    admin_notes = models.TextField(blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_subscription_change_requests',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    applied_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['owner', 'status', '-created_at']),
            models.Index(fields=['status', '-created_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['subscription'],
                condition=models.Q(status='pending'),
                name='one_pending_subscription_change_per_subscription',
            ),
        ]

    def __str__(self):
        return (
            f'{self.owner} | {self.current_plan.display_name_en} -> '
            f'{self.target_plan.display_name_en} ({self.status})'
        )


class MerchantOnboarding(models.Model):
    """Single source of truth for a user's first merchant journey."""

    STATUS_CHOICES = [
        ('draft', 'Draft / مسودة'),
        ('plan_selected', 'Plan Selected / تم اختيار الخطة'),
        ('business_created', 'Business Created / تم إنشاء النشاط'),
        ('payment_pending', 'Payment Pending / بانتظار الدفع'),
        ('admin_review', 'Admin Review / بانتظار مراجعة الإدارة'),
        ('subscription_active', 'Subscription Active / الاشتراك مفعل'),
        ('completed', 'Completed / مكتمل'),
    ]
    PAYMENT_STATUS_CHOICES = [
        ('not_required', 'Not Required / غير مطلوب'),
        ('pending', 'Pending / بانتظار الدفع'),
        ('submitted', 'Submitted / تم الإرسال'),
        ('confirmed', 'Confirmed / مؤكد'),
        ('rejected', 'Rejected / مرفوض'),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='merchant_onboarding',
    )
    selected_plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='merchant_onboardings',
    )
    billing_period = models.CharField(
        max_length=20,
        choices=SubscriptionPlan.DURATION_CHOICES,
        default='monthly',
    )
    business = models.ForeignKey(
        Business,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='onboarding_journeys',
    )
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default='draft',
        db_index=True,
    )
    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='not_required',
        db_index=True,
    )
    payment_method = models.CharField(max_length=50, blank=True)
    payment_reference = models.CharField(max_length=150, blank=True)
    payment_receipt = models.FileField(
        upload_to='subscriptions/onboarding/receipts/%Y/%m/',
        null=True,
        blank=True,
    )
    admin_notes = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Merchant Onboarding'
        verbose_name_plural = 'Merchant Onboardings'
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.user} - {self.status}'

    @property
    def selected_price(self):
        if not self.selected_plan:
            return 0
        return self.selected_plan.get_price(self.billing_period)

    @property
    def payment_required(self) -> bool:
        return bool(self.selected_plan and self.selected_price > 0)
