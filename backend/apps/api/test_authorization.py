"""Authorization regression tests for API v2 business-owner resources.

These tests protect object ownership boundaries. A business owner must not be
able to read, modify, delete, or create nested resources under another owner's
business, even when they can guess its primary key.
"""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.directory.models import Business, Category, City, District, Governorate


User = get_user_model()


class BusinessOwnerObjectAuthorizationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username="owner-a",
            email="owner-a@example.com",
            phone="01000000101",
            password="StrongPass123!",
            is_business_owner=True,
        )
        self.other_owner = User.objects.create_user(
            username="owner-b",
            email="owner-b@example.com",
            phone="01000000102",
            password="StrongPass123!",
            is_business_owner=True,
        )
        self.regular_user = User.objects.create_user(
            username="regular-authorization-user",
            email="regular-authorization@example.com",
            phone="01000000103",
            password="StrongPass123!",
        )

        governorate = Governorate.objects.create(
            name_en="Authorization Governorate",
            name_ar="محافظة اختبار الصلاحيات",
        )
        city = City.objects.create(
            governorate=governorate,
            name_en="Authorization City",
            name_ar="مدينة اختبار الصلاحيات",
        )
        district = District.objects.create(
            city=city,
            name_en="Authorization District",
            name_ar="حي اختبار الصلاحيات",
        )
        category = Category.objects.create(
            name_en="Authorization Category",
            name_ar="تصنيف اختبار الصلاحيات",
        )
        self.business = Business.objects.create(
            owner=self.owner,
            category=category,
            district=district,
            name_en="Owner A Business",
            name_ar="نشاط المالك الأول",
            is_active=True,
        )
        self.other_business = Business.objects.create(
            owner=self.other_owner,
            category=category,
            district=district,
            name_en="Owner B Business",
            name_ar="نشاط المالك الثاني",
            is_active=True,
        )

    def test_owner_list_contains_only_owned_businesses(self):
        self.client.force_authenticate(self.owner)
        response = self.client.get("/api/v2/business-owner/businesses/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        business_ids = {item["id"] for item in response.data["results"]}
        self.assertEqual(business_ids, {self.business.id})
        self.assertNotIn(self.other_business.id, business_ids)

    def test_owner_cannot_retrieve_another_owners_business(self):
        self.client.force_authenticate(self.owner)
        response = self.client.get(
            f"/api/v2/business-owner/businesses/{self.other_business.id}/"
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_owner_cannot_update_another_owners_business(self):
        self.client.force_authenticate(self.owner)
        original_name = self.other_business.name_en
        response = self.client.patch(
            f"/api/v2/business-owner/businesses/{self.other_business.id}/",
            {"name_en": "Unauthorized change"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.other_business.refresh_from_db()
        self.assertEqual(self.other_business.name_en, original_name)

    def test_owner_cannot_delete_another_owners_business(self):
        self.client.force_authenticate(self.owner)
        response = self.client.delete(
            f"/api/v2/business-owner/businesses/{self.other_business.id}/"
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Business.objects.filter(pk=self.other_business.pk).exists())

    def test_owner_cannot_create_product_under_another_owners_business(self):
        self.client.force_authenticate(self.owner)
        response = self.client.post(
            f"/api/v2/business-owner/businesses/{self.other_business.id}/products/",
            {
                "name_en": "Unauthorized product",
                "name_ar": "منتج غير مصرح",
                "description_en": "Must never be created under another owner.",
                "description_ar": "يجب ألا يُنشأ تحت نشاط مالك آخر.",
                "product_type": "product",
                "price": "10.00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_owner_cannot_list_reviews_for_another_owners_business(self):
        self.client.force_authenticate(self.owner)
        response = self.client.get(
            f"/api/v2/business-owner/businesses/{self.other_business.id}/reviews/"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 0)
        self.assertEqual(response.data["results"], [])

    def test_regular_user_cannot_create_a_business_through_owner_api(self):
        self.client.force_authenticate(self.regular_user)
        response = self.client.post(
            "/api/v2/business-owner/businesses/",
            {"name_en": "Unauthorized Business", "name_ar": "نشاط غير مصرح"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(Business.objects.filter(owner=self.regular_user).exists())
