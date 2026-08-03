"""
Review Management Views
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q

from apps.reviews.models import Review, ReviewReply
from apps.directory.models import Business


@login_required
def review_list(request):
    """قائمة تقييمات محلات المستخدم"""
    reviews = Review.objects.filter(
        business__owner=request.user
    ).select_related('business', 'user', 'reply').order_by('-created_at')
    
    # Filter by business
    business_id = request.GET.get('business')
    if business_id:
        reviews = reviews.filter(business_id=business_id)
    
    # Filter by rating
    rating = request.GET.get('rating')
    if rating:
        reviews = reviews.filter(rating=rating)
    
    # Filter by status
    status = request.GET.get('status')
    if status == 'approved':
        reviews = reviews.filter(is_approved=True)
    elif status == 'pending':
        reviews = reviews.filter(is_approved=False)
    elif status == 'replied':
        reviews = reviews.exclude(reply__isnull=True)
    elif status == 'unreplied':
        reviews = reviews.filter(reply__isnull=True)
    
    # Search
    search = request.GET.get('search')
    if search:
        reviews = reviews.filter(
            Q(comment__icontains=search) |
            Q(user__username__icontains=search) |
            Q(user__first_name__icontains=search) |
            Q(user__last_name__icontains=search)
        )
    
    # Pagination
    paginator = Paginator(reviews, 10)
    page = request.GET.get('page')
    reviews = paginator.get_page(page)
    
    # Get user businesses for filter
    businesses = Business.objects.filter(owner=request.user)
    
    context = {
        'reviews': reviews,
        'businesses': businesses,
        'total_count': Review.objects.filter(business__owner=request.user).count(),
        'pending_count': Review.objects.filter(
            business__owner=request.user,
            is_approved=False
        ).count(),
        'unreplied_count': Review.objects.filter(
            business__owner=request.user
        ).filter(reply__isnull=True).count(),
    }
    
    return render(request, 'dashboard/review/list.html', context)


@login_required
def review_reply(request, pk):
    """الرد على تقييم"""
    review = get_object_or_404(Review, pk=pk, business__owner=request.user)
    
    if request.method == 'POST':
        comment = request.POST.get('comment', '').strip()
        
        if not comment:
            messages.error(request, 'يجب إدخال نص الرد!')
            return redirect('dashboard:review_reply', pk=pk)
        
        # Create or update reply
        reply, created = ReviewReply.objects.update_or_create(
            review=review,
            defaults={
                'user': request.user,
                'comment': comment,
            }
        )
        
        if created:
            messages.success(request, 'تم إضافة الرد بنجاح!')
        else:
            messages.success(request, 'تم تحديث الرد بنجاح!')
        
        return redirect('dashboard:review_list')
    
    context = {
        'review': review,
    }
    
    return render(request, 'dashboard/review/reply.html', context)


@login_required
def review_approve(request, pk):
    """اعتماد تقييم"""
    review = get_object_or_404(Review, pk=pk, business__owner=request.user)
    
    if request.method == 'POST':
        review.is_approved = True
        review.save()
        messages.success(request, 'تم اعتماد التقييم بنجاح!')
        return redirect('dashboard:review_list')
    
    return redirect('dashboard:review_list')


@login_required
def review_reject(request, pk):
    """رفض تقييم"""
    review = get_object_or_404(Review, pk=pk, business__owner=request.user)
    
    if request.method == 'POST':
        review.is_approved = False
        review.save()
        messages.success(request, 'تم رفض التقييم بنجاح!')
        return redirect('dashboard:review_list')
    
    return redirect('dashboard:review_list')
