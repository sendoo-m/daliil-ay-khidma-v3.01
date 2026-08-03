from django.contrib.staticfiles import finders
from django.test import SimpleTestCase


class ShopPlaceholderTests(SimpleTestCase):
    def test_shop_placeholder_is_available_to_staticfiles(self):
        """The shops page must not reference a missing manifest asset."""
        self.assertIsNotNone(finders.find("images/shop-placeholder.svg"))
