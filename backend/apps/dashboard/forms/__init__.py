from .admin_forms import (
    UserProfileForm,
    AdminUserCreateForm,
    AdminUserEditForm,
    AdminBusinessForm,
    AdminProductForm,
    AdminDealForm,
    CategoryForm,
)

# ─── alias for admin_crud views ───
BusinessForm = AdminBusinessForm

from .product import ProductForm          # form خاص بأصحاب المحلات
from .deal import DealForm                # form خاص بأصحاب المحلات

from .business_create import (
    BusinessCreateForm,
    BusinessImageFormSet,
)

__all__ = [
    'UserProfileForm',
    'AdminUserCreateForm',
    'AdminUserEditForm',
    'BusinessForm',
    'AdminBusinessForm',
    'AdminProductForm',
    'AdminDealForm',
    'ProductForm',
    'DealForm',
    'CategoryForm',
    'BusinessCreateForm',
    'BusinessImageFormSet',
]
