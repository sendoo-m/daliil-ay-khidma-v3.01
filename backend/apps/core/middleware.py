"""
Custom middleware for Daliil Ay Khidma
"""
from django.utils import translation


class AdminEnglishMiddleware:
    """
    Force Django Admin to use English language only.
    All other pages will use the normal Django language system
    (LocaleMiddleware + user choice via set_language).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # لو المستخدم داخل على لوحة الإدارة
        if request.path.startswith('/admin'):
            translation.activate('en')
            request.LANGUAGE_CODE = 'en'
            response = self.get_response(request)
            translation.deactivate()
            return response

        # باقي الموقع: لا نغيّر اللغة هنا
        # نخلي LocaleMiddleware و set_language يتصرفوا
        response = self.get_response(request)
        return response


# ⚠️ ملاحظة هامة:
# لا نستخدم ForceArabicMiddleware الآن لأنه يمنع تغيير اللغة.
# لو كان عندك ForceArabicMiddleware مفعّل في settings.MIDDLEWARE شيله.


# class ForceArabicMiddleware:
#     """
#     Force all non-admin pages to use Arabic language.
#     This middleware ensures consistent Arabic experience across the site.
#     """
    
#     def __init__(self, get_response):
#         self.get_response = get_response
    
#     def __call__(self, request):
#         # Skip admin panel (handled by AdminEnglishMiddleware)
#         if not request.path.startswith('/admin'):
#             # Set Arabic as active language
#             translation.activate('ar')
#             request.LANGUAGE_CODE = 'ar'
        
#         response = self.get_response(request)
#         return response
