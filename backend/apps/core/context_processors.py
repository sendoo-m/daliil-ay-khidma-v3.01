"""
Core Context Processors
=======================
معالجات السياق العامة
"""

from django.conf import settings
from django.utils.translation import get_language


def language_context(request):
    """Add language info to all templates"""
    return {
        'LANGUAGE_CODE': get_language(),
        'LANGUAGES': settings.LANGUAGES,
        'AVAILABLE_LANGUAGES': dict(settings.LANGUAGES),
    }

# core/context_processors.py
from .models import SiteSettings

def site_settings(request):
    settings_obj = SiteSettings.get_settings()
    return {
        'site_settings': settings_obj
    }

# # apps/core/context_processors.py
# def language_context(request):
#     """Add language info to all templates"""
#     lang = request.session.get('django_language', 'ar')
#     return {
#         'CURRENT_LANGUAGE': lang,
#         'IS_ARABIC': lang == 'ar',
#         'IS_ENGLISH': lang == 'en',
#     }
