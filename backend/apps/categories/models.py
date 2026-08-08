"""
Categories Models
================
نماذج التصنيفات
"""

from django.db import models
from django.utils.text import slugify
from django.core.validators import MinValueValidator
from django.urls import reverse


class Category(models.Model):
    """
    نموذج التصنيف الرئيسي
    Supports hierarchical structure (parent-child)
    """

    # ========================================
    # BASIC INFORMATION
    # ========================================
    name_en = models.CharField(
        max_length=100,
        verbose_name='Name (English)',
        db_index=True
    )
    name_ar = models.CharField(
        max_length=100,
        verbose_name='Name (Arabic)',
        db_index=True
    )

    slug = models.SlugField(
        max_length=150,
        unique=True,
        verbose_name='URL Slug',
        help_text='Unique URL identifier'
    )

    # ========================================
    # DESCRIPTIONS
    # ========================================
    description_en = models.TextField(
        blank=True,
        verbose_name='Description (English)'
    )
    description_ar = models.TextField(
        blank=True,
        verbose_name='Description (Arabic)'
    )

    # ========================================
    # HIERARCHY
    # ========================================
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='children',
        verbose_name='Parent Category'
    )

    # ========================================
    # VISUAL & DISPLAY
    # ========================================
    icon = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='Icon Class',
        help_text='Font Awesome icon class (e.g., fas fa-store)'
    )

    image = models.ImageField(
        upload_to='categories/',
        blank=True,
        null=True,
        verbose_name='Category Image'
    )

    order = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name='Display Order',
        db_index=True
    )

    # ========================================
    # SEO
    # ========================================
    meta_keywords_en = models.CharField(
        max_length=255,
        blank=True,
        verbose_name='Meta Keywords (English)'
    )
    meta_keywords_ar = models.CharField(
        max_length=255,
        blank=True,
        verbose_name='Meta Keywords (Arabic)'
    )

    # ========================================
    # DIRECTORY TYPE
    # ========================================
    BUSINESS_TYPE_CHOICES = [
        ('shop',   'محل تجاري'),
        ('craft',  'حرفة أو مهنة'),
        ('public', 'خدمة عامة'),
    ]

    business_type = models.CharField(
        max_length=20,
        choices=BUSINESS_TYPE_CHOICES,
        default='shop',
        db_index=True,
        verbose_name='نوع الدليل',
        help_text='الدليل الذي يظهر فيه هذا القسم'
    )

    is_active = models.BooleanField(
        default=True,
        verbose_name='Active',
        db_index=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Created At'
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Updated At'
    )

    class Meta:
        verbose_name = 'Category'
        verbose_name_plural = 'Categories'
        ordering = ['order', 'name_ar']
        indexes = [
            models.Index(fields=['slug']),
            models.Index(fields=['is_active', 'order']),
            models.Index(fields=['parent', 'is_active']),
        ]

    def __str__(self):
        """Always display Arabic name as the primary label."""
        return self.name_ar or self.name_en

    def save(self, *args, **kwargs):
        """Auto-generate slug if not provided"""
        if not self.slug:
            self.slug = slugify(self.name_en)
        super().save(*args, **kwargs)

    def get_absolute_url(self):
        return reverse('directory:category_detail', kwargs={'slug': self.slug})

    def get_business_count(self):
        return self.business_set.filter(is_active=True).count()

    def get_all_business_count(self):
        from apps.directory.models import Business
        count = self.business_set.filter(is_active=True).count()
        for child in self.children.filter(is_active=True):
            count += child.get_all_business_count()
        return count

    def get_breadcrumb(self):
        breadcrumb = [self]
        parent = self.parent
        while parent:
            breadcrumb.insert(0, parent)
            parent = parent.parent
        return breadcrumb
