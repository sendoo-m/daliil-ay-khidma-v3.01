"""
Translation Template Tags
=========================
Template tags للترجمة المخصصة
"""

from django import template
from apps.core.translations import translate

register = template.Library()


@register.simple_tag(takes_context=True)
def t(context, text):
    """
    ترجمة نص حسب اللغة الحالية
    
    Usage: {% t "Home" %}
    """
    language = context.get('LANGUAGE_CODE', 'ar')
    return translate(text, language)


@register.filter
def trans(text, language='ar'):
    """
    Filter للترجمة
    
    Usage: {{ "Home"|trans:LANGUAGE_CODE }}
    """
    return translate(text, language)
