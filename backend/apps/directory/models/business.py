"""
Business Model - نموذج المحلات التجارية
==========================================
نموذج شامل مع دعم ثنائي اللغة وجميع الميزات المتقدمة
"""

from django.db import models
from django.conf import settings
from django.utils.text import slugify
from django.urls import reverse
from django.core.validators import (
    RegexValidator,
    MinValueValidator,
    MaxValueValidator
)
from django.utils import timezone
from django.db.models import Avg, Count

# Import Category from categories app
from apps.categories.models import Category

# Import Location models from same package
from .location import District


class Business(models.Model):
    """نموذج المحلات التجارية - شامل ومتقدم"""
    
    # ========================================
    # Business Type Choices
    # ========================================
    BUSINESS_TYPE_CHOICES = [
        ('shop', 'محل تجاري / Commercial Shop'),
        ('craft', 'حرفة أو خدمة حرفية / Craft or Trade Service'),
        ('public', 'خدمة عامة / Public Service'),
    ]
    
    # Egyptian Phone Validator
    phone_regex = RegexValidator(
        regex=r'^01[0-2,5]{1}[0-9]{8}$',
        message="Enter a valid Egyptian phone number (e.g., 01234567890)"
    )
    
    # ========================================
    # Owner
    # ========================================
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='businesses',
        related_query_name='business',
        verbose_name='Owner'
    )
    
    # ========================================
    # Business Type
    # ========================================
    business_type = models.CharField(
        max_length=10,
        choices=BUSINESS_TYPE_CHOICES,
        default='shop',
        verbose_name='نوع المحل / Business Type',
        db_index=True,
        help_text='اختر نوع المحل: تجاري، حرفي، أو خدمة عامة'
    )
    
    # ========================================
    # Basic Info (Bilingual)
    # ========================================
    name_en = models.CharField(
        max_length=200,
        verbose_name='Business Name (English)',
        db_index=True,
        help_text='Example: Golden Restaurant, City Pharmacy, Ahmed the Plumber'
    )
    
    name_ar = models.CharField(
        max_length=200,
        verbose_name='اسم المحل',
        db_index=True,
        help_text='مثال: مطعم الذهبي، صيدلية المدينة، أحمد السباك'
    )
    
    slug = models.SlugField(
        max_length=250,
        unique=True,
        blank=True,
        verbose_name='URL Slug'
    )
    
    # ========================================
    # Images
    # ========================================
    logo = models.ImageField(
        upload_to='businesses/logos/%Y/%m/',
        blank=True,
        null=True,
        verbose_name='Logo',
        help_text='Recommended: 500x500 px square image'
    )
    
    cover_image = models.ImageField(
        upload_to='businesses/covers/%Y/%m/',
        blank=True,
        null=True,
        verbose_name='Cover Image',
        help_text='Wide banner image (Recommended: 1200x400 px)'
    )
    
    # ========================================
    # Classification
    # ========================================
    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name='business_set',
        related_query_name='business',
        verbose_name='Category'
    )
    
    district = models.ForeignKey(
        District,
        on_delete=models.PROTECT,
        related_name='businesses',
        related_query_name='business',
        verbose_name='District'
    )
    
    # ========================================
    # Contact Information
    # ========================================
    phone = models.CharField(
        max_length=15,
        validators=[phone_regex],
        verbose_name='Phone Number',
        help_text='Egyptian mobile number (e.g., 01234567890)'
    )
    
    whatsapp = models.CharField(
        max_length=15,
        blank=True,
        validators=[phone_regex],
        verbose_name='WhatsApp Number',
        help_text='WhatsApp number (optional)'
    )
    
    email = models.EmailField(
        blank=True,
        verbose_name='Email Address'
    )
    
    website = models.URLField(
        blank=True,
        verbose_name='Website URL',
        help_text='Business website (optional)'
    )
    
    # ========================================
    # Social Media
    # ========================================
    facebook = models.URLField(
        blank=True,
        verbose_name='Facebook Page',
        help_text='Facebook page URL (optional)'
    )
    
    instagram = models.URLField(
        blank=True,
        verbose_name='Instagram Account',
        help_text='Instagram profile URL (optional)'
    )
    
    twitter = models.URLField(
        blank=True,
        verbose_name='Twitter Account',
        help_text='Twitter/X profile URL (optional)'
    )
    
    tiktok = models.URLField(
        blank=True,
        verbose_name='TikTok Account',
        help_text='TikTok profile URL (optional)'
    )
    
    # ========================================
    # Location Details
    # ========================================
    address_en = models.TextField(
        verbose_name='Address (English)',
        help_text='Detailed address in English'
    )
    
    address_ar = models.TextField(
        verbose_name='العنوان',
        help_text='العنوان التفصيلي بالعربية'
    )
    
    location_url = models.URLField(
        blank=True,
        verbose_name='Google Maps URL',
        help_text='Google Maps location link (optional)'
    )
    
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Latitude',
        help_text='Auto-determined from map',
        validators=[
            MinValueValidator(-90),
            MaxValueValidator(90)
        ]
    )
    
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Longitude',
        help_text='Auto-determined from map',
        validators=[
            MinValueValidator(-180),
            MaxValueValidator(180)
        ]
    )
    
    # ========================================
    # Description (Bilingual)
    # ========================================
    description_en = models.TextField(
        verbose_name='Description (English)',
        help_text='Detailed description about the business and services'
    )
    
    description_ar = models.TextField(
        verbose_name='الوصف',
        help_text='وصف تفصيلي عن المحل والخدمات'
    )
    
    working_hours_en = models.TextField(
        blank=True,
        verbose_name='Working Hours (English)',
        help_text='Example: Sat-Thu: 9 AM - 10 PM | Fri: 2 PM - 10 PM'
    )
    
    working_hours_ar = models.TextField(
        blank=True,
        verbose_name='ساعات العمل',
        help_text='مثال: السبت-الخميس: 9 ص-10 م | الجمعة: 2 م-10 م'
    )
    
    # ========================================
    # Reviews & Rating - التقييمات
    # ========================================
    average_rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0,
        verbose_name='Average Rating',
        editable=False,
        help_text='Auto-calculated from reviews'
    )
    
    total_reviews = models.PositiveIntegerField(
        default=0,
        verbose_name='Total Reviews',
        editable=False,
        help_text='Auto-calculated count of approved reviews'
    )
    
    # ========================================
    # Statistics
    # ========================================
    view_count = models.PositiveIntegerField(
        default=0,
        verbose_name='View Count',
        editable=False,
        help_text='Total number of page views'
    )
    
    click_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Click Count',
        editable=False,
        help_text='Total clicks on contact buttons'
    )
    
    # ========================================
    # Status Flags
    # ========================================
    is_active = models.BooleanField(
        default=False,
        verbose_name='Active',
        db_index=True,
        help_text='Enable/disable business visibility on the site'
    )
    
    is_verified = models.BooleanField(
        default=False,
        verbose_name='Verified',
        db_index=True,
        help_text='Business has been verified by admin'
    )
    
    is_featured = models.BooleanField(
        default=False,
        verbose_name='Featured',
        db_index=True,
        help_text='Display in featured businesses section'
    )
    
    is_promoted = models.BooleanField(
        default=False,
        verbose_name='Promoted',
        db_index=True,
        help_text='Promoted businesses (paid promotion)'
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
    
    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Verified At',
        help_text='Date when business was verified'
    )
    
    class Meta:
        verbose_name = 'Business'
        verbose_name_plural = 'Businesses'
        ordering = ['-is_featured', '-is_promoted', '-created_at']
        indexes = [
            models.Index(fields=['slug']),
            models.Index(fields=['business_type']),
            models.Index(fields=['business_type', 'is_active']),
            models.Index(fields=['is_active', 'is_verified']),
            models.Index(fields=['category', 'is_active']),
            models.Index(fields=['district', 'is_active']),
            models.Index(fields=['-view_count']),
            models.Index(fields=['-average_rating']),
            models.Index(fields=['is_featured', '-created_at']),
            models.Index(fields=['is_promoted', '-created_at']),
            models.Index(fields=['owner', 'is_active']),
        ]
    
    def save(self, *args, **kwargs):
        """Auto-generate slug and handle verification timestamp"""
        # Auto-generate slug
        if not self.slug:
            base_slug = slugify(self.name_en)
            slug = base_slug
            counter = 1
            while Business.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        
        # Set verified_at if being verified
        if self.is_verified and not self.verified_at:
            self.verified_at = timezone.now()
        elif not self.is_verified:
            self.verified_at = None
        
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.name_en} ({self.get_business_type_display()})"
    
    # ========================================
    # Translation Properties
    # ========================================
    @property
    def name(self):
        """Get name based on current language"""
        from django.utils.translation import get_language
        lang = get_language()
        return self.name_ar if lang == 'ar' else self.name_en
    
    @property
    def description(self):
        """Get description based on current language"""
        from django.utils.translation import get_language
        lang = get_language()
        return self.description_ar if lang == 'ar' else self.description_en
    
    @property
    def address(self):
        """Get address based on current language"""
        from django.utils.translation import get_language
        lang = get_language()
        return self.address_ar if lang == 'ar' else self.address_en
    
    @property
    def working_hours(self):
        """Get working hours based on current language"""
        from django.utils.translation import get_language
        lang = get_language()
        return self.working_hours_ar if lang == 'ar' else self.working_hours_en
    
    # ========================================
    # Business Type Properties
    # ========================================
    @property
    def business_type_display(self):
        """Get business type display name"""
        return self.get_business_type_display()
    
    @property
    def is_shop(self) -> bool:
        """Check if business is a shop"""
        return self.business_type == 'shop'
    
    @property
    def is_craft(self) -> bool:
        """Check if business is a craft/trade service"""
        return self.business_type == 'craft'
    
    @property
    def is_public_service(self) -> bool:
        """Check if business is a public service"""
        return self.business_type == 'public'
    
    @property
    def business_type_icon(self) -> str:
        """Get icon for business type"""
        icons = {
            'shop': '🏪',
            'craft': '🔧',
            'public': '🏛️',
        }
        return icons.get(self.business_type, '📍')
    
    # ========================================
    # Location Properties
    # ========================================
    @property
    def city(self):
        """Get city from district"""
        return self.district.city if self.district else None
    
    @property
    def governorate(self):
        """Get governorate from district"""
        if self.district and self.district.city:
            return self.district.city.governorate
        return None
    
    @property
    def has_location(self):
        """Check if business has geographic coordinates"""
        return self.latitude is not None and self.longitude is not None
    
    @property
    def full_location(self):
        """Get full location string"""
        parts = []
        if self.district:
            parts.append(self.district.name)
        if self.city:
            parts.append(self.city.name)
        if self.governorate:
            parts.append(self.governorate.name)
        return ', '.join(parts)
    
    # ========================================
    # Social Media Properties
    # ========================================
    @property
    def has_social_media(self):
        """Check if business has any social media links"""
        return any([self.facebook, self.instagram, self.twitter, self.tiktok])
    
    @property
    def social_media_count(self):
        """Count active social media links"""
        return sum([
            bool(self.facebook),
            bool(self.instagram),
            bool(self.twitter),
            bool(self.tiktok)
        ])
    
    # ========================================
    # Rating Properties
    # ========================================
    @property
    def rating_percentage(self):
        """Get rating as percentage (0-100)"""
        return (self.average_rating / 5) * 100 if self.average_rating > 0 else 0
    
    @property
    def rating_stars_full(self):
        """Number of full stars"""
        return int(self.average_rating)
    
    @property
    def rating_stars_half(self):
        """Has half star?"""
        return (self.average_rating - int(self.average_rating)) >= 0.5
    
    @property
    def rating_stars_empty(self):
        """Number of empty stars"""
        full = self.rating_stars_full
        half = 1 if self.rating_stars_half else 0
        return 5 - full - half
    
    # ========================================
    # Status Properties
    # ========================================
    @property
    def is_published(self):
        """Check if business is published (active and verified)"""
        return self.is_active and self.is_verified
    
    @property
    def status_display(self):
        """Get human-readable status"""
        if not self.is_active:
            return "Inactive"
        elif not self.is_verified:
            return "Pending Verification"
        elif self.is_promoted:
            return "Promoted"
        elif self.is_featured:
            return "Featured"
        else:
            return "Active"
    
    # ========================================
    # URLs
    # ========================================
    def get_absolute_url(self):
        """Get business detail page URL"""
        return reverse('directory:business_detail', kwargs={'slug': self.slug})
    
    def get_edit_url(self):
        """Get business edit URL"""
        return reverse('directory:business_edit', kwargs={'slug': self.slug})
    
    def get_map_url(self):
        """Get Google Maps URL"""
        if self.has_location:
            return f"https://www.google.com/maps?q={self.latitude},{self.longitude}"
        return self.location_url if self.location_url else "#"
    
    # ========================================
    # Counter Methods
    # ========================================
    def increment_view_count(self):
        """Increment view counter"""
        Business.objects.filter(pk=self.pk).update(
            view_count=models.F('view_count') + 1
        )
        self.refresh_from_db(fields=['view_count'])
    
    def increment_click_count(self):
        """Increment click counter"""
        Business.objects.filter(pk=self.pk).update(
            click_count=models.F('click_count') + 1
        )
        self.refresh_from_db(fields=['click_count'])
    
    # ========================================
    # Review Methods
    # ========================================
    def update_rating(self):
        """Update average rating and total reviews from Review model"""
        try:
            from apps.reviews.models import Review
            
            stats = Review.objects.filter(
                business=self,
                is_approved=True
            ).aggregate(
                avg_rating=Avg('rating'),
                total=Count('id')
            )
            
            self.average_rating = round(stats['avg_rating'], 2) if stats['avg_rating'] else 0
            self.total_reviews = stats['total'] or 0
            self.save(update_fields=['average_rating', 'total_reviews'])
            
        except (ImportError, Exception) as e:
            # Reviews app not installed or error occurred
            pass
    
    def get_reviews(self, limit=None):
        """Get approved reviews for this business"""
        try:
            from apps.reviews.models import Review
            
            reviews = Review.objects.filter(
                business=self,
                is_approved=True
            ).select_related('user').prefetch_related('reply').order_by('-created_at')
            
            if limit:
                reviews = reviews[:limit]
            
            return reviews
        except ImportError:
            return []
    
    # ========================================
    # Product Methods
    # ========================================
    def get_products(self, limit=None):
        """Get available products for this business"""
        try:
            from apps.products.models import Product
            
            products = Product.objects.filter(
                business=self,
                is_available=True
            ).prefetch_related('images').order_by('-is_featured', 'order', '-created_at')
            
            if limit:
                products = products[:limit]
            
            return products
        except ImportError:
            return []
    
    @property
    def products_count(self):
        """Count available products"""
        try:
            from apps.products.models import Product
            return Product.objects.filter(business=self, is_available=True).count()
        except ImportError:
            return 0


# ========================================
# صور المحلات - Business Images
# ========================================
class BusinessImage(models.Model):
    """نموذج صور المحلات التجارية"""
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='images',
        related_query_name='image',
        verbose_name='Business'
    )
    
    image = models.ImageField(
        upload_to='businesses/gallery/%Y/%m/',
        verbose_name='Image'
    )
    
    caption_en = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='Caption (English)'
    )
    
    caption_ar = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='الوصف'
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name='Display Order'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='Active'
    )
    
    uploaded_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Uploaded At'
    )
    
    class Meta:
        verbose_name = 'Business Image'
        verbose_name_plural = 'Business Images'
        ordering = ['order', '-uploaded_at']
        indexes = [
            models.Index(fields=['business', 'is_active']),
            models.Index(fields=['order']),
        ]
    
    def __str__(self):
        return f"Image - {self.business.name_en}"
    
    @property
    def caption(self):
        """Get caption based on current language"""
        from django.utils.translation import get_language
        lang = get_language()
        return self.caption_ar if lang == 'ar' else self.caption_en


# ========================================
# ساعات العمل - Business Working Hours
# ========================================
class BusinessWorkingHours(models.Model):
    """نموذج ساعات العمل المفصلة"""
    
    DAYS_OF_WEEK = [
        (0, 'الأحد / Sunday'),
        (1, 'الإثنين / Monday'),
        (2, 'الثلاثاء / Tuesday'),
        (3, 'الأربعاء / Wednesday'),
        (4, 'الخميس / Thursday'),
        (5, 'الجمعة / Friday'),
        (6, 'السبت / Saturday'),
    ]
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='working_hours_detailed',
        related_query_name='working_hour',
        verbose_name='Business'
    )
    
    day = models.IntegerField(
        choices=DAYS_OF_WEEK,
        verbose_name='Day of Week'
    )
    
    opening_time = models.TimeField(
        null=True,
        blank=True,
        verbose_name='Opening Time'
    )
    
    closing_time = models.TimeField(
        null=True,
        blank=True,
        verbose_name='Closing Time'
    )
    
    is_closed = models.BooleanField(
        default=False,
        verbose_name='Closed on this day'
    )
    
    is_24_hours = models.BooleanField(
        default=False,
        verbose_name='Open 24 Hours'
    )
    
    class Meta:
        verbose_name = 'Working Hours'
        verbose_name_plural = 'Working Hours'
        ordering = ['day']
        unique_together = [['business', 'day']]
        indexes = [
            models.Index(fields=['business', 'day']),
        ]
    
    def __str__(self):
        day_name = self.get_day_display()
        if self.is_closed:
            return f"{self.business.name_en} - {day_name}: Closed"
        elif self.is_24_hours:
            return f"{self.business.name_en} - {day_name}: 24 Hours"
        return f"{self.business.name_en} - {day_name}: {self.opening_time} - {self.closing_time}"
    
    def clean(self):
        """Validation"""
        from django.core.exceptions import ValidationError
        
        if not self.is_closed and not self.is_24_hours:
            if not self.opening_time or not self.closing_time:
                raise ValidationError('Opening and closing times are required unless closed or 24 hours')
        
        if self.opening_time and self.closing_time:
            if self.opening_time >= self.closing_time:
                raise ValidationError('Closing time must be after opening time')
