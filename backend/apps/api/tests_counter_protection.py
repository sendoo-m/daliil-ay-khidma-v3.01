from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.directory.models import Business, Category, City, District, Governorate


User = get_user_model()


class BusinessInteractionCounterProtectionTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        owner = User.objects.create_user(
            username='counter-owner',
            email='counter-owner@example.com',
            phone='01000000901',
            password='StrongPass123!',
            is_business_owner=True,
        )
        governorate = Governorate.objects.create(
            name_en='Counter Governorate',
            name_ar='محافظة العدادات',
        )
        city = City.objects.create(
            governorate=governorate,
            name_en='Counter City',
            name_ar='مدينة العدادات',
        )
        district = District.objects.create(
            city=city,
            name_en='Counter District',
            name_ar='حي العدادات',
        )
        category = Category.objects.create(
            name_en='Counter Category',
            name_ar='تصنيف العدادات',
        )
        self.business = Business.objects.create(
            owner=owner,
            category=category,
            district=district,
            name_en='Counter Business',
            name_ar='نشاط العدادات',
            is_active=True,
            is_verified=True,
        )

    def tearDown(self):
        cache.clear()

    def test_duplicate_view_from_same_ip_is_throttled_and_counted_once(self):
        url = f'/api/v2/businesses/{self.business.slug}/increment_view/'

        first = self.client.post(url, REMOTE_ADDR='198.51.100.10')
        second = self.client.post(url, REMOTE_ADDR='198.51.100.10')

        self.business.refresh_from_db()
        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertEqual(self.business.view_count, 1)

    def test_different_ip_can_record_an_independent_view(self):
        url = f'/api/v2/businesses/{self.business.slug}/increment_view/'

        first = self.client.post(url, REMOTE_ADDR='198.51.100.11')
        second = self.client.post(url, REMOTE_ADDR='198.51.100.12')

        self.business.refresh_from_db()
        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(self.business.view_count, 2)

    def test_view_and_click_are_deduplicated_independently(self):
        view_url = f'/api/v2/businesses/{self.business.slug}/increment_view/'
        click_url = f'/api/v2/businesses/{self.business.slug}/increment_click/'

        view = self.client.post(view_url, REMOTE_ADDR='198.51.100.13')
        click = self.client.post(click_url, REMOTE_ADDR='198.51.100.13')

        self.business.refresh_from_db()
        self.assertEqual(view.status_code, status.HTTP_200_OK)
        self.assertEqual(click.status_code, status.HTTP_200_OK)
        self.assertEqual(self.business.view_count, 1)
        self.assertEqual(self.business.click_count, 1)
