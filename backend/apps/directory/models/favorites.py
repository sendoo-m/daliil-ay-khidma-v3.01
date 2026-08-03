"""
Favorite Model
=============
نموذج المفضلة
"""

from django.db import models
from django.conf import settings
from .business import Business


class Favorite(models.Model):
    """نموذج المفضلة - حفظ المحلات المفضلة للمستخدم"""
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='favorites',
        related_query_name='favorite',
        verbose_name='User'
    )
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='favorited_by',
        related_query_name='favorite',
        verbose_name='Business'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Added At'
    )
    
    class Meta:
        verbose_name = 'Favorite'
        verbose_name_plural = 'Favorites'
        unique_together = [['user', 'business']]
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['business', '-created_at']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.business.name_en}"

# """
# Favorites Model - نموذج المفضلة
# =================================
# حفظ المحلات المفضلة للمستخدمين
# """

# from django.db import models
# from django.conf import settings
# from .business import Business


# class Favorite(models.Model):
#     """نموذج حفظ المحلات المفضلة"""
    
#     user = models.ForeignKey(
#         settings.AUTH_USER_MODEL,
#         on_delete=models.CASCADE,
#         related_name='favorites',
#         related_query_name='favorite',
#         verbose_name='User'
#     )
    
#     business = models.ForeignKey(
#         Business,
#         on_delete=models.CASCADE,
#         related_name='favorited_by',
#         related_query_name='favorited_by_user',
#         verbose_name='Business'
#     )
    
#     created_at = models.DateTimeField(
#         auto_now_add=True,
#         verbose_name='Added At'
#     )
    
#     class Meta:
#         verbose_name = 'Favorite'
#         verbose_name_plural = 'Favorites'
#         ordering = ['-created_at']
#         indexes = [
#             models.Index(fields=['user', '-created_at']),
#             models.Index(fields=['business', '-created_at']),
#         ]
#         constraints = [
#             models.UniqueConstraint(
#                 fields=['user', 'business'],
#                 name='unique_user_business_favorite'
#             )
#         ]
    
#     def __str__(self):
#         return f"{self.user.email} - {self.business.name_en}"
