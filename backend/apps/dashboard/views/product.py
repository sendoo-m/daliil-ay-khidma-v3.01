from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.admin.views.decorators import staff_member_required  # ← مهم
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q
from django.http import HttpResponse

from apps.products.models import Product
from apps.directory.models import Business
from apps.dashboard.forms import ProductForm
from apps.api.merchant_import import (
    ImportError_,
    build_workbook,
    commit_rows,
    read_rows,
    validate_rows,
)


# ══════════════════════════════════════════
#  OWNER Views — صاحب المحل
# ══════════════════════════════════════════

@login_required
def product_list(request):
    """قائمة منتجات صاحب المحل + استيراد/تصدير Excel بنفس محرك التطبيق."""
    businesses = Business.objects.filter(owner=request.user).order_by('id')

    # ── تصدير منتجات نشاط واحد إلى Excel ──
    if request.method == 'GET' and request.GET.get('export') == 'xlsx':
        business_id = request.GET.get('business')
        business = (
            get_object_or_404(Business, pk=business_id, owner=request.user)
            if business_id
            else businesses.first()
        )
        if business is None:
            messages.warning(request, 'أضف نشاطًا أولًا قبل تنزيل ملف المنتجات.')
            return redirect('dashboard:business_create')

        workbook = build_workbook(
            Product.objects.filter(business=business).order_by('id')
        )
        response = HttpResponse(
            workbook,
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
        response['Content-Disposition'] = (
            f'attachment; filename="products-business-{business.id}.xlsx"'
        )
        return response

    bulk_report = None

    # ── رفع Excel/CSV: فحص كامل ثم حفظ ذري — لا نصف استيراد ──
    if request.method == 'POST' and request.POST.get('action') == 'bulk_import':
        business_id = request.POST.get('business')
        business = get_object_or_404(Business, pk=business_id, owner=request.user)
        uploaded_file = request.FILES.get('bulk_file')

        if uploaded_file is None:
            messages.error(request, 'اختر ملف Excel أو CSV أولًا.')
        else:
            try:
                rows = read_rows(uploaded_file)
                owned_ids = set(
                    Product.objects.filter(business=business).values_list('id', flat=True)
                )
                bulk_report = validate_rows(rows, owned_ids)
                if bulk_report['error_count']:
                    messages.error(
                        request,
                        f"الملف فيه {bulk_report['error_count']} صف يحتاج تعديل. لم يتم حفظ أي شيء.",
                    )
                else:
                    result = commit_rows(bulk_report['prepared'], business)
                    messages.success(
                        request,
                        f"تم الاستيراد بنجاح: {result['created']} جديد و{result['updated']} تم تحديثه.",
                    )
                    return redirect(f"{request.path}?business={business.id}")
            except ImportError_ as exc:
                messages.error(request, str(exc))

    products = Product.objects.filter(
        business__owner=request.user
    ).select_related('business').order_by('-created_at')

    business_id = request.GET.get('business')
    product_type = request.GET.get('type')
    status = request.GET.get('status')
    search = request.GET.get('search', '').strip()

    if business_id:
        products = products.filter(business_id=business_id)
    if product_type:
        products = products.filter(product_type=product_type)
    if status == 'available':
        products = products.filter(is_available=True)
    elif status == 'unavailable':
        products = products.filter(is_available=False)
    if search:
        products = products.filter(
            Q(name_ar__icontains=search) | Q(name_en__icontains=search)
        )

    paginator = Paginator(products, 12)
    page = paginator.get_page(request.GET.get('page', 1))
    all_prods = Product.objects.filter(business__owner=request.user)

    return render(request, 'dashboard/product/list.html', {
        'products': page,
        'businesses': businesses,
        'total_count': all_prods.count(),
        'available_count': all_prods.filter(is_available=True).count(),
        'products_count': all_prods.filter(product_type='product').count(),
        'services_count': all_prods.filter(product_type='service').count(),
        'bulk_report': bulk_report,
    })


@login_required
def product_create(request):
    """إضافة منتج جديد"""
    user_businesses = Business.objects.filter(owner=request.user)
    if not user_businesses.exists():
        messages.warning(request, 'يجب إضافة محل أولاً قبل إضافة منتجات!')
        return redirect('dashboard:business_create')

    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, user=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'تم إضافة المنتج بنجاح!')
            return redirect('dashboard:product_list')
    else:
        form = ProductForm(user=request.user)

    return render(request, 'dashboard/product/form.html', {
        'form':  form,
        'title': 'إضافة منتج جديد',
    })


@login_required
def product_update(request, slug):
    """تعديل منتج"""
    product = get_object_or_404(Product, slug=slug, business__owner=request.user)

    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, instance=product, user=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'تم تحديث المنتج بنجاح!')
            return redirect('dashboard:product_list')
    else:
        form = ProductForm(instance=product, user=request.user)

    return render(request, 'dashboard/product/form.html', {
        'form':    form,
        'product': product,
        'title':   f'تعديل {product.name_ar}',
    })


@login_required
def product_delete(request, slug):
    """حذف منتج"""
    product = get_object_or_404(Product, slug=slug, business__owner=request.user)

    if request.method == 'POST':
        name = product.name_ar
        product.delete()
        messages.success(request, f'تم حذف {name} بنجاح!')
        return redirect('dashboard:product_list')

    return render(request, 'dashboard/product/delete.html', {'product': product})


# ══════════════════════════════════════════
#  ADMIN Views — لوحة الأدمن
# ══════════════════════════════════════════

@staff_member_required
def admin_products_list(request):
    """قائمة كل المنتجات للأدمن"""
    search = request.GET.get('search', '').strip()
    type_filter = request.GET.get('type', '').strip()
    status_filter = request.GET.get('status', '').strip()

    products = Product.objects.select_related('business').order_by('-created_at')

    if search:
        products = products.filter(
            Q(name_ar__icontains=search) |
            Q(name_en__icontains=search) |
            Q(business__name_ar__icontains=search)
        )
    if type_filter:
        products = products.filter(product_type=type_filter)
    if status_filter == 'available':
        products = products.filter(is_available=True)
    elif status_filter == 'unavailable':
        products = products.filter(is_available=False)

    total_count = products.count()
    paginator = Paginator(products, 15)
    page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/products_list.html', {
        'products': page,
        'page_obj': page,
        'search': search,
        'type_filter': type_filter,
        'status_filter': status_filter,
        'total_count': total_count,
    })
