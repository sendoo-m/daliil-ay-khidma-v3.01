"""Tests for the browser-based dashboard access and location flow."""

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import User
from apps.dashboard.forms.business_create import BusinessImageFormSet
from apps.directory.models import Business
from apps.categories.models import Category
from apps.directory.models.location import City, District, Governorate


class OwnerDashboardAccessTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='shop-owner',
            phone='01000000001',
            password='A-strong-password-2026',
        )
        self.client.force_login(self.owner)

    def test_business_create_uses_owner_dashboard_navigation(self):
        response = self.client.get(reverse('dashboard:business_create'))

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'dashboard/base.html')
        self.assertTemplateNotUsed(response, 'dashboard/admin/base.html')
        self.assertContains(response, reverse('dashboard:business_list'))
        self.assertNotContains(response, reverse('dashboard:admin_users_list'))

    def test_login_redirect_setting_targets_dashboard_router(self):
        self.client.logout()
        response = self.client.post(
            reverse('accounts:login'),
            {'username': self.owner.username, 'password': 'A-strong-password-2026'},
        )

        self.assertRedirects(
            response,
            reverse('dashboard:index'),
            fetch_redirect_response=False,
        )

    def test_invalid_business_submission_explains_errors_and_keeps_data(self):
        response = self.client.post(
            reverse('dashboard:business_create'),
            {
                'name_ar': 'محل سيظل في النموذج',
                'name_en': 'Retained business name',
                'images-TOTAL_FORMS': '0',
                'images-INITIAL_FORMS': '0',
                'images-MIN_NUM_FORMS': '0',
                'images-MAX_NUM_FORMS': '10',
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'لم يتم حفظ المحل')
        self.assertContains(response, 'محل سيظل في النموذج')
        self.assertContains(response, 'data-error-section="1"')
        self.assertFalse(Business.objects.filter(owner=self.owner).exists())

    def test_gallery_image_does_not_require_display_order(self):
        image = SimpleUploadedFile(
            'gallery.gif',
            b'GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;',
            content_type='image/gif',
        )
        formset = BusinessImageFormSet(
            data={
                'images-TOTAL_FORMS': '1',
                'images-INITIAL_FORMS': '0',
                'images-MIN_NUM_FORMS': '0',
                'images-MAX_NUM_FORMS': '10',
                'images-0-caption_ar': 'واجهة المحل',
                'images-0-caption_en': 'Business front',
            },
            files={'images-0-image': image},
        )

        self.assertTrue(formset.is_valid(), formset.errors)
        self.assertNotIn('order', formset.forms[0].fields)

    def test_owner_can_open_business_detail_page(self):
        governorate = Governorate.objects.create(
            name_en='Cairo',
            name_ar='القاهرة',
        )
        city = City.objects.create(
            governorate=governorate,
            name_en='Nasr City',
            name_ar='مدينة نصر',
        )
        district = District.objects.create(
            city=city,
            name_en='First District',
            name_ar='الحي الأول',
        )
        category = Category.objects.create(
            name_en='Travel',
            name_ar='السفر',
        )
        business = Business.objects.create(
            owner=self.owner,
            business_type='shop',
            name_en='Sendoo Travel',
            name_ar='سندو ترافيل',
            category=category,
            district=district,
            phone='01000000001',
            address_en='Test address',
            address_ar='عنوان اختباري',
            description_en='Test description',
            description_ar='وصف اختباري',
        )

        response = self.client.get(
            reverse('dashboard:business_detail', kwargs={'slug': business.slug}),
        )

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'dashboard/business/detail.html')
        self.assertTemplateUsed(response, 'dashboard/base.html')
        self.assertContains(response, 'سندو ترافيل')
        self.assertContains(
            response,
            reverse('dashboard:business_update', kwargs={'slug': business.slug}),
        )

        other_owner = User.objects.create_user(
            username='other-shop-owner',
            phone='01000000002',
            password='A-strong-password-2026',
        )
        self.client.force_login(other_owner)
        forbidden_response = self.client.get(
            reverse('dashboard:business_detail', kwargs={'slug': business.slug}),
        )
        self.assertEqual(forbidden_response.status_code, 404)


class DashboardLocationAjaxTests(TestCase):
    def setUp(self):
        self.governorate = Governorate.objects.create(
            name_en='Test Governorate',
            name_ar='محافظة اختبار',
        )
        self.active_city = City.objects.create(
            governorate=self.governorate,
            name_en='Active City',
            name_ar='مدينة نشطة',
        )
        City.objects.create(
            governorate=self.governorate,
            name_en='Inactive City',
            name_ar='مدينة غير نشطة',
            is_active=False,
        )

    def test_cities_endpoint_returns_active_cities_for_governorate(self):
        response = self.client.get(
            reverse('dashboard:ajax_cities'),
            {'governorate_id': self.governorate.pk},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {'cities': [{'id': self.active_city.pk, 'name_ar': 'مدينة نشطة'}]},
        )

    def test_business_form_uses_named_location_ajax_urls(self):
        owner = User.objects.create_user(
            username='another-owner',
            phone='01000000002',
            password='A-strong-password-2026',
        )
        self.client.force_login(owner)

        response = self.client.get(reverse('dashboard:business_create'))

        self.assertContains(response, reverse('dashboard:ajax_cities'))
        self.assertContains(response, reverse('dashboard:ajax_districts'))
        self.assertNotContains(response, '/dashboard/ajax/get-cities/')
        self.assertNotContains(response, '/dashboard/ajax/get-districts/')
