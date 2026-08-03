from django.test import SimpleTestCase, override_settings


@override_settings(
    CORS_ALLOWED_ORIGINS=['https://sendoo-m.github.io'],
    CSRF_TRUSTED_ORIGINS=['https://sendoo-m.github.io'],
)
class WebCorsSettingsTests(SimpleTestCase):
    def test_github_pages_origin_is_allowed(self):
        from django.conf import settings

        self.assertIn('https://sendoo-m.github.io', settings.CORS_ALLOWED_ORIGINS)
        self.assertIn('https://sendoo-m.github.io', settings.CSRF_TRUSTED_ORIGINS)
