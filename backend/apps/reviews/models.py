# apps/reviews/models.py
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.conf import settings
from django.db.models import Avg, Count

from apps.directory.models import Business


class Review(models.Model):
    """تقييم محل من عميل"""
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='reviews',
        verbose_name='المحل',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='reviews',
        verbose_name='المستخدم',
    )
    
    # التقييم
    rating = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        verbose_name='التقييم',
        help_text='من 1 إلى 5 نجوم',
    )
    
    # التعليق
    comment = models.TextField(
        blank=True,
        verbose_name='التعليق',
    )
    
    # حالة التقييم
    is_approved = models.BooleanField(
        default=False,
        verbose_name='معتمد؟',
        help_text='هل التقييم معتمد للعرض؟',
    )
    
    # التواريخ
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإضافة',
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث',
    )
    
    class Meta:
        verbose_name = 'Review'
        verbose_name_plural = 'Reviews'
        ordering = ['-created_at']
        unique_together = ['business', 'user']
        indexes = [
            models.Index(fields=['business', 'is_approved']),
            models.Index(fields=['user']),
            models.Index(fields=['-created_at']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.business.name_en} ({self.rating}⭐)"
    
    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.update_business_rating()
    
    def delete(self, *args, **kwargs):
        business = self.business
        super().delete(*args, **kwargs)
        self.update_business_rating_for(business)
    
    def update_business_rating(self):
        """تحديث متوسط التقييم للمحل"""
        self.update_business_rating_for(self.business)
    
    @staticmethod
    def update_business_rating_for(business):
        """تحديث متوسط التقييم لمحل معين"""
        stats = Review.objects.filter(
            business=business,
            is_approved=True,
        ).aggregate(
            avg_rating=Avg('rating'),
            total=Count('id')
        )
        
        business.average_rating = stats['avg_rating'] or 0
        business.total_reviews = stats['total'] or 0
        business.save(update_fields=['average_rating', 'total_reviews'])


class ReviewReply(models.Model):
    """رد صاحب المحل على التقييم"""
    
    review = models.OneToOneField(
        Review,
        on_delete=models.CASCADE,
        related_name='reply',
        verbose_name='التقييم',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='review_replies',
        verbose_name='المستخدم (صاحب المحل)',
    )
    
    # الرد
    comment = models.TextField(
        verbose_name='الرد',
    )
    
    # التواريخ
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الرد',
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث',
    )
    
    class Meta:
        verbose_name = 'Review Reply'
        verbose_name_plural = 'Review Replies'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Reply to: {self.review}"


class ReviewLike(models.Model):
    """إعجاب مستخدم بتقييم واحد."""

    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='review_likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['review', 'user'],
                name='unique_review_like_per_user',
            )
        ]


class ReviewReport(models.Model):
    """بلاغ مستخدم عن تقييم غير مناسب."""

    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name='reports')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='review_reports',
    )
    reason = models.CharField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['review', 'user'],
                name='unique_review_report_per_user',
            )
        ]
