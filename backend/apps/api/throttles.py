import hashlib
import re

from django.core.cache import cache
from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle


class LoginRateThrottle(AnonRateThrottle):
    scope = 'login'


class RegistrationRateThrottle(AnonRateThrottle):
    scope = 'registration'


class PasswordResetRateThrottle(AnonRateThrottle):
    scope = 'password_reset'


class BusinessInteractionRateThrottle(SimpleRateThrottle):
    """Protect public view/click counters from bursts and duplicate events."""

    scope = 'business_interaction'
    duplicate_ttl_seconds = 60
    interaction_pattern = re.compile(
        r'^/api/v\d+/businesses/(?P<slug>[^/]+)/increment_(?P<event>view|click)/$'
    )

    def allow_request(self, request, view):
        match = self.interaction_pattern.match(request.path)
        if not match:
            return True

        self._interaction_match = match
        if not super().allow_request(request, view):
            return False

        identity = self._identity(request)
        fingerprint = hashlib.sha256(
            f"{identity}:{match.group('slug')}:{match.group('event')}".encode()
        ).hexdigest()
        duplicate_key = f'business-interaction-once:{fingerprint}'
        return cache.add(duplicate_key, True, timeout=self.duplicate_ttl_seconds)

    def get_cache_key(self, request, view):
        match = getattr(self, '_interaction_match', None)
        if match is None:
            return None
        ident = self._identity(request)
        return self.cache_format % {
            'scope': self.scope,
            'ident': f"{ident}:{match.group('event')}",
        }

    def _identity(self, request):
        user = getattr(request, 'user', None)
        if user and user.is_authenticated:
            return f'user:{user.pk}'
        return f'ip:{self.get_ident(request)}'
