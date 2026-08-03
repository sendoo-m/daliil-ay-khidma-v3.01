"""
Location Models - نماذج المواقع الجغرافية
=====================================
Hierarchical location system with 3 levels:
Governorate (محافظة) > City (مدينة) > District (حي)

This module provides a comprehensive geographic location system
for organizing businesses in Egypt.
"""


from django.db import models
from django.utils.text import slugify
from django.utils.translation import gettext_lazy as _
from django.core.validators import MinValueValidator
from django.urls import reverse
from django.db.models import Count, Q


class Governorate(models.Model):
    """
    Governorate Model - نموذج المحافظة
    
    Represents Egyptian governorates with bilingual support.
    يمثل المحافظات المصرية مع دعم ثنائي اللغة.
    """
    
    name_en = models.CharField(
        max_length=100,
        verbose_name=_('Name (English)'),
        db_index=True,
        help_text=_('Governorate name in English (e.g., Cairo, Alexandria, Giza)')
    )
    
    name_ar = models.CharField(
        max_length=100,
        verbose_name=_('الاسم (عربي)'),
        db_index=True,
        help_text=_('اسم المحافظة بالعربية (مثال: القاهرة، الإسكندرية، الجيزة)')
    )
    
    slug = models.SlugField(
        max_length=100,
        unique=True,
        blank=True,
        verbose_name=_('URL Slug'),
        help_text=_('Auto-generated from English name for SEO-friendly URLs')
    )
    
    description_en = models.TextField(
        blank=True,
        verbose_name=_('Description (English)'),
        help_text=_('Brief description of the governorate in English')
    )
    
    description_ar = models.TextField(
        blank=True,
        verbose_name=_('الوصف (عربي)'),
        help_text=_('وصف مختصر للمحافظة بالعربية')
    )
    
    icon = models.CharField(
        max_length=50,
        blank=True,
        default='fas fa-city',
        verbose_name=_('Icon Class'),
        help_text=_('FontAwesome icon class (default: fas fa-city)')
    )
    
    image = models.ImageField(
        upload_to='governorates/%Y/%m/',
        blank=True,
        null=True,
        verbose_name=_('Governorate Image'),
        help_text=_('Representative image for the governorate (optional)')
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name=_('Active Status'),
        help_text=_('Inactive governorates will be hidden from public view')
    )
    
    order = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_('Display Order'),
        help_text=_('Order for displaying in lists (lower numbers appear first)')
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Created At')
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_('Last Updated')
    )
    
    class Meta:
        verbose_name = _('Governorate')
        verbose_name_plural = _('Governorates')
        ordering = ['order', 'name_en']
        indexes = [
            models.Index(fields=['slug'], name='gov_slug_idx'),
            models.Index(fields=['is_active', 'order'], name='gov_active_order_idx'),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['name_en'],
                name='unique_governorate_name_en',
                violation_error_message=_('A governorate with this English name already exists.')
            ),
            models.UniqueConstraint(
                fields=['name_ar'],
                name='unique_governorate_name_ar',
                violation_error_message=_('محافظة بهذا الاسم العربي موجودة بالفعل.')
            ),
        ]
    
    def save(self, *args, **kwargs):
        """يولد Slug تلقائياً من الاسم الإنجليزي | Auto-generates slug from English name"""
        if not self.slug:
            self.slug = slugify(self.name_en)
        super().save(*args, **kwargs)
    
    def __str__(self):
        """يرجع الاسم العربي للمحافظة | Returns Arabic name"""
        return f"{self.name_ar} | {self.name_en}"
    
    @property
    def name(self):
        """يرجع الاسم حسب اللغة المفعّلة | Returns name based on active language"""
        from django.utils.translation import get_language
        return self.name_ar if get_language() == 'ar' else self.name_en
    
    def get_absolute_url(self):
        """يرجع رابط صفحة المحافظة | Returns governorate detail URL"""
        return reverse('directory:governorate_detail', kwargs={'slug': self.slug})
    
    @property
    def cities_count(self):
        """يرجع عدد المدن في المحافظة | Returns number of cities"""
        return self.cities.filter(is_active=True).count()
    
    @property
    def businesses_count(self):
        """يرجع عدد الأعمال في المحافظة | Returns total businesses count"""
        from apps.directory.models import Business
        return Business.objects.filter(
            district__city__governorate=self,
            is_active=True
        ).count()


class City(models.Model):
    """
    City Model - نموذج المدينة
    
    Represents cities within governorates.
    يمثل المدن داخل المحافظات.
    """
    
    governorate = models.ForeignKey(
        Governorate,
        on_delete=models.CASCADE,
        related_name='cities',
        verbose_name=_('Governorate'),
        help_text=_('The governorate this city belongs to')
    )
    
    name_en = models.CharField(
        max_length=100,
        db_index=True,
        verbose_name=_('Name (English)'),
        help_text=_('City name in English')
    )
    
    name_ar = models.CharField(
        max_length=100,
        db_index=True,
        verbose_name=_('الاسم (عربي)'),
        help_text=_('اسم المدينة بالعربية')
    )
    
    slug = models.SlugField(
        max_length=100,
        unique=True,
        blank=True,
        verbose_name=_('URL Slug')
    )
    
    description_en = models.TextField(
        blank=True,
        verbose_name=_('Description (English)')
    )
    
    description_ar = models.TextField(
        blank=True,
        verbose_name=_('الوصف (عربي)')
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name=_('Active Status')
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name=_('Display Order')
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Created At')
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_('Last Updated')
    )
    
    class Meta:
        verbose_name = _('City')
        verbose_name_plural = _('Cities')
        ordering = ['governorate__order', 'order', 'name_en']
        indexes = [
            models.Index(fields=['slug'], name='city_slug_idx'),
            models.Index(fields=['governorate', 'is_active'], name='city_gov_active_idx'),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['governorate', 'name_en'],
                name='unique_city_name_en_per_gov',
                violation_error_message=_('A city with this English name already exists in this governorate.')
            ),
            models.UniqueConstraint(
                fields=['governorate', 'name_ar'],
                name='unique_city_name_ar_per_gov',
                violation_error_message=_('مدينة بهذا الاسم موجودة بالفعل في هذه المحافظة.')
            ),
        ]
    
    def save(self, *args, **kwargs):
        """يولد Slug فريد من المحافظة والمدينة | Generates unique slug"""
        if not self.slug:
            base = slugify(f"{self.governorate.name_en}-{self.name_en}")
            slug = base
            counter = 1
            while City.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)
    
    def __str__(self):
        """يعرض اسم المدينة مع المحافظة | Displays city with governorate"""
        return f"{self.name_ar} - {self.governorate.name_ar}"
    
    @property
    def name(self):
        """يرجع الاسم حسب اللغة | Returns name based on language"""
        from django.utils.translation import get_language
        return self.name_ar if get_language() == 'ar' else self.name_en
    
    @property
    def districts_count(self):
        """يرجع عدد الأحياء | Returns districts count"""
        return self.districts.filter(is_active=True).count()
    
    @property
    def businesses_count(self):
        """يرجع عدد الأعمال | Returns businesses count"""
        from apps.directory.models import Business
        return Business.objects.filter(
            district__city=self,
            is_active=True
        ).count()


class District(models.Model):
    """
    District Model - نموذج الحي
    
    Represents districts/neighborhoods within cities.
    يمثل الأحياء داخل المدن.
    """
    
    city = models.ForeignKey(
        City,
        on_delete=models.CASCADE,
        related_name='districts',
        verbose_name=_('City'),
        help_text=_('The city this district belongs to')
    )
    
    name_en = models.CharField(
        max_length=100,
        db_index=True,
        verbose_name=_('Name (English)'),
        help_text=_('District name in English')
    )
    
    name_ar = models.CharField(
        max_length=100,
        db_index=True,
        verbose_name=_('الاسم (عربي)'),
        help_text=_('اسم الحي بالعربية')
    )
    
    slug = models.SlugField(
        max_length=100,
        unique=True,
        blank=True,
        verbose_name=_('URL Slug')
    )
    
    description_en = models.TextField(
        blank=True,
        verbose_name=_('Description (English)')
    )
    
    description_ar = models.TextField(
        blank=True,
        verbose_name=_('الوصف (عربي)')
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name=_('Active Status')
    )
    
    order = models.IntegerField(
        default=0,
        verbose_name=_('Display Order')
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Created At')
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_('Last Updated')
    )
    
    class Meta:
        verbose_name = _('District')
        verbose_name_plural = _('Districts')
        ordering = ['city__order', 'order', 'name_en']
        indexes = [
            models.Index(fields=['slug'], name='district_slug_idx'),
            models.Index(fields=['city', 'is_active'], name='district_city_active_idx'),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['city', 'name_en'],
                name='unique_district_name_en_per_city',
                violation_error_message=_('A district with this English name already exists in this city.')
            ),
            models.UniqueConstraint(
                fields=['city', 'name_ar'],
                name='unique_district_name_ar_per_city',
                violation_error_message=_('حي بهذا الاسم موجود بالفعل في هذه المدينة.')
            ),
        ]
    
    def save(self, *args, **kwargs):
        """يولد Slug فريد من المحافظة والمدينة والحي | Generates unique slug"""
        if not self.slug:
            base = slugify(f"{self.city.governorate.name_en}-{self.city.name_en}-{self.name_en}")
            slug = base
            counter = 1
            while District.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)
    
    def __str__(self):
        """يعرض الحي مع المدينة والمحافظة | Displays full location path"""
        return f"{self.name_ar} - {self.city.name_ar} - {self.city.governorate.name_ar}"
    
    @property
    def name(self):
        """يرجع الاسم حسب اللغة | Returns name based on language"""
        from django.utils.translation import get_language
        return self.name_ar if get_language() == 'ar' else self.name_en
    
    @property
    def governorate(self):
        """يرجع المحافظة | Returns parent governorate"""
        return self.city.governorate
    
    @property
    def full_location_ar(self):
        """يرجع الموقع الكامل بالعربية | Returns full location in Arabic"""
        return f"{self.name_ar}، {self.city.name_ar}، {self.governorate.name_ar}"
    
    @property
    def full_location_en(self):
        """يرجع الموقع الكامل بالإنجليزية | Returns full location in English"""
        return f"{self.name_en}, {self.city.name_en}, {self.governorate.name_en}"
    
    @property
    def businesses_count(self):
        """يرجع عدد الأعمال في الحي | Returns businesses count in district"""
        from apps.directory.models import Business
        return Business.objects.filter(
            district=self,
            is_active=True
        ).count()
