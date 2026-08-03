"""
Admin CRUD Views
================
Create, Read, Update, Delete operations for admin
"""

# ========================================
# IMPORTS
# ========================================

from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib import messages
from django.db.models import Count
from django.core.paginator import Paginator

from django.views import View
from django.contrib.auth.mixins import LoginRequiredMixin

from apps.dashboard.mixins import AdminRequiredMixin

from apps.accounts.models import User
from apps.categories.models import Category
from apps.directory.models import Business
from apps.directory.models.location import Governorate, City, District
from apps.products.models import Product
from apps.deals.models import Deal

from apps.dashboard.forms import (
    AdminUserCreateForm,
    AdminUserEditForm,
    BusinessForm,
    ProductForm,
    DealForm,
    CategoryForm,
)


# ========================================
# USER CRUD
# ========================================

@staff_member_required
def admin_user_create(request):
    """إضافة مستخدم جديد"""
    if request.method == 'POST':
        form = AdminUserCreateForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, f'✅ تم إضافة المستخدم "{user.username}" بنجاح!')
            return redirect('dashboard:admin_user_detail', user_id=user.id)
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
    else:
        form = AdminUserCreateForm()

    return render(request, 'dashboard/admin/user_form.html', {
        'form': form,
        'action': 'إضافة'
    })


@staff_member_required
def admin_user_edit_view(request, user_id):
    """تعديل مستخدم"""
    user = get_object_or_404(User, id=user_id)

    if request.method == 'POST':
        form = AdminUserEditForm(request.POST, instance=user)
        if form.is_valid():
            form.save()
            messages.success(request, '✅ تم تحديث بيانات المستخدم بنجاح!')
            return redirect('dashboard:admin_user_detail', user_id=user_id)
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
    else:
        form = AdminUserEditForm(instance=user)

    return render(request, 'dashboard/admin/user_form.html', {
        'form': form,
        'user_obj': user,
        'action': 'تعديل'
    })


# ========================================
# BUSINESS CRUD
# ========================================

@staff_member_required
def admin_business_create(request):
    """إضافة محل جديد"""
    if request.method == 'POST':
        form = BusinessForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                business = form.save(commit=False)
                business.owner = request.user
                business.save()
                messages.success(request, f'✅ تم إضافة المحل "{business.name_ar}" بنجاح!')
                return redirect('dashboard:admin_business_detail', business_id=business.id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء حفظ المحل: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = BusinessForm()

    return render(request, 'dashboard/admin/business_form.html', {
        'form': form,
        'action': 'إضافة',
        'title': 'إضافة محل جديد',
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'categories': Category.objects.filter(is_active=True).order_by('name_ar'),
    })


@staff_member_required
def admin_business_edit_view(request, business_id):
    """تعديل محل"""
    business = get_object_or_404(Business, id=business_id)

    if request.method == 'POST':
        form = BusinessForm(request.POST, request.FILES, instance=business)
        if form.is_valid():
            try:
                form.save()
                messages.success(request, f'✅ تم تحديث بيانات المحل "{business.name_ar}" بنجاح!')
                return redirect('dashboard:admin_business_detail', business_id=business_id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = BusinessForm(instance=business)

    return render(request, 'dashboard/admin/business_form.html', {
        'form': form,
        'business': business,
        'action': 'تعديل',
        'title': f'تعديل محل: {business.name_ar}',
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'categories': Category.objects.filter(is_active=True).order_by('name_ar'),
    })


# ========================================
# PRODUCT CRUD
# ========================================

@staff_member_required
def admin_product_create(request, business_id=None):
    """إضافة منتج جديد"""
    business = get_object_or_404(Business, id=business_id) if business_id else None

    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                product = form.save(commit=False)
                if business:
                    product.business = business
                if not product.business_id:
                    messages.error(request, '❌ يجب تحديد المحل التابع له المنتج')
                else:
                    product.save()
                    messages.success(request, f'✅ تم إضافة المنتج "{product.name_ar}" بنجاح!')
                    return redirect('dashboard:admin_product_detail', product_id=product.id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء حفظ المنتج: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = ProductForm()

    return render(request, 'dashboard/admin/product_form.html', {
        'form': form,
        'business': business,
        'action': 'إضافة'
    })


@staff_member_required
def admin_product_edit_view(request, product_id):
    """تعديل منتج"""
    product = get_object_or_404(Product, id=product_id)

    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, instance=product)
        if form.is_valid():
            try:
                form.save()
                messages.success(request, f'✅ تم تحديث بيانات المنتج "{product.name_ar}" بنجاح!')
                return redirect('dashboard:admin_product_detail', product_id=product_id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = ProductForm(instance=product)

    return render(request, 'dashboard/admin/product_form.html', {
        'form': form,
        'product': product,
        'action': 'تعديل'
    })


# ========================================
# CATEGORY CRUD
# ========================================

@staff_member_required
def admin_category_create_view(request):
    """إضافة تصنيف جديد"""
    if request.method == 'POST':
        form = CategoryForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                category = form.save()
                messages.success(request, f'✅ تم إضافة التصنيف "{category.name_ar}" بنجاح!')
                return redirect('dashboard:admin_categories_list')
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء حفظ التصنيف: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = CategoryForm()

    return render(request, 'dashboard/admin/category_form.html', {
        'form': form,
        'action': 'إضافة'
    })


@staff_member_required
def admin_category_edit_view(request, category_id):
    """تعديل تصنيف"""
    category = get_object_or_404(Category, id=category_id)

    if request.method == 'POST':
        form = CategoryForm(request.POST, request.FILES, instance=category)
        if form.is_valid():
            try:
                form.save()
                messages.success(request, f'✅ تم تحديث بيانات التصنيف "{category.name_ar}" بنجاح!')
                return redirect('dashboard:admin_categories_list')
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = CategoryForm(instance=category)

    return render(request, 'dashboard/admin/category_form.html', {
        'form': form,
        'category': category,
        'action': 'تعديل'
    })


# ========================================
# DEAL CRUD
# ========================================

@staff_member_required
def admin_deal_create(request, business_id=None):
    """إضافة عرض جديد"""
    business = get_object_or_404(Business, id=business_id) if business_id else None

    if request.method == 'POST':
        form = DealForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                deal = form.save(commit=False)
                if business:
                    deal.business = business
                if not deal.business_id:
                    messages.error(request, '❌ يجب تحديد المحل التابع له العرض')
                else:
                    deal.save()
                    messages.success(request, f'✅ تم إضافة العرض "{deal.title_ar}" بنجاح!')
                    return redirect('dashboard:admin_deal_detail', deal_id=deal.id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء حفظ العرض: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = DealForm()

    return render(request, 'dashboard/admin/deal_form.html', {
        'form': form,
        'business': business,
        'action': 'إضافة'
    })


@staff_member_required
def admin_deal_edit_view(request, deal_id):
    """تعديل عرض"""
    deal = get_object_or_404(Deal, id=deal_id)

    if request.method == 'POST':
        form = DealForm(request.POST, request.FILES, instance=deal)
        if form.is_valid():
            try:
                form.save()
                messages.success(request, f'✅ تم تحديث بيانات العرض "{deal.title_ar}" بنجاح!')
                return redirect('dashboard:admin_deal_detail', deal_id=deal_id)
            except Exception as e:
                messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'خطأ في {field}: {error}')
    else:
        form = DealForm(instance=deal)

    return render(request, 'dashboard/admin/deal_form.html', {
        'form': form,
        'deal': deal,
        'action': 'تعديل'
    })


# ========================================
# AJAX ENDPOINTS
# ========================================

def ajax_get_districts(request):
    """جلب الأحياء بناءً على المحافظة - للـ dropdowns المتسلسلة"""
    governorate_id = request.GET.get('governorate_id', '').strip()
    results = []

    if governorate_id:
        try:
            districts = District.objects.filter(
                city__governorate_id=governorate_id,
                is_active=True
            ).select_related('city').order_by('city__name_ar', 'name_ar')

            results = [
                {'id': d.id, 'text': f"{d.name_ar} - {d.city.name_ar}"}
                for d in districts
            ]
        except Exception:
            pass

    return JsonResponse({'results': results})


# ========================================
# LOCATION MANAGEMENT
# ========================================

# ---- Governorates ----

@staff_member_required
def admin_governorates_list(request):
    """قائمة المحافظات"""
    governorates = Governorate.objects.prefetch_related('cities').order_by('name_ar')
    return render(request, 'dashboard/admin/location/governorates_list.html', {
        'governorates': governorates
    })


@staff_member_required
def admin_governorate_create(request):
    """إضافة محافظة"""
    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar:
            messages.error(request, '❌ الاسم بالعربية مطلوب')
        elif Governorate.objects.filter(name_ar=name_ar).exists():
            messages.error(request, '❌ هذه المحافظة موجودة بالفعل')
        else:
            try:
                gov = Governorate.objects.create(
                    name_ar=name_ar, name_en=name_en, is_active=is_active
                )
                messages.success(request, f'✅ تم إضافة محافظة "{gov.name_ar}" بنجاح!')
                return redirect('dashboard:admin_governorates_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/governorate_form.html', {
        'action': 'إضافة',
        'post_data': request.POST if request.method == 'POST' else None
    })


@staff_member_required
def admin_governorate_edit(request, gov_id):
    """تعديل محافظة"""
    gov = get_object_or_404(Governorate, id=gov_id)

    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar:
            messages.error(request, '❌ الاسم بالعربية مطلوب')
        elif Governorate.objects.filter(name_ar=name_ar).exclude(pk=gov_id).exists():
            messages.error(request, '❌ يوجد محافظة أخرى بنفس الاسم')
        else:
            try:
                gov.name_ar = name_ar
                gov.name_en = name_en
                gov.is_active = is_active
                gov.save(update_fields=['name_ar', 'name_en', 'is_active', 'updated_at'])
                messages.success(request, f'✅ تم تحديث "{gov.name_ar}" بنجاح!')
                return redirect('dashboard:admin_governorates_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/governorate_form.html', {
        'action': 'تعديل',
        'obj': gov
    })


@staff_member_required
def admin_governorate_delete(request, gov_id):
    """حذف محافظة - POST فقط"""
    if request.method != 'POST':
        return redirect('dashboard:admin_governorates_list')

    gov = get_object_or_404(Governorate, id=gov_id)
    cities_count = gov.cities.count()

    if cities_count > 0:
        messages.error(request, f'❌ لا يمكن حذف "{gov.name_ar}" لأنها تحتوي على {cities_count} مدينة. احذف المدن أولاً.')
        return redirect('dashboard:admin_governorates_list')

    name = gov.name_ar
    gov.delete()
    messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
    return redirect('dashboard:admin_governorates_list')


# ---- Cities ----

@staff_member_required
def admin_cities_list(request):
    """قائمة المدن"""
    cities = City.objects.select_related('governorate').prefetch_related(
        'districts'
    ).order_by('governorate__name_ar', 'name_ar')

    gov_filter = request.GET.get('governorate', '').strip()
    if gov_filter:
        cities = cities.filter(governorate_id=gov_filter)

    return render(request, 'dashboard/admin/location/cities_list.html', {
        'cities': cities,
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'gov_filter': gov_filter,
    })


@staff_member_required
def admin_city_create(request):
    """إضافة مدينة"""
    governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')

    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        governorate_id = request.POST.get('governorate', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar or not governorate_id:
            messages.error(request, '❌ الاسم والمحافظة مطلوبان')
        elif City.objects.filter(name_ar=name_ar, governorate_id=governorate_id).exists():
            messages.error(request, '❌ هذه المدينة موجودة بالفعل في هذه المحافظة')
        else:
            try:
                city = City.objects.create(
                    name_ar=name_ar, name_en=name_en,
                    governorate_id=governorate_id, is_active=is_active
                )
                messages.success(request, f'✅ تم إضافة مدينة "{city.name_ar}" بنجاح!')
                return redirect('dashboard:admin_cities_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/city_form.html', {
        'action': 'إضافة',
        'governorates': governorates,
        'post_data': request.POST if request.method == 'POST' else None
    })


@staff_member_required
def admin_city_edit(request, city_id):
    """تعديل مدينة"""
    city = get_object_or_404(City, id=city_id)
    governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')

    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        governorate_id = request.POST.get('governorate', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar or not governorate_id:
            messages.error(request, '❌ الاسم والمحافظة مطلوبان')
        elif City.objects.filter(name_ar=name_ar, governorate_id=governorate_id).exclude(pk=city_id).exists():
            messages.error(request, '❌ يوجد مدينة أخرى بنفس الاسم في هذه المحافظة')
        else:
            try:
                city.name_ar = name_ar
                city.name_en = name_en
                city.governorate_id = governorate_id
                city.is_active = is_active
                city.save(update_fields=['name_ar', 'name_en', 'governorate', 'is_active', 'updated_at'])
                messages.success(request, f'✅ تم تحديث "{city.name_ar}" بنجاح!')
                return redirect('dashboard:admin_cities_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/city_form.html', {
        'action': 'تعديل',
        'obj': city,
        'governorates': governorates
    })


@staff_member_required
def admin_city_delete(request, city_id):
    """حذف مدينة - POST فقط"""
    if request.method != 'POST':
        return redirect('dashboard:admin_cities_list')

    city = get_object_or_404(City, id=city_id)
    districts_count = city.districts.count()

    if districts_count > 0:
        messages.error(request, f'❌ لا يمكن حذف "{city.name_ar}" لأنها تحتوي على {districts_count} حي. احذف الأحياء أولاً.')
        return redirect('dashboard:admin_cities_list')

    name = city.name_ar
    city.delete()
    messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
    return redirect('dashboard:admin_cities_list')


# ---- Districts ----

@staff_member_required
def admin_districts_list(request):
    """قائمة الأحياء"""
    districts = District.objects.select_related(
        'city', 'city__governorate'
    ).order_by('city__governorate__name_ar', 'city__name_ar', 'name_ar')

    gov_filter = request.GET.get('governorate', '').strip()
    city_filter = request.GET.get('city', '').strip()

    if gov_filter:
        districts = districts.filter(city__governorate_id=gov_filter)
    if city_filter:
        districts = districts.filter(city_id=city_filter)

    paginator = Paginator(districts, 30)
    districts_page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'dashboard/admin/location/districts_list.html', {
        'districts': districts_page,
        'governorates': Governorate.objects.filter(is_active=True).order_by('name_ar'),
        'cities': City.objects.filter(is_active=True).select_related('governorate').order_by(
            'governorate__name_ar', 'name_ar'
        ),
        'gov_filter': gov_filter,
        'city_filter': city_filter,
    })


@staff_member_required
def admin_district_create(request):
    """إضافة حي"""
    governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
    cities = City.objects.filter(is_active=True).select_related('governorate').order_by(
        'governorate__name_ar', 'name_ar'
    )

    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        city_id = request.POST.get('city', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar or not city_id:
            messages.error(request, '❌ الاسم والمدينة مطلوبان')
        elif District.objects.filter(name_ar=name_ar, city_id=city_id).exists():
            messages.error(request, '❌ هذا الحي موجود بالفعل في هذه المدينة')
        else:
            try:
                district = District.objects.create(
                    name_ar=name_ar, name_en=name_en,
                    city_id=city_id, is_active=is_active
                )
                messages.success(request, f'✅ تم إضافة حي "{district.name_ar}" بنجاح!')
                return redirect('dashboard:admin_districts_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/district_form.html', {
        'action': 'إضافة',
        'governorates': governorates,
        'cities': cities,
        'post_data': request.POST if request.method == 'POST' else None
    })


@staff_member_required
def admin_district_edit(request, district_id):
    """تعديل حي"""
    district = get_object_or_404(District, id=district_id)
    governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
    cities = City.objects.filter(is_active=True).select_related('governorate').order_by(
        'governorate__name_ar', 'name_ar'
    )

    if request.method == 'POST':
        name_ar = request.POST.get('name_ar', '').strip()
        name_en = request.POST.get('name_en', '').strip()
        city_id = request.POST.get('city', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name_ar or not city_id:
            messages.error(request, '❌ الاسم والمدينة مطلوبان')
        elif District.objects.filter(name_ar=name_ar, city_id=city_id).exclude(pk=district_id).exists():
            messages.error(request, '❌ يوجد حي آخر بنفس الاسم في هذه المدينة')
        else:
            try:
                district.name_ar = name_ar
                district.name_en = name_en
                district.city_id = city_id
                district.is_active = is_active
                district.save(update_fields=['name_ar', 'name_en', 'city', 'is_active', 'updated_at'])
                messages.success(request, f'✅ تم تحديث "{district.name_ar}" بنجاح!')
                return redirect('dashboard:admin_districts_list')
            except Exception as e:
                messages.error(request, f'❌ خطأ: {str(e)}')

    return render(request, 'dashboard/admin/location/district_form.html', {
        'action': 'تعديل',
        'obj': district,
        'governorates': governorates,
        'cities': cities
    })


@staff_member_required
def admin_district_delete(request, district_id):
    """حذف حي - POST فقط"""
    if request.method != 'POST':
        return redirect('dashboard:admin_districts_list')

    district = get_object_or_404(District, id=district_id)
    businesses_count = district.businesses.count()

    if businesses_count > 0:
        messages.error(request, f'❌ لا يمكن حذف "{district.name_ar}" لأنه يحتوي على {businesses_count} محل. انقل المحلات أولاً.')
        return redirect('dashboard:admin_districts_list')

    name = district.name_ar
    district.delete()
    messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
    return redirect('dashboard:admin_districts_list')

from apps.core.models import SiteSettings
from apps.core.serializers import SiteSettingsSerializer

class AdminSettingsView(AdminRequiredMixin, View):
    template_name = "dashboard/admin/settings.html"

    def get(self, request):
        settings = SiteSettings.get_settings()
        return render(request, self.template_name, {"settings": settings})

    def post(self, request):
        settings = SiteSettings.get_settings()
        data = request.POST.copy()

        # حذف اللوجو لو طُلب
        if request.POST.get("delete_logo"):
            if settings.logo:
                settings.logo.delete()

        # حذف الفافيكون لو طُلب
        if request.POST.get("delete_favicon"):
            if settings.favicon:
                settings.favicon.delete()

        # تحديث الحقول النصية
        fields = [
            "site_name_ar", "site_name_en",
            "site_description_ar", "site_description_en",
            "contact_email", "contact_phone", "address",
            "facebook", "instagram", "twitter", "whatsapp", "youtube",
            "results_per_page", "meta_description",
            "meta_keywords", "google_analytics_id", "google_maps_key",
        ]
        for field in fields:
            if field in data:
                setattr(settings, field, data[field])

        # البولeans
        settings.maintenance_mode        = "maintenance_mode" in request.POST
        settings.allow_registration      = "allow_registration" in request.POST
        settings.allow_reviews           = "allow_reviews" in request.POST
        settings.require_review_approval = "require_review_approval" in request.POST

        # الصور
        if "logo" in request.FILES:
            settings.logo = request.FILES["logo"]
        if "favicon" in request.FILES:
            settings.favicon = request.FILES["favicon"]

        settings.save()
        messages.success(request, "✅ تم حفظ الإعدادات بنجاح!")
        return redirect("dashboard:settings")

# """
# Admin CRUD Views
# ================
# Create, Read, Update, Delete operations for admin
# """
# from django.shortcuts import render, redirect, get_object_or_404
# from django.http import JsonResponse
# from django.contrib.admin.views.decorators import staff_member_required
# from django.contrib import messages
# from django.db import transaction
# from django.utils.translation import gettext_lazy as _
# from django.db.models import Count
# from apps.accounts.models import User
# from apps.directory.models import Business
# from apps.products.models import Product
# from apps.deals.models import Deal

# from apps.directory.models.location import Governorate, City, District

# # احذف أي import قديم لـ CategoryForm
# # وأضف ده في أول الملف بشكل صريح
# from apps.dashboard.forms import (
#     AdminUserCreateForm,
#     AdminUserEditForm,
#     BusinessForm,
#     ProductForm,
#     DealForm,
# )
# # CategoryForm منفصلة عشان نتأكد
# from apps.dashboard.forms import CategoryForm as CategoryForm


# # ========================================
# # USER CRUD
# # ========================================

# @staff_member_required
# def admin_user_create(request):
#     """إضافة مستخدم جديد"""
#     if request.method == 'POST':
#         form = AdminUserCreateForm(request.POST)
#         if form.is_valid():
#             user = form.save()
#             messages.success(request, f'تم إضافة المستخدم {user.username} بنجاح')
#             return redirect('dashboard:admin_user_detail', user_id=user.id)
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'{field}: {error}')
#     else:
#         form = AdminUserCreateForm()
    
#     return render(request, 'dashboard/admin/user_form.html', {'form': form, 'action': 'إضافة'})

# @staff_member_required
# def admin_user_edit_view(request, user_id):
#     """تعديل مستخدم"""
#     user = get_object_or_404(User, id=user_id)
    
#     if request.method == 'POST':
#         form = AdminUserEditForm(request.POST, instance=user)
#         if form.is_valid():
#             form.save()
#             messages.success(request, 'تم تحديث بيانات المستخدم بنجاح')
#             return redirect('dashboard:admin_user_detail', user_id=user_id)
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'{field}: {error}')
#     else:
#         form = AdminUserEditForm(instance=user)
    
#     return render(request, 'dashboard/admin/user_form.html', {
#         'form': form,
#         'user_obj': user,
#         'action': 'تعديل'
#     })

# # ========================================
# # BUSINESS CRUD
# # ========================================

# @staff_member_required
# def admin_business_create(request):
#     """إضافة محل جديد"""
#     if request.method == 'POST':
#         form = BusinessForm(request.POST, request.FILES)
#         if form.is_valid():
#             try:
#                 business = form.save(commit=False)
#                 business.owner = request.user
#                 business.save()
#                 messages.success(request, f'✅ تم إضافة المحل "{business.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_business_detail', business_id=business.id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء حفظ المحل: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = BusinessForm()
    
#     governorates = Governorate.objects.filter(is_active=True)
#     categories = Category.objects.all()
    
#     return render(request, 'dashboard/admin/business_form.html', {
#         'form': form, 
#         'action': 'إضافة',
#         'title': 'إضافة محل جديد',
#         'governorates': governorates,
#         'categories': categories
#     })

# @staff_member_required
# def admin_business_edit_view(request, business_id):
#     """تعديل محل"""
#     business = get_object_or_404(Business, id=business_id)
    
#     if request.method == 'POST':
#         form = BusinessForm(request.POST, request.FILES, instance=business)
#         if form.is_valid():
#             try:
#                 form.save()
#                 messages.success(request, f'✅ تم تحديث بيانات المحل "{business.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_business_detail', business_id=business_id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = BusinessForm(instance=business)
    
#     governorates = Governorate.objects.filter(is_active=True)
#     categories = Category.objects.all()
    
#     return render(request, 'dashboard/admin/business_form.html', {
#         'form': form,
#         'business': business,
#         'action': 'تعديل',
#         'title': f'تعديل محل: {business.name_ar}',
#         'governorates': governorates,
#         'categories': categories
#     })

# # ========================================
# # PRODUCT CRUD
# # ========================================

# @staff_member_required
# def admin_product_create(request, business_id=None):
#     """إضافة منتج جديد"""
#     business = None
#     if business_id:
#         business = get_object_or_404(Business, id=business_id)
    
#     if request.method == 'POST':
#         form = ProductForm(request.POST, request.FILES)
#         if form.is_valid():
#             try:
#                 product = form.save(commit=False)
#                 if business:
#                     product.business = business
#                 elif not product.business:
#                     messages.error(request, '❌ يجب تحديد المحل التابع له المنتج')
#                     return render(request, 'dashboard/admin/product_form.html', {
#                         'form': form,
#                         'business': business,
#                         'action': 'إضافة'
#                     })
#                 product.save()
#                 messages.success(request, f'✅ تم إضافة المنتج "{product.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_product_detail', product_id=product.id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء حفظ المنتج: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = ProductForm()
    
#     return render(request, 'dashboard/admin/product_form.html', {
#         'form': form,
#         'business': business,
#         'action': 'إضافة'
#     })

# @staff_member_required
# def admin_product_edit_view(request, product_id):
#     """تعديل منتج"""
#     product = get_object_or_404(Product, id=product_id)
    
#     if request.method == 'POST':
#         form = ProductForm(request.POST, request.FILES, instance=product)
#         if form.is_valid():
#             try:
#                 form.save()
#                 messages.success(request, f'✅ تم تحديث بيانات المنتج "{product.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_product_detail', product_id=product_id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = ProductForm(instance=product)
    
#     return render(request, 'dashboard/admin/product_form.html', {
#         'form': form,
#         'product': product,
#         'action': 'تعديل'
#     })

# # ========================================
# # CATEGORY CRUD
# # ========================================

# @staff_member_required
# def admin_category_create_view(request):
#     """إضافة تصنيف جديد"""
#     if request.method == 'POST':
#         form = CategoryForm(request.POST, request.FILES)
#         if form.is_valid():
#             try:
#                 category = form.save()
#                 messages.success(request, f'✅ تم إضافة التصنيف "{category.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_categories_list')
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء حفظ التصنيف: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = CategoryForm()
    
#     return render(request, 'dashboard/admin/category_form.html', {'form': form, 'action': 'إضافة'})

# @staff_member_required
# def admin_category_edit_view(request, category_id):
#     """تعديل تصنيف"""
#     category = get_object_or_404(Category, id=category_id)
    
#     if request.method == 'POST':
#         form = CategoryForm(request.POST, request.FILES, instance=category)
#         if form.is_valid():
#             try:
#                 form.save()
#                 messages.success(request, f'✅ تم تحديث بيانات التصنيف "{category.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_categories_list')
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = CategoryForm(instance=category)
    
#     return render(request, 'dashboard/admin/category_form.html', {
#         'form': form,
#         'category': category,
#         'action': 'تعديل'
#     })

# # ========================================
# # DEAL CRUD
# # ========================================

# @staff_member_required
# def admin_deal_create(request, business_id=None):
#     """إضافة عرض جديد"""
#     business = None
#     if business_id:
#         business = get_object_or_404(Business, id=business_id)
    
#     if request.method == 'POST':
#         form = DealForm(request.POST, request.FILES)
#         if form.is_valid():
#             try:
#                 deal = form.save(commit=False)
#                 if business:
#                     deal.business = business
#                 elif not deal.business:
#                     messages.error(request, '❌ يجب تحديد المحل التابع له العرض')
#                     return render(request, 'dashboard/admin/deal_form.html', {
#                         'form': form,
#                         'business': business,
#                         'action': 'إضافة'
#                     })
#                 deal.save()
#                 messages.success(request, f'✅ تم إضافة العرض "{deal.title_ar}" بنجاح!')
#                 return redirect('dashboard:admin_deal_detail', deal_id=deal.id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء حفظ العرض: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = DealForm()
    
#     return render(request, 'dashboard/admin/deal_form.html', {
#         'form': form,
#         'business': business,
#         'action': 'إضافة'
#     })

# @staff_member_required
# def admin_deal_edit_view(request, deal_id):
#     """تعديل عرض"""
#     deal = get_object_or_404(Deal, id=deal_id)
    
#     if request.method == 'POST':
#         form = DealForm(request.POST, request.FILES, instance=deal)
#         if form.is_valid():
#             try:
#                 form.save()
#                 messages.success(request, f'✅ تم تحديث بيانات العرض "{deal.title_ar}" بنجاح!')
#                 return redirect('dashboard:admin_deal_detail', deal_id=deal_id)
#             except Exception as e:
#                 messages.error(request, f'❌ حدث خطأ أثناء التحديث: {str(e)}')
#         else:
#             for field, errors in form.errors.items():
#                 for error in errors:
#                     messages.error(request, f'خطأ في {field}: {error}')
#     else:
#         form = DealForm(instance=deal)
    
#     return render(request, 'dashboard/admin/deal_form.html', {
#         'form': form,
#         'deal': deal,
#         'action': 'تعديل'
#     })


# # ==========================================
# # AJAX Views
# # ==========================================

# def ajax_get_districts(request):
#     """
#     AJAX endpoint to get districts based on governorate
#     Used in business forms for cascading dropdowns
#     """
#     governorate_id = request.GET.get('governorate_id')
#     results = []
    
#     if governorate_id:
#         try:
#             # Get all districts for cities in the selected governorate
#             districts = District.objects.filter(
#                 city__governorate_id=governorate_id,
#                 is_active=True
#             ).select_related('city').order_by('city__name_ar', 'name_ar')
            
#             results = [
#                 {
#                     'id': district.id,
#                     'text': f"{district.name_ar} - {district.city.name_ar}"
#                 }
#                 for district in districts
#             ]
#         except Exception as e:
#             pass
    
#     return JsonResponse({'results': results})

# # ========================================
# # LOCATION MANAGEMENT (Governorate / City / District)
# # ========================================

# @staff_member_required
# def admin_governorates_list(request):
#     """قائمة المحافظات - بدون annotate لتجنب تعارض @property"""
#     governorates = Governorate.objects.prefetch_related('cities').order_by('name_ar')
#     return render(request, 'dashboard/admin/location/governorates_list.html', {
#         'governorates': governorates
#     })


# @staff_member_required
# def admin_governorate_create(request):
#     """إضافة محافظة"""
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar:
#             messages.error(request, '❌ الاسم بالعربية مطلوب')
#         elif Governorate.objects.filter(name_ar=name_ar).exists():
#             messages.error(request, '❌ هذه المحافظة موجودة بالفعل')
#         else:
#             try:
#                 gov = Governorate.objects.create(
#                     name_ar=name_ar,
#                     name_en=name_en,
#                     is_active=is_active
#                 )
#                 messages.success(request, f'✅ تم إضافة محافظة "{gov.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_governorates_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/governorate_form.html', {
#         'action': 'إضافة',
#         'post_data': request.POST if request.method == 'POST' else None
#     })


# @staff_member_required
# def admin_governorate_edit(request, gov_id):
#     """تعديل محافظة"""
#     gov = get_object_or_404(Governorate, id=gov_id)
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar:
#             messages.error(request, '❌ الاسم بالعربية مطلوب')
#         elif Governorate.objects.filter(name_ar=name_ar).exclude(pk=gov_id).exists():
#             messages.error(request, '❌ يوجد محافظة أخرى بنفس الاسم')
#         else:
#             try:
#                 gov.name_ar = name_ar
#                 gov.name_en = name_en
#                 gov.is_active = is_active
#                 gov.save(update_fields=['name_ar', 'name_en', 'is_active', 'updated_at'])
#                 messages.success(request, f'✅ تم تحديث "{gov.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_governorates_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/governorate_form.html', {
#         'action': 'تعديل',
#         'obj': gov
#     })


# @staff_member_required
# def admin_governorate_delete(request, gov_id):
#     """حذف محافظة - POST فقط"""
#     if request.method != 'POST':
#         return redirect('dashboard:admin_governorates_list')
#     gov = get_object_or_404(Governorate, id=gov_id)
#     # منع الحذف لو فيه مدن مرتبطة
#     cities_count = gov.cities.count()
#     if cities_count > 0:
#         messages.error(request, f'❌ لا يمكن حذف "{gov.name_ar}" لأنها تحتوي على {cities_count} مدينة. احذف المدن أولاً.')
#         return redirect('dashboard:admin_governorates_list')
#     name = gov.name_ar
#     gov.delete()
#     messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
#     return redirect('dashboard:admin_governorates_list')


# # ---- Cities ----

# @staff_member_required
# def admin_cities_list(request):
#     """قائمة المدن"""
#     cities = City.objects.select_related('governorate').prefetch_related('districts').order_by(
#         'governorate__name_ar', 'name_ar'
#     )
#     gov_filter = request.GET.get('governorate', '').strip()
#     if gov_filter:
#         cities = cities.filter(governorate_id=gov_filter)

#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     return render(request, 'dashboard/admin/location/cities_list.html', {
#         'cities': cities,
#         'governorates': governorates,
#         'gov_filter': gov_filter,
#     })


# @staff_member_required
# def admin_city_create(request):
#     """إضافة مدينة"""
#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         governorate_id = request.POST.get('governorate', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar or not governorate_id:
#             messages.error(request, '❌ الاسم والمحافظة مطلوبان')
#         elif City.objects.filter(name_ar=name_ar, governorate_id=governorate_id).exists():
#             messages.error(request, '❌ هذه المدينة موجودة بالفعل في هذه المحافظة')
#         else:
#             try:
#                 city = City.objects.create(
#                     name_ar=name_ar,
#                     name_en=name_en,
#                     governorate_id=governorate_id,
#                     is_active=is_active
#                 )
#                 messages.success(request, f'✅ تم إضافة مدينة "{city.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_cities_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/city_form.html', {
#         'action': 'إضافة',
#         'governorates': governorates,
#         'post_data': request.POST if request.method == 'POST' else None
#     })


# @staff_member_required
# def admin_city_edit(request, city_id):
#     """تعديل مدينة"""
#     city = get_object_or_404(City, id=city_id)
#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         governorate_id = request.POST.get('governorate', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar or not governorate_id:
#             messages.error(request, '❌ الاسم والمحافظة مطلوبان')
#         elif City.objects.filter(name_ar=name_ar, governorate_id=governorate_id).exclude(pk=city_id).exists():
#             messages.error(request, '❌ يوجد مدينة أخرى بنفس الاسم في هذه المحافظة')
#         else:
#             try:
#                 city.name_ar = name_ar
#                 city.name_en = name_en
#                 city.governorate_id = governorate_id
#                 city.is_active = is_active
#                 city.save(update_fields=['name_ar', 'name_en', 'governorate', 'is_active', 'updated_at'])
#                 messages.success(request, f'✅ تم تحديث "{city.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_cities_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/city_form.html', {
#         'action': 'تعديل',
#         'obj': city,
#         'governorates': governorates
#     })


# @staff_member_required
# def admin_city_delete(request, city_id):
#     """حذف مدينة - POST فقط"""
#     if request.method != 'POST':
#         return redirect('dashboard:admin_cities_list')
#     city = get_object_or_404(City, id=city_id)
#     districts_count = city.districts.count()
#     if districts_count > 0:
#         messages.error(request, f'❌ لا يمكن حذف "{city.name_ar}" لأنها تحتوي على {districts_count} حي. احذف الأحياء أولاً.')
#         return redirect('dashboard:admin_cities_list')
#     name = city.name_ar
#     city.delete()
#     messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
#     return redirect('dashboard:admin_cities_list')


# # ---- Districts ----

# @staff_member_required
# def admin_districts_list(request):
#     """قائمة الأحياء"""
#     from django.core.paginator import Paginator

#     districts = District.objects.select_related(
#         'city', 'city__governorate'
#     ).order_by('city__governorate__name_ar', 'city__name_ar', 'name_ar')

#     gov_filter = request.GET.get('governorate', '').strip()
#     city_filter = request.GET.get('city', '').strip()
#     if gov_filter:
#         districts = districts.filter(city__governorate_id=gov_filter)
#     if city_filter:
#         districts = districts.filter(city_id=city_filter)

#     paginator = Paginator(districts, 30)
#     page = request.GET.get('page', 1)
#     districts_page = paginator.get_page(page)

#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     cities = City.objects.filter(is_active=True).select_related('governorate').order_by(
#         'governorate__name_ar', 'name_ar'
#     )
#     return render(request, 'dashboard/admin/location/districts_list.html', {
#         'districts': districts_page,
#         'governorates': governorates,
#         'cities': cities,
#         'gov_filter': gov_filter,
#         'city_filter': city_filter,
#     })


# @staff_member_required
# def admin_district_create(request):
#     """إضافة حي"""
#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     cities = City.objects.filter(is_active=True).select_related('governorate').order_by(
#         'governorate__name_ar', 'name_ar'
#     )
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         city_id = request.POST.get('city', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar or not city_id:
#             messages.error(request, '❌ الاسم والمدينة مطلوبان')
#         elif District.objects.filter(name_ar=name_ar, city_id=city_id).exists():
#             messages.error(request, '❌ هذا الحي موجود بالفعل في هذه المدينة')
#         else:
#             try:
#                 district = District.objects.create(
#                     name_ar=name_ar,
#                     name_en=name_en,
#                     city_id=city_id,
#                     is_active=is_active
#                 )
#                 messages.success(request, f'✅ تم إضافة حي "{district.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_districts_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/district_form.html', {
#         'action': 'إضافة',
#         'governorates': governorates,
#         'cities': cities,
#         'post_data': request.POST if request.method == 'POST' else None
#     })


# @staff_member_required
# def admin_district_edit(request, district_id):
#     """تعديل حي"""
#     district = get_object_or_404(District, id=district_id)
#     governorates = Governorate.objects.filter(is_active=True).order_by('name_ar')
#     cities = City.objects.filter(is_active=True).select_related('governorate').order_by(
#         'governorate__name_ar', 'name_ar'
#     )
#     if request.method == 'POST':
#         name_ar = request.POST.get('name_ar', '').strip()
#         name_en = request.POST.get('name_en', '').strip()
#         city_id = request.POST.get('city', '').strip()
#         is_active = request.POST.get('is_active') == 'on'
#         if not name_ar or not city_id:
#             messages.error(request, '❌ الاسم والمدينة مطلوبان')
#         elif District.objects.filter(name_ar=name_ar, city_id=city_id).exclude(pk=district_id).exists():
#             messages.error(request, '❌ يوجد حي آخر بنفس الاسم في هذه المدينة')
#         else:
#             try:
#                 district.name_ar = name_ar
#                 district.name_en = name_en
#                 district.city_id = city_id
#                 district.is_active = is_active
#                 district.save(update_fields=['name_ar', 'name_en', 'city', 'is_active', 'updated_at'])
#                 messages.success(request, f'✅ تم تحديث "{district.name_ar}" بنجاح!')
#                 return redirect('dashboard:admin_districts_list')
#             except Exception as e:
#                 messages.error(request, f'❌ خطأ: {str(e)}')
#     return render(request, 'dashboard/admin/location/district_form.html', {
#         'action': 'تعديل',
#         'obj': district,
#         'governorates': governorates,
#         'cities': cities
#     })


# @staff_member_required
# def admin_district_delete(request, district_id):
#     """حذف حي - POST فقط"""
#     if request.method != 'POST':
#         return redirect('dashboard:admin_districts_list')
#     district = get_object_or_404(District, id=district_id)
#     # منع الحذف لو فيه محلات مرتبطة
#     businesses_count = district.businesses.count()
#     if businesses_count > 0:
#         messages.error(request, f'❌ لا يمكن حذف "{district.name_ar}" لأنه يحتوي على {businesses_count} محل. انقل المحلات أولاً.')
#         return redirect('dashboard:admin_districts_list')
#     name = district.name_ar
#     district.delete()
#     messages.success(request, f'✅ تم حذف "{name}" بنجاح!')
#     return redirect('dashboard:admin_districts_list')
