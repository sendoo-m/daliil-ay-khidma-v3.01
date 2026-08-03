"""Regression tests for the mobile API v2 contract."""

from django.contrib.auth import get_user_model
from django.core import mail
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from io import BytesIO
from PIL import Image
from urllib.parse import parse_qs, urlparse
from rest_framework import serializers, status
from rest_framework.test import APIClient
from apps.api.validators import validate_image_upload
from apps.deals.models import Deal, DealClaim
from apps.directory.models import Business, Category, City, District, Favorite, Governorate
from apps.reviews.models import Review, ReviewLike, ReviewReport
from apps.core.models import SiteSettings
from apps.notifications.models import DeviceRegistration, Notification


User = get_user_model()


class MobileApiV2AuthenticationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='mobile-user',
            email='mobile@example.com',
            phone='01000000001',
            password='StrongPass123!',
        )

    def test_login_token_authenticates_profile_request(self):
        login = self.client.post(
            '/api/v2/auth/login/',
            {'username': self.user.username, 'password': 'StrongPass123!'},
            format='json',
        )

        self.assertEqual(login.status_code, status.HTTP_200_OK)
        self.assertIn('access', login.data)

        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        profile = self.client.get('/api/v2/auth/profile/')

        self.assertEqual(profile.status_code, status.HTTP_200_OK)
        self.assertEqual(profile.data['id'], self.user.id)

    def test_authentication_errors_have_stable_mobile_shape(self):
        response = self.client.get('/api/v2/auth/profile/')

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(response.data['success'], False)
        self.assertEqual(response.data['status_code'], 401)
        self.assertIn('errors', response.data)

    def test_logout_blacklists_refresh_token(self):
        login = self.client.post(
            '/api/v2/auth/login/',
            {'username': self.user.username, 'password': 'StrongPass123!'},
            format='json',
        )
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")

        logout = self.client.post(
            '/api/v2/auth/logout/',
            {'refresh': login.data['refresh']},
            format='json',
        )
        self.assertEqual(logout.status_code, status.HTTP_200_OK)

        refresh = self.client.post(
            '/api/v2/auth/refresh/',
            {'refresh': login.data['refresh']},
            format='json',
        )
        self.assertEqual(refresh.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_password_reset_changes_password(self):
        request_reset = self.client.post(
            '/api/v2/auth/password-reset/',
            {'email': self.user.email},
            format='json',
        )
        self.assertEqual(request_reset.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 1)

        reset_url = mail.outbox[0].body.splitlines()[2]
        query = parse_qs(urlparse(reset_url).query)
        confirm = self.client.post(
            '/api/v2/auth/password-reset/confirm/',
            {
                'uid': query['uid'][0],
                'token': query['token'][0],
                'password': 'NewStrongPass456!',
                'password_confirm': 'NewStrongPass456!',
            },
            format='json',
        )

        self.assertEqual(confirm.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('NewStrongPass456!'))

    def test_password_reset_does_not_disclose_unknown_email(self):
        response = self.client.post(
            '/api/v2/auth/password-reset/',
            {'email': 'unknown@example.com'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 0)


class MobileApiV2RolePermissionTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.regular_user = User.objects.create_user(
            username='regular-user',
            email='regular@example.com',
            phone='01000000002',
            password='StrongPass123!',
        )
        self.business_owner = User.objects.create_user(
            username='business-owner',
            email='owner@example.com',
            phone='01000000003',
            password='StrongPass123!',
            is_business_owner=True,
        )
        self.admin = User.objects.create_superuser(
            username='admin-user',
            email='admin@example.com',
            phone='01000000004',
            password='StrongPass123!',
        )

    def test_regular_user_cannot_access_business_owner_dashboard(self):
        self.client.force_authenticate(self.regular_user)
        response = self.client.get('/api/v2/business-owner/dashboard/stats/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_business_owner_can_access_own_dashboard(self):
        self.client.force_authenticate(self.business_owner)
        response = self.client.get('/api/v2/business-owner/dashboard/stats/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['total_businesses'], 0)

    def test_regular_user_cannot_access_admin_api(self):
        self.client.force_authenticate(self.regular_user)
        response = self.client.get('/api/v2/admin/users/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_access_admin_api(self):
        self.client.force_authenticate(self.admin)
        response = self.client.get('/api/v2/admin/users/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_public_catalogues_reject_write_operations(self):
        self.client.force_authenticate(self.business_owner)

        for endpoint in ('businesses', 'products', 'deals'):
            response = self.client.post(f'/api/v2/{endpoint}/', {}, format='json')
            self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)


class MobileApiV2ImageValidationTests(TestCase):
    def test_valid_png_is_accepted(self):
        content = BytesIO()
        Image.new('RGB', (20, 20), color='blue').save(content, format='PNG')
        upload = SimpleUploadedFile('image.png', content.getvalue(), content_type='image/png')

        self.assertIs(validate_image_upload(upload), upload)

    def test_unsupported_image_type_is_rejected(self):
        upload = SimpleUploadedFile(
            'image.svg',
            b'<svg xmlns="http://www.w3.org/2000/svg"></svg>',
            content_type='image/svg+xml',
        )

        with self.assertRaises(serializers.ValidationError):
            validate_image_upload(upload)

    def test_image_larger_than_five_mb_is_rejected(self):
        upload = SimpleUploadedFile(
            'large.png',
            b'0' * (5 * 1024 * 1024 + 1),
            content_type='image/png',
        )

        with self.assertRaises(serializers.ValidationError):
            validate_image_upload(upload)


class MobileApiV2DiscoveryTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_home_endpoint_returns_all_mobile_sections(self):
        response = self.client.get('/api/v2/home/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            set(response.data),
            {
                'categories', 'featured_businesses', 'featured_products',
                'featured_deals', 'governorates',
            },
        )

    def test_nearby_requires_valid_coordinates(self):
        missing = self.client.get('/api/v2/businesses/nearby/')
        invalid = self.client.get(
            '/api/v2/businesses/nearby/',
            {'latitude': 100, 'longitude': 31},
        )

        self.assertEqual(missing.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(invalid.status_code, status.HTTP_400_BAD_REQUEST)

    def test_nearby_accepts_valid_coordinates(self):
        response = self.client.get(
            '/api/v2/businesses/nearby/',
            {'latitude': 30.0444, 'longitude': 31.2357, 'radius_km': 20},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])


class MobileApiV2InteractionTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username='interaction-owner', email='interaction-owner@example.com',
            phone='01000000010', password='StrongPass123!', is_business_owner=True,
        )
        self.user = User.objects.create_user(
            username='interaction-user', email='interaction-user@example.com',
            phone='01000000011', password='StrongPass123!',
        )
        self.other_user = User.objects.create_user(
            username='interaction-other', email='interaction-other@example.com',
            phone='01000000012', password='StrongPass123!',
        )
        governorate = Governorate.objects.create(name_en='Cairo Test', name_ar='القاهرة اختبار')
        city = City.objects.create(
            governorate=governorate, name_en='City Test', name_ar='مدينة اختبار'
        )
        district = District.objects.create(city=city, name_en='District Test', name_ar='حي اختبار')
        category = Category.objects.create(name_en='Category Test', name_ar='تصنيف اختبار')
        self.business = Business.objects.create(
            owner=self.owner,
            category=category,
            district=district,
            name_en='Published Business',
            name_ar='نشاط منشور',
            is_active=True,
            is_verified=True,
        )
        self.hidden_business = Business.objects.create(
            owner=self.owner,
            category=category,
            district=district,
            name_en='Hidden Business',
            name_ar='نشاط مخفي',
            is_active=False,
            is_verified=False,
        )

    def test_favorite_toggle_rejects_hidden_business(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(
            '/api/v2/favorites/toggle/',
            {'business_id': self.hidden_business.id},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertFalse(Favorite.objects.filter(user=self.user).exists())

    def test_business_detail_reports_current_user_favorite_state(self):
        Favorite.objects.create(user=self.user, business=self.business)
        self.client.force_authenticate(self.user)

        response = self.client.get(f'/api/v2/businesses/{self.business.slug}/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_favorite'])

    def test_new_review_waits_for_admin_approval(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(
            '/api/v2/reviews/',
            {'business': self.business.id, 'rating': 5, 'comment': 'ممتاز'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(Review.objects.get(user=self.user).is_approved)

        review_list = self.client.get(
            '/api/v2/reviews/',
            {'business': self.business.id},
        )
        self.assertEqual(review_list.status_code, status.HTTP_200_OK)
        self.assertTrue(review_list.data['results'][0]['is_own'])

    def test_review_like_toggles_and_report_is_not_duplicated(self):
        review = Review.objects.create(
            business=self.business,
            user=self.user,
            rating=5,
            comment='تقييم منشور',
            is_approved=True,
        )
        self.client.force_authenticate(self.other_user)

        like = self.client.post(f'/api/v2/reviews/{review.id}/like/')
        unlike = self.client.post(f'/api/v2/reviews/{review.id}/like/')
        first_report = self.client.post(
            f'/api/v2/reviews/{review.id}/report/', {'reason': 'محتوى غير مناسب'}
        )
        second_report = self.client.post(
            f'/api/v2/reviews/{review.id}/report/', {'reason': 'بلاغ مكرر'}
        )

        self.assertTrue(like.data['is_liked'])
        self.assertFalse(unlike.data['is_liked'])
        self.assertFalse(ReviewLike.objects.filter(review=review).exists())
        self.assertEqual(first_report.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second_report.data['status'], 'already_reported')
        self.assertEqual(ReviewReport.objects.filter(review=review).count(), 1)

    def test_deal_claim_never_exceeds_total_limit(self):
        deal = Deal.objects.create(
            business=self.business,
            title_en='Limited Deal',
            title_ar='عرض محدود',
            description_en='Limited',
            description_ar='محدود',
            start_date=timezone.now() - timedelta(hours=1),
            end_date=timezone.now() + timedelta(days=1),
            max_uses=1,
            max_uses_per_user=1,
        )

        self.client.force_authenticate(self.user)
        first = self.client.post(f'/api/v2/deals/{deal.slug}/claim/')
        self.client.force_authenticate(self.other_user)
        second = self.client.post(f'/api/v2/deals/{deal.slug}/claim/')

        deal.refresh_from_db()
        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(deal.current_uses, 1)
        self.assertEqual(DealClaim.objects.filter(deal=deal).count(), 1)


class MobileApiV2NotificationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='notification-user', email='notification@example.com',
            phone='01000000020', password='StrongPass123!',
        )
        self.other_user = User.objects.create_user(
            username='notification-other', email='notification-other@example.com',
            phone='01000000021', password='StrongPass123!',
        )
        self.admin = User.objects.create_superuser(
            username='notification-admin', email='notification-admin@example.com',
            phone='01000000022', password='StrongPass123!',
        )

    def test_app_config_reports_available_and_required_updates(self):
        config = SiteSettings.get_settings()
        config.android_min_version = '2.0.0'
        config.android_latest_version = '2.5.0'
        config.force_update = True
        config.save()

        response = self.client.get(
            '/api/v2/app-config/', {'platform': 'android', 'version': '1.5.0'}
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['update_available'])
        self.assertTrue(response.data['update_required'])

    def test_device_registration_is_scoped_to_current_user(self):
        self.client.force_authenticate(self.user)
        created = self.client.post(
            '/api/v2/devices/',
            {
                'token': 'firebase-token-1', 'platform': 'android',
                'device_id': 'device-1', 'app_version': '1.0.0', 'language': 'ar',
            },
            format='json',
        )

        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        self.assertEqual(DeviceRegistration.objects.get().user, self.user)

        self.client.force_authenticate(self.other_user)
        listing = self.client.get('/api/v2/devices/')
        self.assertEqual(listing.data['results'], [])

    def test_notification_inbox_read_all_and_user_isolation(self):
        Notification.objects.create(
            user=self.user, title_ar='عنوان', body_ar='رسالة'
        )
        Notification.objects.create(
            user=self.other_user, title_ar='خاص', body_ar='لمستخدم آخر'
        )
        self.client.force_authenticate(self.user)

        inbox = self.client.get('/api/v2/notifications/')
        unread = self.client.get('/api/v2/notifications/unread-count/')
        read_all = self.client.post('/api/v2/notifications/read-all/')

        self.assertEqual(inbox.data['count'], 1)
        self.assertEqual(unread.data['count'], 1)
        self.assertEqual(read_all.data['updated'], 1)
        self.assertFalse(Notification.objects.filter(user=self.user, is_read=False).exists())

    def test_admin_can_create_targeted_notification(self):
        self.client.force_authenticate(self.admin)
        response = self.client.post(
            '/api/v2/admin/notifications/send/',
            {
                'user_ids': [self.user.id],
                'title_ar': 'عرض جديد',
                'body_ar': 'يوجد عرض جديد بالقرب منك',
                'notification_type': 'deal',
                'data': {'deal_id': 10},
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['created'], 1)
        self.assertTrue(Notification.objects.filter(user=self.user).exists())
        self.assertFalse(Notification.objects.filter(user=self.other_user).exists())
