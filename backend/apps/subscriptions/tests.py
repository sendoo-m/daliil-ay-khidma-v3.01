from types import SimpleNamespace

from django.test import SimpleTestCase

from .services import change_type


FEATURE_FIELDS = (
    'can_upload_images',
    'can_show_prices',
    'has_delivery_options',
    'has_analytics',
    'featured_in_search',
    'can_create_deals',
    'has_social_media_links',
    'has_verified_badge',
)


def plan(*, price=0, businesses=1, products=3, product_images=1, business_images=1, **features):
    values = {
        'price_monthly': price,
        'max_businesses': businesses,
        'max_products': products,
        'max_images_per_product': product_images,
        'max_business_images': business_images,
    }
    values.update({field: features.get(field, False) for field in FEATURE_FIELDS})
    return SimpleNamespace(**values)


class SubscriptionChangeDirectionTests(SimpleTestCase):
    def test_expanding_limits_is_upgrade(self):
        current = plan(price=0, businesses=1, products=3)
        target = plan(price=100, businesses=3, products=50, has_analytics=True)
        self.assertEqual(change_type(current, target), 'upgrade')

    def test_higher_price_does_not_hide_a_reduced_limit(self):
        current = plan(price=100, businesses=3, products=50, has_analytics=True)
        target = plan(price=200, businesses=3, products=5, has_analytics=True)
        self.assertEqual(change_type(current, target), 'downgrade')

    def test_losing_a_feature_is_downgrade(self):
        current = plan(price=100, businesses=1, products=5, can_create_deals=True)
        target = plan(price=100, businesses=1, products=5, can_create_deals=False)
        self.assertEqual(change_type(current, target), 'downgrade')

    def test_zero_limit_means_unlimited_and_is_an_upgrade(self):
        current = plan(price=100, businesses=1, products=5)
        target = plan(price=100, businesses=0, products=0)
        self.assertEqual(change_type(current, target), 'upgrade')

    def test_moving_from_unlimited_to_finite_is_downgrade(self):
        current = plan(price=100, businesses=0, products=0)
        target = plan(price=100, businesses=3, products=50)
        self.assertEqual(change_type(current, target), 'downgrade')
