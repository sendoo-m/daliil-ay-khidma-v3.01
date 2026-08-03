"""
Categories App Configuration
============================
"""

from django.apps import AppConfig


class CategoriesConfig(AppConfig):
    """إعدادات تطبيق التصنيفات"""
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.categories'
    verbose_name = 'Categories Management'
    verbose_name_plural = 'Categories'

    def ready(self):
        """Keep legacy category admin links compatible with the current app label."""
        from . import admin as categories_admin

        original_reverse = categories_admin.reverse

        def admin_reverse(viewname, *args, **kwargs):
            if viewname == 'admin:directory_category_change':
                viewname = 'admin:categories_category_change'
            return original_reverse(viewname, *args, **kwargs)

        categories_admin.reverse = admin_reverse
