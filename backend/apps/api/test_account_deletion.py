from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import AccountDeletionRequest


User = get_user_model()


class AccountDeletionApiTests(APITestCase):
    def setUp(self):
        self.password = 'Strong-Test-Password-928!'
        self.user = User.objects.create_user(
            username='delete-me',
            email='delete@example.com',
            phone='01012345678',
            password=self.password,
        )
        self.url = reverse('api_v2:account_deletion')
        self.client.force_authenticate(self.user)

    def test_requires_explicit_delete_confirmation(self):
        response = self.client.post(
            self.url,
            {'password': self.password, 'confirmation': 'NO'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_active)
        self.assertFalse(AccountDeletionRequest.objects.exists())

    def test_rejects_wrong_password(self):
        response = self.client.post(
            self.url,
            {'password': 'wrong-password', 'confirmation': 'DELETE'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_active)

    def test_request_deactivates_account_and_preserves_audit_record(self):
        response = self.client.post(
            self.url,
            {
                'password': self.password,
                'confirmation': 'DELETE',
                'reason': 'No longer using the service',
                'source': 'user_app',
            },
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_active)

        deletion = AccountDeletionRequest.objects.get(user=self.user)
        self.assertEqual(deletion.status, AccountDeletionRequest.Status.PENDING)
        self.assertEqual(deletion.user_id_snapshot, self.user.pk)
        self.assertEqual(deletion.email_snapshot, 'delete@example.com')
        self.assertEqual(deletion.source, 'user_app')

    def test_staff_account_cannot_be_deleted_from_mobile_api(self):
        self.user.is_staff = True
        self.user.save(update_fields=['is_staff'])
        response = self.client.post(
            self.url,
            {'password': self.password, 'confirmation': 'DELETE'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_active)
