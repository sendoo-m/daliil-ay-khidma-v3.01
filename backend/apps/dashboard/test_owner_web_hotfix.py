from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import User
from apps.categories.models import Category
from apps.directory.models import Business
from apps.directory.models.location import City, District, Governorate
from apps.notifications.models import Notification


class OwnerWebHotfixTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='owner-hotfix',
            phone='01000000111',
            password='A-strong-password-2026',
        )
        self.client.force_login(self.owner)
        governorate = Governorate.objects.create(name_en='Cairo', name_ar='القاهرة')
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
        category = Category.objects.create(name_en='Retail', name_ar='تجزئة')
        self.business = Business.objects.create(
            owner=self.owner,
            business_type='shop',
            name_en='Owner Shop',
            name_ar='محل المالك',
            category=category,
            district=district,
            phone='01000000111',
            address_en='Test address',
            address_ar='عنوان اختباري',
            description_en='Test description',
            description_ar='وصف اختباري',
            is_active=True,
        )

    def test_owner_business_list_renders(self):
        response = self.client.get(reverse('dashboard:business_list'))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'dashboard/business/list.html')
        self.assertContains(response, 'محل المالك')

    def test_owner_notifications_renders_real_notifications(self):
        Notification.objects.create(
            user=self.owner,
            notification_type='system',
            title_ar='إشعار اختبار',
            title_en='Test notification',
            body_ar='رسالة اختبار',
            body_en='Test body',
        )
        response = self.client.get(reverse('dashboard:notifications'))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'dashboard/notifications.html')
        self.assertContains(response, 'إشعار اختبار')
        self.assertContains(response, '1')
