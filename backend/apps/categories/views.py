"""
Categories Views
================
عرض التصنيفات
"""

from django.shortcuts import render, get_object_or_404
from django.core.paginator import Paginator
from django.db.models import Count, Q

from .models import Category


def category_list(request):
    """قائمة التصنيفات الرئيسية"""
    categories = Category.objects.filter(
        is_active=True,
        parent__isnull=True
    ).annotate(
        businesses_count=Count(
            'business',  # ← استخدم related_query_name بدلاً من related_name
            filter=Q(business__is_active=True)
        )
    ).order_by('order')
    
    context = {
        'categories': categories,
        'total_count': categories.count()
    }
    return render(request, 'categories/category_list.html', context)


def category_detail(request, slug):
    """تفاصيل تصنيف معين"""
    category = get_object_or_404(Category, slug=slug, is_active=True)
    
    # Get subcategories
    subcategories = category.children.filter(is_active=True).annotate(
        businesses_count=Count(
            'business',  # ← استخدم related_query_name
            filter=Q(business__is_active=True)
        )
    ).order_by('order')
    
    # Get businesses in this category
    from apps.directory.models import Business
    
    # Get all category IDs (current + subcategories)
    category_ids = [category.id] + list(
        subcategories.values_list('id', flat=True)
    )
    
    businesses = Business.objects.filter(
        category_id__in=category_ids,
        is_active=True,
        is_verified=True
    ).select_related(
        'category',
        'district__city__governorate'
    ).order_by('-is_featured', '-created_at')
    
    # Pagination
    paginator = Paginator(businesses, 20)
    page = request.GET.get('page')
    businesses_page = paginator.get_page(page)
    
    context = {
        'category': category,
        'subcategories': subcategories,
        'businesses': businesses_page,
        'total_businesses': businesses.count()
    }
    return render(request, 'categories/category_detail.html', context)
