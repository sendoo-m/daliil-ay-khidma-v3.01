"""Tests for the browser-based account registration flow."""

from django.test import TestCase
from django.urls import reverse

from .models import User


class RegisterViewTests(TestCase):
    def setUp(self):
        self.url = reverse('accounts:register')

    def test_get_displays_all_registration_fields(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertIsNotNone(response.context['form'])
        for field_name in ('username', 'email', 'phone', 'password1', 'password2'):
            self.assertContains(response, f'name="{field_name}"')

    def test_valid_registration_saves_phone_and_logs_user_in(self):
        response = self.client.post(
            self.url,
            {
                'username': 'new-user',
                'email': 'new-user@example.com',
                'phone': '01000000003',
                'password1': 'A-strong-password-2026',
                'password2': 'A-strong-password-2026',
            },
        )

        user = User.objects.get(username='new-user')
        self.assertEqual(user.email, 'new-user@example.com')
        self.assertEqual(user.phone, '01000000003')
        self.assertEqual(self.client.session.get('_auth_user_id'), str(user.pk))
        self.assertRedirects(
            response,
            reverse('dashboard:index'),
            fetch_redirect_response=False,
        )

    def test_invalid_registration_redisplays_bound_form_errors(self):
        response = self.client.post(
            self.url,
            {
                'username': 'new-user',
                'email': 'not-an-email',
                'phone': '01000000004',
                'password1': 'different-password-1',
                'password2': 'different-password-2',
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.context['form'].is_bound)
        self.assertTrue(response.context['form'].errors)
        self.assertContains(response, 'name="username"')
        self.assertFalse(User.objects.filter(username='new-user').exists())
