"""
Deal Management Views
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q
from django.utils import timezone

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.dashboard.forms import DealForm


@login_required
def deal_list(request):
    """قائمة عروض المستخدم"""
    deals = Deal.objects.filter(
        business__owner=request.user
    ).select_related('business').order_by('-created_at')
    
    # Filter by business
    business_id = request.GET.get('business')
    if business_id:
        deals = deals.filter(business_id=business_id)
    
    # Filter by type
    deal_type = request.GET.get('type')
    if deal_type:
        deals = deals.filter(deal_type=deal_type)
    
    # Filter by status
    status = request.GET.get('status')
    now = timezone.now()
    if status == 'active':
        deals = deals.filter(start_date__lte=now, end_date__gte=now)
    elif status == 'upcoming':
        deals = deals.filter(start_date__gt=now)
    elif status == 'expired':
        deals = deals.filter(end_date__lt=now)
    
    # Search
    search = request.GET.get('search')
    if search:
        deals = deals.filter(
            Q(title_en__icontains=search) |
            Q(title_ar__icontains=search)
        )
    
    # Pagination
    paginator = Paginator(deals, 12)
    page = request.GET.get('page')
    deals = paginator.get_page(page)
    
    # Get user businesses for filter
    businesses = Business.objects.filter(owner=request.user)
    
    # Calculate statistics
    all_deals = Deal.objects.filter(business__owner=request.user)
    
    context = {
        'deals': deals,
        'businesses': businesses,
        'today': now,
        'total_count': all_deals.count(),
        'active_count': all_deals.filter(
            start_date__lte=now,
            end_date__gte=now
        ).count(),
        'upcoming_count': all_deals.filter(start_date__gt=now).count(),
        'expired_count': all_deals.filter(end_date__lt=now).count(),
    }
    
    return render(request, 'dashboard/deal/list.html', context)


@login_required
def deal_create(request):
    """إضافة عرض جديد"""
    # Get user businesses
    user_businesses = Business.objects.filter(owner=request.user)
    
    if not user_businesses.exists():
        messages.warning(request, 'يجب إضافة محل أولاً قبل إضافة عروض!')
        return redirect('dashboard:business_create')
    
    if request.method == 'POST':
        form = DealForm(request.POST, request.FILES, user=request.user)
        if form.is_valid():
            deal = form.save()
            messages.success(request, 'تم إضافة العرض بنجاح!')
            return redirect('dashboard:deal_list')
    else:
        form = DealForm(user=request.user)
    
    context = {
        'form': form,
        'title': 'إضافة عرض جديد',
    }
    
    return render(request, 'dashboard/deal/form.html', context)


@login_required
def deal_update(request, slug):
    """تعديل عرض"""
    deal = get_object_or_404(Deal, slug=slug, business__owner=request.user)
    
    if request.method == 'POST':
        form = DealForm(request.POST, request.FILES, instance=deal, user=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'تم تحديث العرض بنجاح!')
            return redirect('dashboard:deal_list')
    else:
        form = DealForm(instance=deal, user=request.user)
    
    context = {
        'form': form,
        'deal': deal,
        'title': f'تعديل {deal.title_ar}',
    }
    
    return render(request, 'dashboard/deal/form.html', context)


@login_required
def deal_delete(request, slug):
    """حذف عرض"""
    deal = get_object_or_404(Deal, slug=slug, business__owner=request.user)
    
    if request.method == 'POST':
        deal_title = deal.title_ar
        deal.delete()
        messages.success(request, f'تم حذف {deal_title} بنجاح!')
        return redirect('dashboard:deal_list')
    
    context = {
        'deal': deal,
    }
    
    return render(request, 'dashboard/deal/delete.html', context)
