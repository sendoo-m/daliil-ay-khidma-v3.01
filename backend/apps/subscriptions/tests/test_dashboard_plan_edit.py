from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.subscriptions.models import SubscriptionPlan


class SubscriptionPlanDashboardEditTests(TestCase):
    def setUp(self):
        self.staff = get_user_model().objects.create_user(
            username='plan-admin',
            password='test-password',
            is_staff=True,
        )
        self.plan = SubscriptionPlan.objects.create(
            name='basic',
            display_name_en='Basic',
            display_name_ar='أساسي',
            price_monthly=10,
            price_quarterly=25,
            price_semi_annual=45,
            price_annual=80,
        )
        self.url = reverse('dashboard:admin_subscription_plan_edit', args=[self.plan.id])

    def test_staff_can_open_edit_page(self):
        self.client.force_login(self.staff)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Basic')

    def test_staff_can_update_plan(self):
        self.client.force_login(self.staff)
        response = self.client.post(self.url, {
            'name': 'basic',
            'display_name_en': 'Basic Plus',
            'display_name_ar': 'أساسي بلس',
            'description_en': 'Updated plan',
            'description_ar': 'خطة محدثة',
            'price_monthly': '15.00',
            'price_quarterly': '40.00',
            'price_semi_annual': '75.00',
            'price_annual': '140.00',
            'max_products': '20',
            'max_images_per_product': '5',
            'max_business_images': '10',
            'can_upload_images': 'on',
            'can_show_prices': 'on',
            'has_social_media_links': 'on',
            'color': '#667eea',
            'icon': 'fas fa-star',
            'order': '2',
            'is_active': 'on',
        })
        self.assertRedirects(response, reverse('dashboard:admin_subscription_plans'))
        self.plan.refresh_from_db()
        self.assertEqual(self.plan.display_name_en, 'Basic Plus')
        self.assertEqual(str(self.plan.price_monthly), '15.00')

    def test_non_staff_is_redirected(self):
        user = get_user_model().objects.create_user(
            username='regular-user',
            password='test-password',
        )
        self.client.force_login(user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)
