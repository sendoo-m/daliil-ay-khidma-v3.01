"""
Products & Services Models
===========================
نماذج المنتجات والخدمات مع دعم ثنائي اللغة
"""

from django.db import models
from django.utils.text import slugify
from django.core.validators import MinValueValidator
from django.urls import reverse
from django.utils import timezone

from apps.directory.models import Business


class Product(models.Model):
    """نموذج المنتجات/الخدمات - ثنائي اللغة"""
    
    PRODUCT_TYPE_CHOICES = [
        ('product', 'Product / منتج'),
        ('service', 'Service / خدمة'),
    ]
    
    # ========================================
    # Basic Info
    # ========================================
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='products',
        related_query_name='product',
        verbose_name='Business'
    )
    
    name_en = models.CharField(
        max_length=200,
        verbose_name='Name (English)',
        db_index=True,
        help_text='Product/Service name in English'
    )
    
    name_ar = models.CharField(
        max_length=200,
        verbose_name='الاسم',
        db_index=True,
        help_text='اسم المنتج/الخدمة بالعربية'
    )
    
    slug = models.SlugField(
        max_length=250,
        unique=True,
        blank=True,
        verbose_name='URL Slug'
    )
    
    product_type = models.CharField(
        max_length=10,
        choices=PRODUCT_TYPE_CHOICES,
        default='product',
        verbose_name='Type',
        db_index=True
    )
    
    # ========================================
    # Description
    # ========================================
    description_en = models.TextField(
        verbose_name='Description (English)',
        help_text='Detailed description in English'
    )
    
    description_ar = models.TextField(
        verbose_name='الوصف',
        help_text='وصف تفصيلي بالعربية'
    )
    
    # ========================================
    # Pricing
    # ========================================
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        verbose_name='Price (EGP)',
        help_text='Price in Egyptian Pounds',
        validators=[MinValueValidator(0)]
    )
    
    old_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Old Price (EGP)',
        help_text='Previous price (for discount display)',
        validators=[MinValueValidator(0)]
    )
    
    # ========================================
    # Availability
    # ========================================
    is_available = models.BooleanField(
        default=True,
        verbose_name='Available',
        help_text='Is this product/service currently available?'
    )
    
    stock_quantity = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='Stock Quantity',
        help_text='Leave empty for unlimited stock'
    )
    
    # ========================================
    # Delivery Options
    # ========================================
    has_delivery = models.BooleanField(
        default=False,
        verbose_name='Delivery Available'
    )
    
    delivery_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Delivery Cost (EGP)',
        validators=[MinValueValidator(0)]
    )
    
    delivery_time_en = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='Delivery Time (English)',
        help_text='Example: 1-2 business days'
    )
    
    delivery_time_ar = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='وقت التوصيل',
        help_text='مثال: 1-2 يوم عمل'
    )
    
    # ========================================
    # Display Settings
    # ========================================
    order = models.IntegerField(
        default=0,
        verbose_name='Display Order',
        help_text='Lower number = displayed first'
    )
    
    is_featured = models.BooleanField(
        default=False,
        verbose_name='Featured',
        help_text='Display in featured products section'
    )
    
    # ========================================
    # Statistics
    # ========================================
    view_count = models.PositiveIntegerField(
        default=0,
        verbose_name='Views',
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
        verbose_name = 'Product/Service'
        verbose_name_plural = 'Products & Services'
        ordering = ['business', 'order', '-created_at']
        indexes = [
            models.Index(fields=['slug']),
            models.Index(fields=['business', 'is_available']),
            models.Index(fields=['product_type', 'is_available']),
            models.Index(fields=['is_featured', '-created_at']),
            models.Index(fields=['-view_count']),
        ]
    
    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(f"{self.business.name_en}-{self.name_en}")
            slug = base_slug
            counter = 1
            while Product.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.name_en} - {self.business.name_en}"
    
    # ========================================
    # Properties
    # ========================================
    @property
    def name(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.name_ar if lang == 'ar' else self.name_en
    
    @property
    def description(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.description_ar if lang == 'ar' else self.description_en
    
    @property
    def delivery_time(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.delivery_time_ar if lang == 'ar' else self.delivery_time_en
    
    @property
    def discount_percentage(self) -> float:
        """حساب نسبة الخصم"""
        if self.old_price and self.old_price > self.price:
            discount = ((self.old_price - self.price) / self.old_price) * 100
            return round(discount, 0)
        return 0
    
    @property
    def has_discount(self) -> bool:
        """هل يوجد خصم؟"""
        return bool(self.old_price and self.old_price > self.price)
    
    @property
    def is_in_stock(self) -> bool:
        """هل المنتج متوفر في المخزون؟"""
        if self.stock_quantity is None:
            return True  # Unlimited stock
        return self.stock_quantity > 0
    
    def get_absolute_url(self):
        return reverse('products:product_detail', kwargs={'slug': self.slug})
    
    def increment_view_count(self):
        """زيادة عداد المشاهدات"""
        Product.objects.filter(pk=self.pk).update(
            view_count=models.F('view_count') + 1
        )
        self.refresh_from_db(fields=['view_count'])


class ProductImage(models.Model):
    """نموذج صور المنتجات"""
    
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='images',
        related_query_name='image',
        verbose_name='Product'
    )
    
    image = models.ImageField(
        upload_to='products/images/%Y/%m/',
        verbose_name='Image'
    )
    
    alt_text_en = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='Alt Text (English)',
        help_text='Image description for SEO'
    )
    
    alt_text_ar = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='النص البديل',
        help_text='وصف الصورة لمحركات البحث'
    )
    
    is_primary = models.BooleanField(
        default=False,
        verbose_name='Primary Image',
        help_text='Main product image'
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name='Display Order'
    )
    
    uploaded_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Uploaded At'
    )
    
    class Meta:
        verbose_name = 'Product Image'
        verbose_name_plural = 'Product Images'
        ordering = ['-is_primary', 'order', '-uploaded_at']
        indexes = [
            models.Index(fields=['product', 'is_primary']),
        ]
    
    def __str__(self):
        return f"Image - {self.product.name_en}"
    
    def save(self, *args, **kwargs):
        # If this is set as primary, unset others
        if self.is_primary:
            ProductImage.objects.filter(
                product=self.product,
                is_primary=True
            ).exclude(pk=self.pk).update(is_primary=False)
        super().save(*args, **kwargs)
    
    @property
    def alt_text(self):
        from django.utils.translation import get_language
        lang = get_language()
        return self.alt_text_ar if lang == 'ar' else self.alt_text_en
