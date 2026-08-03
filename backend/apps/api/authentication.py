"""Custom Authentication Classes"""
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.authentication import SessionAuthentication


class CustomJWTAuthentication(JWTAuthentication):
    """JWT authentication hook reserved for future mobile-specific claims."""

    pass


class CsrfExemptSessionAuthentication(SessionAuthentication):
    """Session authentication without CSRF for API"""
    
    def enforce_csrf(self, request):
        return  # Skip CSRF check for API
