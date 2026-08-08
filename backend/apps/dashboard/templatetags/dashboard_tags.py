"""
Dashboard Template Tags
=======================
"""
from django import template
from apps.core.models import SiteSettings

register = template.Library()


@register.simple_tag
def get_site_settings():
    """إرجاع إعدادات الموقع للاستخدام في القوالب."""
    return SiteSettings.get_settings()
