# apps/accounts/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Custom User Admin"""
    
    list_display = [
        'username',
        'email',
        'first_name',
        'last_name',
        'phone',
        'is_business_owner',
        'is_active',
        'date_joined',
    ]
    
    list_filter = [
        'is_active',
        'is_staff',
        'is_superuser',
        'is_business_owner',
        'email_verified',
        'date_joined',
    ]
    
    search_fields = [
        'username',
        'email',
        'first_name',
        'last_name',
        'phone',
    ]
    
    fieldsets = (
        (None, {
            'fields': ('username', 'password')
        }),
        ('Personal Information', {
            'fields': (
                'first_name',
                'last_name',
                'email',
                'phone',
                'city',
                'profile_picture',
                'bio',
            )
        }),
        ('Permissions', {
            'fields': (
                'is_active',
                'is_staff',
                'is_superuser',
                'is_business_owner',
                'email_verified',
                'groups',
                'user_permissions',
            ),
        }),
        ('Important Dates', {
            'fields': (
                'last_login',
                'date_joined',
            )
        }),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': (
                'username',
                'email',
                'phone',
                'password1',
                'password2',
            ),
        }),
    )
    
    ordering = ['-date_joined']
    list_per_page = 50
