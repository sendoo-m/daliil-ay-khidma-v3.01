"""
Owner Dashboard URLs
====================
"""

from django.urls import path
from apps.dashboard.views import owner
from apps.dashboard.views.business import (
    business_list, business_create, business_update, business_detail, business_delete
)
from apps.dashboard.views.product import (
    product_list, product_create, product_update, product_delete
)
from apps.dashboard.views.deal import (
    deal_list, deal_create, deal_update, deal_delete
)
from apps.dashboard.views.review import (
    review_list, review_reply
)


app_name = 'owner'

urlpatterns = [
    # ── Dashboard Home ────────────────────────────
    path('', owner.owner_dashboard, name='dashboard'),

    # ── Business Management ───────────────────────
    path('businesses/',
         business_list,                            name='business_list'),
    path('businesses/create/',
         business_create,  {'business_type': 'shop'},   name='business_create_shop'),
    path('businesses/create/craft/',
         business_create,  {'business_type': 'craft'},  name='business_create_craft'),
    path('businesses/<slug:slug>/',
         business_detail,                          name='business_detail'),
    path('businesses/<slug:slug>/edit/',
         business_update,                          name='business_edit'),   # ✅ update
    path('businesses/<slug:slug>/delete/',
         business_delete,                          name='business_delete'),

    # ── Product Management ────────────────────────
    path('products/',
         product_list,                             name='product_list'),
    path('products/create/',
         product_create,                           name='product_create'),
    path('products/<slug:slug>/edit/',
         product_update,                           name='product_edit'),    # ✅ update
    path('products/<slug:slug>/delete/',
         product_delete,                           name='product_delete'),

    # ── Deal Management ───────────────────────────
    path('deals/',
         deal_list,                                name='deal_list'),
    path('deals/create/',
         deal_create,                              name='deal_create'),
    path('deals/<slug:slug>/edit/',
         deal_update,                              name='deal_edit'),       # ✅ update
    path('deals/<slug:slug>/delete/',
         deal_delete,                              name='deal_delete'),

    # ── Reviews ───────────────────────────────────
    path('reviews/',
         review_list,                              name='review_list'),
    path('reviews/<int:pk>/reply/',
         review_reply,                             name='review_reply'),    # ✅ reply مش respond
]

# """
# Owner Dashboard URLs
# ====================
# روابط لوحة التحكم - أصحاب المحلات
# """

# from django.urls import path
# from apps.dashboard.views import owner

# app_name = 'owner'

# urlpatterns = [
#     # Dashboard Home
#     path('', owner.owner_dashboard, name='dashboard'),
    
#     # Business Management
#     # Business
#     path('businesses/', owner.business_list, name='business_list'),
#     path('businesses/create/',               owner.business_create,
#         {'business_type': 'shop'},  name='business_create_shop'),
#     path('businesses/create/craft/',         owner.business_create,
#         {'business_type': 'craft'}, name='business_create_craft'),
#     path('businesses/<slug:slug>/edit/',     owner.business_update, name='business_edit'),
#     path('businesses/<slug:slug>/delete/',   owner.business_delete, name='business_delete'),

#     # Product Management
#     path('products/', owner.product_list, name='product_list'),
#     path('products/create/', owner.product_create, name='product_create'),
#     path('products/<slug:slug>/edit/', owner.product_edit, name='product_edit'),
#     path('products/<slug:slug>/delete/', owner.product_delete, name='product_delete'),
    
#     # Deal Management
#     path('deals/', owner.deal_list, name='deal_list'),
#     path('deals/create/', owner.deal_create, name='deal_create'),
#     path('deals/<slug:slug>/edit/', owner.deal_edit, name='deal_edit'),
#     path('deals/<slug:slug>/delete/', owner.deal_delete, name='deal_delete'),
    
#     # Reviews Management
#     path('reviews/', owner.review_list, name='review_list'),
#     path('reviews/<int:pk>/respond/', owner.review_respond, name='review_respond'),
# ]
