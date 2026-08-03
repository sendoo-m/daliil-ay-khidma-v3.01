"""
Deals & Offers Models
=====================
نظام العروض والخصومات الخاصة
"""

from django.db import models
from django.utils.text import slugify
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from django.urls import reverse
from django.conf import settings
import re

from apps.directory.models import Business


class Deal(models.Model):
    """نموذج العروض والخصومات"""
    
    DEAL_TYPE_CHOICES = [
        ('percentage', 'Percentage Discount / خصم بالنسبة'),
        ('fixed', 'Fixed Amount / قيمة ثابتة'),
        ('bogo', 'Buy One Get One / اشتري واحد واحصل على آخر'),
        ('bundle', 'Bundle Deal / عرض مجمع'),
        ('special', 'Special Offer / عرض خاص'),
    ]
    
    # ========================================
    # Relations
    # ========================================
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='deals',
        related_query_name='deal',
        verbose_name='Business'
    )
    
    # ========================================
    # Basic Info (Bilingual)
    # ========================================
    title_en = models.CharField(
        max_length=200,
        verbose_name='Title (English)',
        db_index=True,
        help_text='Example: 50% Off on All Items'
    )
    
    title_ar = models.CharField(
        max_length=200,
        verbose_name='العنوان',
        db_index=True,
        help_text='مثال: خصم 50% على جميع المنتجات'
    )
    
    slug = models.SlugField(
        max_length=250,
        unique=True,
        blank=True,
        verbose_name='URL Slug'
    )
    
    description_en = models.TextField(
        verbose_name='Description (English)',
        help_text='Full deal description in English'
    )
    
    description_ar = models.TextField(
        verbose_name='الوصف',
        help_text='وصف كامل للعرض بالعربية'
    )
    
    # ========================================
    # Deal Details
    # ========================================
    deal_type = models.CharField(
        max_length=15,
        choices=DEAL_TYPE_CHOICES,
        default='percentage',
        verbose_name='Deal Type',
        db_index=True
    )
    
    discount_percentage = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='Discount Percentage',
        help_text='For percentage discounts (e.g., 25 for 25%)',
        validators=[MinValueValidator(1), MaxValueValidator(100)]
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Discount Amount (EGP)',
        help_text='For fixed amount discounts',
        validators=[MinValueValidator(0)]
    )
    
    original_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Original Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    final_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Final Price (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    # ========================================
    # Validity Period
    # ========================================
    start_date = models.DateTimeField(
        verbose_name='Start Date',
        help_text='When the deal becomes active'
    )
    
    end_date = models.DateTimeField(
        verbose_name='End Date',
        help_text='When the deal expires'
    )
    
    # ========================================
    # Terms & Conditions
    # ========================================
    terms_en = models.TextField(
        blank=True,
        verbose_name='Terms & Conditions (English)',
        help_text='Deal terms and conditions in English'
    )
    
    terms_ar = models.TextField(
        blank=True,
        verbose_name='الشروط والأحكام',
        help_text='شروط وأحكام العرض بالعربية'
    )
    
    # ========================================
    # Image
    # ========================================
    image = models.ImageField(
        upload_to='deals/%Y/%m/',
        blank=True,
        null=True,
        verbose_name='Deal Image',
        help_text='Banner image for the deal (Recommended: 1200x600 px)'
    )
    
    # ========================================
    # Limits
    # ========================================
    max_uses = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='Maximum Uses',
        help_text='Total number of times this deal can be claimed (Leave empty for unlimited)'
    )
    
    current_uses = models.PositiveIntegerField(
        default=0,
        verbose_name='Current Uses',
        editable=False,
        help_text='Number of times this deal has been claimed'
    )
    
    max_uses_per_user = models.PositiveIntegerField(
        default=1,
        verbose_name='Max Uses Per User',
        help_text='How many times a single user can claim this deal'
    )
    
    # ========================================
    # Display Settings
    # ========================================
    is_active = models.BooleanField(
        default=True,
        verbose_name='Active',
        help_text='Enable/disable deal visibility'
    )
    
    is_featured = models.BooleanField(
        default=False,
        verbose_name='Featured',
        help_text='Display in featured deals section'
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name='Display Order'
    )
    
    # ========================================
    # Statistics
    # ========================================
    view_count = models.PositiveIntegerField(
        default=0,
        verbose_name='View Count',
        editable=False
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
        verbose_name = 'Deal'
        verbose_name_plural = 'Deals'
        ordering = ['-is_featured', 'order', '-created_at']
        indexes = [
            models.Index(fields=['slug']),
            models.Index(fields=['business', 'is_active']),
            models.Index(fields=['deal_type']),
            models.Index(fields=['start_date', 'end_date']),
            models.Index(fields=['is_featured', '-created_at']),
        ]
    
    def _generate_unique_slug(self):
        """Generate a unique, URL-safe slug"""
        # Start with business name + title
        base_text = f"{self.business.name_en} {self.title_en}"
        
        # Create base slug
        base_slug = slugify(base_text)
        
        # Remove any remaining invalid characters (keep only a-z, 0-9, dash, underscore)
        base_slug = re.sub(r'[^a-z0-9\-_]', '', base_slug.lower())
        
        # Remove multiple consecutive dashes
        base_slug = re.sub(r'-+', '-', base_slug)
        
        # Remove leading/trailing dashes
        base_slug = base_slug.strip('-')
        
        # Ensure slug is not empty
        if not base_slug:
            base_slug = f"deal-{timezone.now().strftime('%Y%m%d%H%M%S')}"
        
        # Ensure uniqueness
        slug = base_slug[:240]  # Leave room for counter
        counter = 1
        
        while Deal.objects.filter(slug=slug).exclude(pk=self.pk).exists():
            slug = f"{base_slug[:235]}-{counter}"
            counter += 1
        
        return slug
    
    def save(self, *args, **kwargs):
        """Auto-generate slug on save"""
        if not self.slug:
            self.slug = self._generate_unique_slug()
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.title_en} - {self.business.name_en}"
    
    # ========================================
    # Properties
    # ========================================
    @property
    def title(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.title_ar if lang == 'ar' else self.title_en
    
    @property
    def description(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.description_ar if lang == 'ar' else self.description_en
    
    @property
    def terms(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.terms_ar if lang == 'ar' else self.terms_en
    
    @property
    def is_valid(self) -> bool:
        """هل العرض ساري الآن؟"""
        now = timezone.now()
        return (
            self.is_active and 
            self.start_date <= now <= self.end_date and
            (self.max_uses is None or self.current_uses < self.max_uses)
        )
    
    @property
    def is_expired(self) -> bool:
        """هل انتهى العرض؟"""
        return timezone.now() > self.end_date
    
    @property
    def is_upcoming(self) -> bool:
        """هل العرض قادم؟"""
        return timezone.now() < self.start_date
    
    @property
    def days_remaining(self) -> int:
        """عدد الأيام المتبقية"""
        if self.is_valid:
            delta = self.end_date - timezone.now()
            return max(0, delta.days)
        return 0
    
    @property
    def remaining_uses(self) -> int | None:
        """عدد الاستخدامات المتبقية"""
        if self.max_uses is None:
            return None  # Unlimited
        return max(0, self.max_uses - self.current_uses)
    
    @property
    def savings_amount(self) -> float:
        """مبلغ التوفير"""
        if self.original_price and self.final_price:
            return self.original_price - self.final_price
        elif self.discount_amount:
            return self.discount_amount
        return 0
    
    def get_absolute_url(self):
        return reverse('deals:deal_detail', kwargs={'slug': self.slug})
    
    def increment_view_count(self):
        """زيادة عداد المشاهدات"""
        Deal.objects.filter(pk=self.pk).update(
            view_count=models.F('view_count') + 1
        )
        self.refresh_from_db(fields=['view_count'])
    
    def increment_uses(self):
        """زيادة عداد الاستخدامات"""
        if self.max_uses is None or self.current_uses < self.max_uses:
            Deal.objects.filter(pk=self.pk).update(
                current_uses=models.F('current_uses') + 1
            )
            self.refresh_from_db(fields=['current_uses'])
            return True
        return False


class DealClaim(models.Model):
    """نموذج استخدام العروض"""
    
    deal = models.ForeignKey(
        Deal,
        on_delete=models.CASCADE,
        related_name='claims',
        related_query_name='claim',
        verbose_name='Deal'
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='deal_claims',
        related_query_name='deal_claim',
        verbose_name='User'
    )
    
    claimed_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Claimed At'
    )
    
    is_used = models.BooleanField(
        default=False,
        verbose_name='Used',
        help_text='Has the user actually used this deal?'
    )
    
    used_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Used At'
    )
    
    notes = models.TextField(
        blank=True,
        verbose_name='Notes'
    )
    
    class Meta:
        verbose_name = 'Deal Claim'
        verbose_name_plural = 'Deal Claims'
        ordering = ['-claimed_at']
        indexes = [
            models.Index(fields=['deal', 'user']),
            models.Index(fields=['-claimed_at']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.deal.title_en}"
    
    def mark_as_used(self):
        """تحديد كمستخدم"""
        self.is_used = True
        self.used_at = timezone.now()
        self.save()
