from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.categories.models import Category
from apps.directory.models import Business
from apps.directory.models.location import City, District, Governorate
from apps.subscriptions.models import MerchantOnboarding, Subscription, SubscriptionPlan


class MerchantOnboardingApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='new-merchant',
            phone='01011111111',
            password='Strong-pass-2026',
        )
        self.other_user = User.objects.create_user(
            username='other-owner',
            phone='01022222222',
            password='Strong-pass-2026',
        )
        self.client.force_authenticate(self.user)
        self.free_plan = SubscriptionPlan.objects.create(
            name='free',
            display_name_en='Free',
            display_name_ar='مجانية',
            price_monthly=0,
            price_quarterly=0,
            price_semi_annual=0,
            price_annual=0,
            max_businesses=1,
            max_products=3,
            can_create_deals=False,
        )
        self.premium_plan = SubscriptionPlan.objects.create(
            name='premium',
            display_name_en='Premium',
            display_name_ar='مميزة',
            price_monthly=100,
            price_quarterly=270,
            price_semi_annual=500,
            price_annual=900,
            max_businesses=3,
            max_products=50,
            can_create_deals=True,
        )
        governorate = Governorate.objects.create(name_en='Cairo', name_ar='القاهرة')
        city = City.objects.create(
            governorate=governorate,
            name_en='Nasr City',
            name_ar='مدينة نصر',
        )
        self.district = District.objects.create(
            city=city,
            name_en='First District',
            name_ar='الحي الأول',
        )
        self.category = Category.objects.create(name_en='Services', name_ar='خدمات')

    def make_business(self, owner=None, name='Merchant Business'):
        owner = owner or self.user
        return Business.objects.create(
            owner=owner,
            business_type='shop',
            name_en=name,
            name_ar='نشاط تجريبي',
            category=self.category,
            district=self.district,
            phone='01012345678',
            address_en='Test address',
            address_ar='عنوان تجريبي',
            description_en='Test description',
            description_ar='وصف تجريبي',
        )

    def test_get_creates_singleton_draft_journey(self):
        response = self.client.get('/api/v2/onboarding/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'draft')
        self.assertEqual(response.data['next_action'], 'select_plan')
        self.assertEqual(MerchantOnboarding.objects.filter(user=self.user).count(), 1)

        second = self.client.get('/api/v2/onboarding/')
        self.assertEqual(second.data['id'], response.data['id'])
        self.assertEqual(MerchantOnboarding.objects.filter(user=self.user).count(), 1)

    def test_paid_plan_journey_moves_to_admin_review(self):
        selected = self.client.post(
            '/api/v2/onboarding/select-plan/',
            {'plan_id': self.premium_plan.id, 'billing_period': 'quarterly'},
            format='json',
        )
        self.assertEqual(selected.status_code, status.HTTP_200_OK)
        self.assertTrue(selected.data['payment_required'])
        self.assertEqual(selected.data['selected_price'], 270.0)
        self.assertEqual(selected.data['next_action'], 'create_business')

        business = self.make_business()
        attached = self.client.post(
            '/api/v2/onboarding/attach-business/',
            {'business_id': business.id},
            format='json',
        )
        self.assertEqual(attached.status_code, status.HTTP_200_OK)
        self.assertEqual(attached.data['next_action'], 'submit_payment')

        paid = self.client.post(
            '/api/v2/onboarding/payment/',
            {
                'payment_method': 'bank_transfer',
                'payment_reference': 'TX-2026-001',
            },
            format='json',
        )
        self.assertEqual(paid.status_code, status.HTTP_200_OK)
        self.assertEqual(paid.data['payment_status'], 'submitted')
        self.assertEqual(paid.data['status'], 'admin_review')
        self.assertEqual(paid.data['next_action'], 'await_admin_review')

    def test_free_plan_never_requires_fake_payment(self):
        selected = self.client.post(
            '/api/v2/onboarding/select-plan/',
            {'plan_id': self.free_plan.id, 'billing_period': 'monthly'},
            format='json',
        )
        self.assertEqual(selected.status_code, status.HTTP_200_OK)
        self.assertFalse(selected.data['payment_required'])
        self.assertEqual(selected.data['payment_status'], 'not_required')

        business = self.make_business()
        attached = self.client.post(
            '/api/v2/onboarding/attach-business/',
            {'business_id': business.id},
            format='json',
        )
        self.assertEqual(attached.data['next_action'], 'await_admin_review')
        payment_item = next(
            item for item in attached.data['checklist']
            if item['key'] == 'payment_submitted'
        )
        self.assertEqual(payment_item['state'], 'not_applicable')

        payment = self.client.post(
            '/api/v2/onboarding/payment/',
            {'payment_method': 'cash'},
            format='json',
        )
        self.assertEqual(payment.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_attach_someone_elses_business(self):
        self.client.post(
            '/api/v2/onboarding/select-plan/',
            {'plan_id': self.free_plan.id},
            format='json',
        )
        other_business = self.make_business(owner=self.other_user, name='Other Business')

        response = self.client.post(
            '/api/v2/onboarding/attach-business/',
            {'business_id': other_business.id},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_existing_active_merchant_is_backfilled_and_uses_change_workflow(self):
        business = self.make_business()
        Subscription.objects.create(
            business=business,
            plan=self.premium_plan,
            start_date=timezone.now() - timedelta(days=2),
            end_date=timezone.now() + timedelta(days=28),
            status='active',
            amount_paid=100,
            payment_method='cash',
        )

        state = self.client.get('/api/v2/onboarding/')
        self.assertEqual(state.status_code, status.HTTP_200_OK)
        self.assertEqual(state.data['business']['id'], business.id)
        self.assertEqual(state.data['selected_plan']['id'], self.premium_plan.id)
        self.assertIsNotNone(state.data['subscription'])

        change_attempt = self.client.post(
            '/api/v2/onboarding/select-plan/',
            {'plan_id': self.free_plan.id},
            format='json',
        )
        self.assertEqual(change_attempt.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(change_attempt.data['code'], 'active_subscription_exists')
