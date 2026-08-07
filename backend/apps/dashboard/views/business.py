"""Owner business management views."""

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404, redirect, render

from apps.dashboard.forms.business_create import BusinessCreateForm, BusinessImageFormSet
from apps.directory.models import Business
from apps.directory.models.location import Governorate
from apps.subscriptions.models import Subscription


BUSINESS_FORM_SECTIONS = {
    1: {
        'business_type', 'name_ar', 'name_en', 'category',
        'description_ar', 'description_en', 'logo', 'cover_image',
    },
    2: {
        'governorate', 'city', 'district', 'address_ar', 'address_en',
        'latitude', 'longitude', 'location_url',
    },
    3: {
        'phone', 'whatsapp', 'email', 'website',
        'working_hours_ar', 'working_hours_en',
    },
    4: {'facebook', 'instagram', 'twitter', 'tiktok'},
}


def _active_owner_subscription(user):
    """Return the most relevant active subscription for owner-level limits."""
    return (
        Subscription.objects.filter(
            business__owner=user,
            status='active',
        )
        .select_related('plan', 'business')
        .order_by('-end_date')
        .first()
    )


def _can_create_business(user):
    """Check the current plan's owner-level business limit."""
    subscription = _active_owner_subscription(user)
    if not subscription:
        return True, None, None

    limit = subscription.plan.max_businesses
    active_count = Business.objects.filter(owner=user, is_active=True).count()
    if limit and active_count >= limit:
        return False, subscription, limit
    return True, subscription, limit


def _business_form_error_section(form, formset):
    """Return the first wizard section containing an error."""
    error_fields = set(form.errors)
    for section, fields in BUSINESS_FORM_SECTIONS.items():
        if error_fields & fields:
            return section

    if formset.non_form_errors() or any(form_errors for form_errors in formset.errors):
        return 5
    return 1


def _save_business_images(formset, business):
    """Save gallery images and assign deterministic order to new images."""
    formset.instance = business
    images = formset.save(commit=False)

    for deleted_image in formset.deleted_objects:
        deleted_image.delete()

    next_order = business.images.order_by('-order').values_list('order', flat=True).first()
    next_order = (next_order if next_order is not None else -1) + 1

    for image in images:
        if image.pk is None:
            image.order = next_order
            next_order += 1
        image.save()

    formset.save_m2m()


@login_required
def business_list(request):
    """Owner Business List V2."""
    owner_businesses = Business.objects.filter(owner=request.user)
    businesses = (
        owner_businesses
        .select_related(
            'category',
            'district__city__governorate',
            'subscription__plan',
        )
        .annotate(
            deals_count=Count('deal', distinct=True),
            reviews_count=Count('reviews', distinct=True),
        )
        .order_by('-is_active', '-updated_at')
    )

    business_type = request.GET.get('type', '').strip()
    if business_type:
        businesses = businesses.filter(business_type=business_type)

    status = request.GET.get('status', '').strip()
    if status == 'active':
        businesses = businesses.filter(is_active=True)
    elif status == 'inactive':
        businesses = businesses.filter(is_active=False)
    elif status == 'verified':
        businesses = businesses.filter(is_verified=True)
    elif status == 'unverified':
        businesses = businesses.filter(is_verified=False)

    search = request.GET.get('search', '').strip()
    if search:
        businesses = businesses.filter(
            Q(name_en__icontains=search)
            | Q(name_ar__icontains=search)
            | Q(phone__icontains=search)
            | Q(category__name_ar__icontains=search)
            | Q(category__name_en__icontains=search)
        )

    paginator = Paginator(businesses, 12)
    page_obj = paginator.get_page(request.GET.get('page'))

    can_create, current_subscription, business_limit = _can_create_business(request.user)
    active_count = owner_businesses.filter(is_active=True).count()

    context = {
        'businesses': page_obj,
        'total_count': owner_businesses.count(),
        'active_count': active_count,
        'verified_count': owner_businesses.filter(is_verified=True).count(),
        'inactive_count': owner_businesses.filter(is_active=False).count(),
        'search_query': search,
        'selected_type': business_type,
        'selected_status': status,
        'can_create_business': can_create,
        'current_subscription': current_subscription,
        'business_limit': business_limit,
        'business_limit_used': active_count,
    }
    return render(request, 'dashboard/business/list.html', context)


@login_required
def business_create(request, business_type='shop'):
    """Create a shop/craft while respecting the active plan limit."""
    if business_type not in ['shop', 'craft']:
        return redirect('dashboard:business_list')

    can_create, subscription, limit = _can_create_business(request.user)
    if not can_create:
        messages.warning(
            request,
            'وصلت للحد الأقصى من الأنشطة المسموح بها في خطتك الحالية. '
            'يمكنك ترقية الخطة أو إدارة الأنشطة الحالية أولًا.',
        )
        return redirect('subscriptions:my_subscription')

    titles = {
        'shop': {'ar': 'إضافة محل تجاري جديد', 'en': 'Add a new business', 'icon': '🏪'},
        'craft': {'ar': 'إضافة حرفة / مهنة حرة', 'en': 'Add a craft / profession', 'icon': '🔧'},
    }

    if request.method == 'POST':
        form = BusinessCreateForm(
            request.POST,
            request.FILES,
            business_type=business_type,
            user=request.user,
        )
        formset = BusinessImageFormSet(request.POST, request.FILES)
        form_is_valid = form.is_valid()
        formset_is_valid = formset.is_valid()

        if form_is_valid and formset_is_valid:
            can_create_now, _, _ = _can_create_business(request.user)
            if not can_create_now:
                messages.warning(request, 'تم الوصول إلى حد الأنشطة في الخطة الحالية.')
                return redirect('subscriptions:my_subscription')

            business = form.save(commit=False)
            business.owner = request.user
            business.business_type = business_type
            business.save()
            _save_business_images(formset, business)
            messages.success(request, f'✅ تم إضافة "{business.name_ar}" بنجاح!')
            return redirect('dashboard:business_detail', slug=business.slug)

        error_section = _business_form_error_section(form, formset)
        messages.error(request, 'لم يتم حفظ المحل. راجع الأخطاء الموضحة في النموذج.')
    else:
        form = BusinessCreateForm(business_type=business_type, user=request.user)
        formset = BusinessImageFormSet()
        error_section = 1

    return render(request, 'dashboard/business/form.html', {
        'form': form,
        'formset': formset,
        'business_type': business_type,
        'title': titles[business_type],
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'action': 'create',
        'error_section': error_section,
        'current_subscription': subscription,
        'business_limit': limit,
    })


@login_required
def business_update(request, slug):
    """Update an owner business using the existing multi-step editor."""
    business = get_object_or_404(Business, slug=slug, owner=request.user)

    if request.method == 'POST':
        form = BusinessCreateForm(
            request.POST,
            request.FILES,
            instance=business,
            user=request.user,
        )
        formset = BusinessImageFormSet(
            request.POST,
            request.FILES,
            instance=business,
        )
        form_is_valid = form.is_valid()
        formset_is_valid = formset.is_valid()

        if form_is_valid and formset_is_valid:
            form.save()
            _save_business_images(formset, business)
            messages.success(request, f'✅ تم تحديث "{business.name_ar}" بنجاح!')
            return redirect('dashboard:business_detail', slug=business.slug)

        error_section = _business_form_error_section(form, formset)
        messages.error(request, 'تعذر حفظ التعديلات. راجع الأخطاء الموضحة في النموذج.')
    else:
        form = BusinessCreateForm(instance=business, user=request.user)
        formset = BusinessImageFormSet(instance=business)
        error_section = 1

    subscription = getattr(business, 'subscription', None)
    return render(request, 'dashboard/business/form.html', {
        'form': form,
        'formset': formset,
        'business': business,
        'business_type': business.business_type,
        'title': {
            'ar': f'تعديل: {business.name_ar}',
            'en': f'Edit: {business.name_en}',
            'icon': '✏️',
        },
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'action': 'update',
        'error_section': error_section,
        'current_subscription': subscription,
    })


@login_required
def business_detail(request, slug):
    """Business Profile V2 detail page."""
    business = get_object_or_404(
        Business.objects.select_related(
            'category',
            'district__city__governorate',
            'subscription__plan',
        ).prefetch_related('images'),
        slug=slug,
        owner=request.user,
    )

    products = business.products.order_by('-created_at')[:5]
    deals = business.deals.order_by('-created_at')[:5]
    return render(request, 'dashboard/business/detail.html', {
        'business': business,
        'products': products,
        'deals': deals,
    })


@login_required
def business_delete(request, slug):
    """Delete a business owned by the authenticated user."""
    business = get_object_or_404(Business, slug=slug, owner=request.user)
    if request.method == 'POST':
        business_name = business.name_ar
        business.delete()
        messages.success(request, f'تم حذف {business_name} بنجاح!')
        return redirect('dashboard:business_list')
    return render(request, 'dashboard/business/delete.html', {'business': business})