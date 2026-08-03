# apps/reviews/views.py
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render
from django.contrib import messages
from django.core.paginator import Paginator
from django.views.decorators.http import require_POST

from apps.directory.models import Business
from .models import Review, ReviewReply


@login_required
def add_review(request, business_slug):
    """إضافة تقييم لمحل"""
    business = get_object_or_404(
        Business,
        slug=business_slug,
        is_active=True,
        is_verified=True,
    )
    
    # التحقق من أن المستخدم لم يقيّم من قبل
    existing_review = Review.objects.filter(
        business=business,
        user=request.user,
    ).first()
    
    if existing_review:
        messages.warning(request, 'لقد قمت بتقييم هذا المحل من قبل!')
        return redirect(business.get_absolute_url())
    
    if request.method == 'POST':
        rating = request.POST.get('rating')
        comment = request.POST.get('comment', '')
        
        if rating and rating.isdigit() and 1 <= int(rating) <= 5:
            Review.objects.create(
                business=business,
                user=request.user,
                rating=int(rating),
                comment=comment,
            )
            messages.success(request, 'تم إضافة تقييمك بنجاح! شكراً لك.')
            return redirect(business.get_absolute_url())
        else:
            messages.error(request, 'الرجاء اختيار تقييم صحيح (1-5 نجوم).')
    
    context = {
        'business': business,
    }
    return render(request, 'reviews/add_review.html', context)


@login_required
def edit_review(request, review_id):
    """تعديل تقييم"""
    review = get_object_or_404(Review, pk=review_id, user=request.user)
    
    if request.method == 'POST':
        rating = request.POST.get('rating')
        comment = request.POST.get('comment', '')
        
        if rating and rating.isdigit() and 1 <= int(rating) <= 5:
            review.rating = int(rating)
            review.comment = comment
            review.save()
            messages.success(request, 'تم تحديث تقييمك بنجاح!')
            return redirect(review.business.get_absolute_url())
        else:
            messages.error(request, 'الرجاء اختيار تقييم صحيح (1-5 نجوم).')
    
    context = {
        'review': review,
        'business': review.business,
    }
    return render(request, 'reviews/edit_review.html', context)


@login_required
@require_POST
def delete_review(request, review_id):
    """حذف تقييم"""
    review = get_object_or_404(Review, pk=review_id, user=request.user)
    business = review.business
    review.delete()
    messages.success(request, 'تم حذف تقييمك.')
    return redirect(business.get_absolute_url())


def business_reviews(request, business_slug):
    """عرض جميع تقييمات محل"""
    business = get_object_or_404(
        Business,
        slug=business_slug,
        is_active=True,
        is_verified=True,
    )
    
    reviews = Review.objects.filter(
        business=business,
        is_approved=True,
    ).select_related('user').prefetch_related('reply').order_by('-created_at')
    
    paginator = Paginator(reviews, 10)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'business': business,
        'page_obj': page_obj,
    }
    return render(request, 'reviews/business_reviews.html', context)


@login_required
@require_POST
def add_review_reply(request, review_id):
    """رد صاحب المحل على تقييم"""
    review = get_object_or_404(Review, pk=review_id)
    
    # التحقق من أن المستخدم هو صاحب المحل
    if review.business.owner != request.user:
        messages.error(request, 'غير مصرح لك بهذا الإجراء!')
        return redirect(review.business.get_absolute_url())
    
    # التحقق من عدم وجود رد سابق
    if hasattr(review, 'reply'):
        messages.warning(request, 'لقد قمت بالرد على هذا التقييم من قبل!')
        return redirect(review.business.get_absolute_url())
    
    comment = request.POST.get('comment', '').strip()
    
    if comment:
        ReviewReply.objects.create(
            review=review,
            user=request.user,
            comment=comment,
        )
        messages.success(request, 'تم إضافة ردك بنجاح!')
    else:
        messages.error(request, 'الرجاء كتابة رد!')
    
    return redirect(review.business.get_absolute_url())


@login_required
@require_POST
def edit_review_reply(request, reply_id):
    """تعديل رد على تقييم"""
    reply = get_object_or_404(ReviewReply, pk=reply_id, user=request.user)
    
    comment = request.POST.get('comment', '').strip()
    
    if comment:
        reply.comment = comment
        reply.save()
        messages.success(request, 'تم تحديث ردك بنجاح!')
    else:
        messages.error(request, 'الرجاء كتابة رد!')
    
    return redirect(reply.review.business.get_absolute_url())


@login_required
@require_POST
def delete_review_reply(request, reply_id):
    """حذف رد على تقييم"""
    reply = get_object_or_404(ReviewReply, pk=reply_id, user=request.user)
    business = reply.review.business
    reply.delete()
    messages.success(request, 'تم حذف ردك.')
    return redirect(business.get_absolute_url())
