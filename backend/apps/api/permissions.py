"""Custom API Permissions"""
from rest_framework import permissions


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Allow owners to edit, others to read only"""
    
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Check if object has owner attribute
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        
        # Check if object has user attribute
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        return False


class IsBusinessOwner(permissions.BasePermission):
    """Allow only business owners to access"""
    
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (
                user.is_staff
                or getattr(user, 'is_business_owner', False)
                or user.businesses.exists()
            )
        )
    
    def has_object_permission(self, request, view, obj):
        # For Business model
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        
        # For related models (Product, Deal, etc.)
        if hasattr(obj, 'business'):
            return obj.business.owner == request.user
        
        return False


class IsAdminUser(permissions.BasePermission):
    """Allow only admin/staff users"""
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_staff


class IsAdminOrReadOnly(permissions.BasePermission):
    """Allow admins to edit, others to read only"""
    
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user and request.user.is_staff
