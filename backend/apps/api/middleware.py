import hashlib
import re
import time

from django.core.cache import cache
from django.http import JsonResponse


class BusinessInteractionProtectionMiddleware:
    """Protect public business counter endpoints from bursts and duplicates."""

    interaction_pattern = re.compile(
        r'^/api/v\d+/businesses/(?P<slug>[^/]+)/increment_(?P<event>view|click)/$'
    )
    duplicate_ttl_seconds = 60
    rate_limit = 30
    rate_window_seconds = 60

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method != 'POST':
            return self.get_response(request)

        match = self.interaction_pattern.match(request.path)
        if match is None:
            return self.get_response(request)

        identity = self._identity(request)
        event = match.group('event')
        slug = match.group('slug')

        rate_key = self._hash_key(f'rate:{identity}:{event}')
        if not self._consume_rate_slot(rate_key):
            return self._throttled_response('تم تجاوز الحد المسموح مؤقتًا')

        duplicate_key = self._hash_key(f'duplicate:{identity}:{slug}:{event}')
        if not cache.add(duplicate_key, True, timeout=self.duplicate_ttl_seconds):
            return self._throttled_response('تم تسجيل هذا الحدث مؤخرًا')

        return self.get_response(request)

    def _consume_rate_slot(self, key):
        now = int(time.time())
        window = now // self.rate_window_seconds
        window_key = f'{key}:{window}'

        if cache.add(window_key, 1, timeout=self.rate_window_seconds + 5):
            return True

        try:
            count = cache.incr(window_key)
        except ValueError:
            cache.set(window_key, 1, timeout=self.rate_window_seconds + 5)
            count = 1
        return count <= self.rate_limit

    @staticmethod
    def _hash_key(value):
        digest = hashlib.sha256(value.encode()).hexdigest()
        return f'business-interaction:{digest}'

    @staticmethod
    def _identity(request):
        user = getattr(request, 'user', None)
        if user and user.is_authenticated:
            return f'user:{user.pk}'

        forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR', '')
        ip = forwarded_for.split(',')[0].strip() if forwarded_for else request.META.get('REMOTE_ADDR', '')
        return f'ip:{ip or "unknown"}'

    @staticmethod
    def _throttled_response(message):
        return JsonResponse(
            {
                'success': False,
                'status_code': 429,
                'errors': {'detail': message},
            },
            status=429,
        )
