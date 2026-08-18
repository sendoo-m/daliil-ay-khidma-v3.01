from django.test import SimpleTestCase
from django.urls import reverse


class StoreCompliancePagesTests(SimpleTestCase):
    def test_privacy_policy_is_public(self):
        response = self.client.get(reverse("privacy_policy"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "سياسة الخصوصية")

    def test_terms_are_public(self):
        response = self.client.get(reverse("terms_of_service"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "الشروط والأحكام")

    def test_support_is_public(self):
        response = self.client.get(reverse("support"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "الدعم والمساعدة")

    def test_account_deletion_info_is_public(self):
        response = self.client.get(reverse("account_deletion_info"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "حذف الحساب والبيانات")
