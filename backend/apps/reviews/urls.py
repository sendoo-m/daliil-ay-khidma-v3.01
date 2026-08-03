# apps/reviews/urls.py
from django.urls import path
from . import views

app_name = 'reviews'

urlpatterns = [
    # إضافة وتعديل وحذف تقييم
    path('add/<slug:business_slug>/', views.add_review, name='add_review'),
    path('edit/<int:review_id>/', views.edit_review, name='edit_review'),
    path('delete/<int:review_id>/', views.delete_review, name='delete_review'),
    
    # عرض تقييمات محل
    path('business/<slug:business_slug>/', views.business_reviews, name='business_reviews'),
    
    # رد صاحب المحل
    path('reply/add/<int:review_id>/', views.add_review_reply, name='add_reply'),
    path('reply/edit/<int:reply_id>/', views.edit_review_reply, name='edit_reply'),
    path('reply/delete/<int:reply_id>/', views.delete_review_reply, name='delete_reply'),
]
