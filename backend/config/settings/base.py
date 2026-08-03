"""
Django settings for daliil-ay-khidma project.
Base settings shared across all environments.
"""
from pathlib import Path
from decouple import config
from django.utils.translation import gettext_lazy as _


# ========================================
# BUILD PATHS
# ========================================
BASE_DIR = Path(__file__).resolve().parent.parent.parent


# ========================================
# SECURITY
# ========================================
SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-this-in-production-12345')

DEBUG = config('DEBUG', default=False, cast=bool)

ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1', cast=lambda v: [s.strip() for s in v.split(',')])


# ========================================
# APPLICATION DEFINITION
# ========================================
INSTALLED_APPS = [
    # Django built-in apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.humanize',  # Human-friendly numbers
    
    # Third-party apps
    'rest_framework',
    'rest_framework.authtoken',  # ← أضف
    'rest_framework_simplejwt.token_blacklist',
    'drf_spectacular',
    'corsheaders',
    'django_filters',
    'crispy_forms',
    'crispy_bootstrap5',
    'cloudinary',
    'cloudinary_storage',
    'django_cleanup.apps.CleanupConfig',
    
    # Local apps - Core
    'apps.core',
    'apps.accounts',
    'apps.api',
    
    # Local apps - Main Features
    'apps.directory',
    'apps.products',
    'apps.categories',
    'apps.reviews',
    
    # Local apps - Advanced Features
    'apps.subscriptions',
    'apps.deals',
    
    # Local apps - Utilities
    'apps.services',
    'apps.search',
    'apps.dashboard',
    'apps.notifications',
]


# ========================================
# MIDDLEWARE
# ========================================
# MIDDLEWARE = [
#     'django.middleware.security.SecurityMiddleware',
#     'corsheaders.middleware.CorsMiddleware',
#     'django.contrib.sessions.middleware.SessionMiddleware',
#     'django.middleware.locale.LocaleMiddleware',
#     'apps.core.middleware.AdminEnglishMiddleware',  # Force admin to English
#     'django.middleware.common.CommonMiddleware',
#     'django.middleware.csrf.CsrfViewMiddleware',
#     'django.contrib.auth.middleware.AuthenticationMiddleware',
#     'django.contrib.messages.middleware.MessageMiddleware',
#     'django.middleware.clickjacking.XFrameOptionsMiddleware',
# ]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'apps.core.middleware.AdminEnglishMiddleware',  # خليها
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]


# ========================================
# URL CONFIGURATION
# ========================================
ROOT_URLCONF = 'config.urls'


# ========================================
# TEMPLATES
# ========================================
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'apps.core.context_processors.site_settings',
                'django.template.context_processors.media',
                'django.template.context_processors.static',
                'django.template.context_processors.i18n',
                'apps.core.context_processors.language_context',
            ],
        },
    },
]


# ========================================
# WSGI
# ========================================
WSGI_APPLICATION = 'config.wsgi.application'


# ========================================
# DATABASE
# ========================================
# Override this in development.py or production.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


# ========================================
# PASSWORD VALIDATION
# ========================================
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {
            'min_length': 8,
        }
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# ========================================
# INTERNATIONALIZATION
# ========================================
LANGUAGE_CODE = 'ar'  # اللغة الافتراضية للموقع

LANGUAGES = [
    ('ar', 'العربية'),
    ('en', 'English'),
]

# Language Cookie
LANGUAGE_COOKIE_NAME = 'django_language'
LANGUAGE_COOKIE_AGE = 365 * 24 * 60 * 60  # 1 year

TIME_ZONE = 'Africa/Cairo'

USE_I18N = True
USE_TZ = True


# ========================================
# STATIC FILES (CSS, JavaScript, Images)
# ========================================
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']

STATICFILES_FINDERS = [
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
]


# ========================================
# MEDIA FILES
# ========================================
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# ========================================
# DEFAULT PRIMARY KEY FIELD TYPE
# ========================================
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# ========================================
# CUSTOM USER MODEL
# ========================================
AUTH_USER_MODEL = 'accounts.User'


# ========================================
# AUTHENTICATION
# ========================================
AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
]

LOGIN_URL = 'accounts:login'
LOGIN_REDIRECT_URL = 'dashboard:index'
LOGOUT_REDIRECT_URL = 'accounts:login'


# ========================================
# CRISPY FORMS
# ========================================
CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'


# ========================================
# DJANGO REST FRAMEWORK
# ========================================
REST_FRAMEWORK = {
    # Schema
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    
    # Authentication
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    
    # Permissions
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],

    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '300/hour',
        'user': '3000/hour',
        'login': '10/minute',
        'registration': '5/hour',
        'password_reset': '5/hour',
    },
    
    # Pagination
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    
    # Filtering
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    
    # Renderers
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
        'rest_framework.renderers.BrowsableAPIRenderer',
    ],
    
    # Parsers
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
        'rest_framework.parsers.FormParser',
        'rest_framework.parsers.MultiPartParser',
    ],
    # Date/Time formats
    'DATETIME_FORMAT': '%Y-%m-%d %H:%M:%S',
    'DATE_FORMAT': '%Y-%m-%d',
    'TIME_FORMAT': '%H:%M:%S',
    
    # Error handling
    'EXCEPTION_HANDLER': 'apps.api.exceptions.mobile_api_exception_handler',
}


# ========================================
# SIMPLE JWT - MOBILE API
# ========================================
SIMPLE_JWT = {
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'CHECK_REVOKE_TOKEN': True,
}

MOBILE_PASSWORD_RESET_URL = config(
    'MOBILE_PASSWORD_RESET_URL',
    default='daliil://reset-password',
)

PUSH_NOTIFICATIONS_ENABLED = config(
    'PUSH_NOTIFICATIONS_ENABLED', default=False, cast=bool
)
FIREBASE_CREDENTIALS_PATH = config('FIREBASE_CREDENTIALS_PATH', default='')


# ========================================
# DRF SPECTACULAR (API DOCUMENTATION)
# ========================================
SPECTACULAR_SETTINGS = {
    'TITLE': 'Daliil Ay Khidma API',
    'DESCRIPTION': 'RESTful API for Business Directory Platform',
    'VERSION': '2.0.0',
    'SCHEMA_PATH_PREFIX_INSERT': '/api/v2',
    'SERVE_INCLUDE_SCHEMA': False,
    
    # API info
    'CONTACT': {
        'name': 'API Support',
        'email': 'support@daliilaaykhidma.com',
    },
    'LICENSE': {
        'name': 'Proprietary',
    },
    
    # Schema generation
    'COMPONENT_SPLIT_REQUEST': True,
    'SORT_OPERATIONS': False,
    
    # UI settings
    'SWAGGER_UI_SETTINGS': {
        'deepLinking': True,
        'persistAuthorization': True,
        'displayOperationId': True,
        'filter': True,
    },
    
    # Tags
    'TAGS': [
        {'name': 'Authentication', 'description': 'User authentication endpoints'},
        {'name': 'Directory', 'description': 'Business directory operations'},
        {'name': 'Products', 'description': 'Products and services'},
        {'name': 'Reviews', 'description': 'Reviews and ratings'},
        {'name': 'Deals', 'description': 'Special offers and deals'},
        {'name': 'Subscriptions', 'description': 'Subscription plans'},
    ],
}


# ========================================
# CORS HEADERS
# ========================================
CORS_ALLOW_ALL_ORIGINS = config('CORS_ALLOW_ALL_ORIGINS', default=False, cast=bool)

CORS_ALLOWED_ORIGINS = [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080',
    'https://sendoo-m.github.io',
]

CORS_ALLOW_CREDENTIALS = True

CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]


# ========================================
# EMAIL CONFIGURATION
# ========================================
EMAIL_BACKEND = config(
    'EMAIL_BACKEND',
    default='django.core.mail.backends.console.EmailBackend'
)
EMAIL_HOST = config('EMAIL_HOST', default='localhost')
EMAIL_PORT = config('EMAIL_PORT', default=25, cast=int)
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=False, cast=bool)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='noreply@daliilaaykhidma.com')


# ========================================
# LOGGING
# ========================================
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'filters': {
        'require_debug_true': {
            '()': 'django.utils.log.RequireDebugTrue',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'filters': ['require_debug_true'],
            'class': 'logging.StreamHandler',
            'formatter': 'simple'
        },
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR / 'logs' / 'django.log',
            'maxBytes': 1024 * 1024 * 15,  # 15MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}


# ========================================
# CACHING
# ========================================
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}


# ========================================
# SESSION CONFIGURATION
# ========================================
SESSION_COOKIE_AGE = 1209600  # 2 weeks
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = not DEBUG  # True in production
SESSION_COOKIE_SAMESITE = 'Lax'


# ========================================
# CSRF CONFIGURATION
# ========================================
CSRF_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = not DEBUG  # True in production
CSRF_COOKIE_SAMESITE = 'Lax'


# ========================================
# FILE UPLOAD SETTINGS
# ========================================
FILE_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB
FILE_UPLOAD_PERMISSIONS = 0o644


# ========================================
# BUSINESS LOGIC SETTINGS
# ========================================
# Reviews
REVIEWS_PER_PAGE = 10
MIN_REVIEW_RATING = 1
MAX_REVIEW_RATING = 5

# Products
PRODUCTS_PER_PAGE = 12

# Businesses
BUSINESSES_PER_PAGE = 15
BUSINESS_CLAIM_APPROVAL_REQUIRED = True

# Subscriptions
SUBSCRIPTION_TRIAL_DAYS = 14
SUBSCRIPTION_GRACE_PERIOD_DAYS = 7

# Deals
DEALS_PER_PAGE = 12
DEAL_CLAIM_LIMIT_PER_USER = 10


# ========================================
# IMAGE SETTINGS
# ========================================
IMAGE_UPLOAD_MAX_SIZE = 5 * 1024 * 1024  # 5MB
ALLOWED_IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp']
THUMBNAIL_SIZE = (300, 300)
LARGE_IMAGE_SIZE = (1200, 1200)
