# config/settings/development.py
from .base import *
import sys


DEBUG = True


ALLOWED_HOSTS = ['localhost', '127.0.0.1', '*']


# لا تُحمّل أدوات التطوير أثناء الاختبارات.
if 'test' not in sys.argv:
    INSTALLED_APPS += [
        'debug_toolbar',
    ]

    MIDDLEWARE.insert(0, 'debug_toolbar.middleware.DebugToolbarMiddleware')

MIDDLEWARE.insert(0, 'apps.api.middleware.BusinessInteractionProtectionMiddleware')


INTERNAL_IPS = [
    '127.0.0.1',
]


# Debug Toolbar Config
DEBUG_TOOLBAR_CONFIG = {
    'SHOW_TOOLBAR_CALLBACK': lambda request: DEBUG,
    'DISABLE_PANELS': [
        'debug_toolbar.panels.redirects.RedirectsPanel',
    ],
}


# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


# Email Backend
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
