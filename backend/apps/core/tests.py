from io import StringIO
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.urls import reverse

from apps.categories.models import Category
from apps.deals.models import Deal
from apps.directory.models import Business
from apps.notifications.models import Notification
from apps.products.models import Product
from apps.reviews.models import Review
from apps.subscriptions.models import Subscription


class ProductionMediaStorageTests(TestCase):
    def _default_storage_backend(self, cloudinary_url=""):
        env = os.environ.copy()
        env.update(
            {
                "DJANGO_SETTINGS_MODULE": "config.settings.production",
                "SECRET_KEY": "test-only-secret-key",
                "ALLOWED_HOSTS": "testserver",
                "DB_NAME": "test",
                "DB_USER": "test",
                "DB_PASSWORD": "test",
                "CLOUDINARY_URL": cloudinary_url,
            }
        )
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                (
                    "import json; from django.conf import settings; "
                    "print(json.dumps(settings.STORAGES['default']['BACKEND']))"
                ),
            ],
            cwd=Path(__file__).resolve().parents[2],
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(result.stdout.strip())

    def test_cloudinary_is_used_when_render_secret_exists(self):
        backend = self._default_storage_backend(
            "cloudinary://1234567890:test-secret@test-cloud"
        )
        self.assertEqual(backend, "apps.core.storage.BoundedMediaCloudinaryStorage")

    def test_local_storage_remains_the_safe_fallback(self):
        self.assertEqual(
            self._default_storage_backend(),
            "django.core.files.storage.FileSystemStorage",
        )


class SeedDemoDataCommandTests(TestCase):
    def test_seed_keeps_records_when_image_storage_is_unavailable(self):
        stderr = StringIO()
        with patch(
            "django.core.files.storage.FileSystemStorage.save",
            side_effect=TimeoutError("storage timeout"),
        ):
            call_command("seed_demo_data", stdout=StringIO(), stderr=stderr)

        self.assertEqual(Business.objects.filter(slug__startswith="demo-").count(), 22)
        self.assertEqual(Product.objects.filter(slug__startswith="demo-").count(), 52)
        self.assertIn("تم إنشاء البيانات بدون صور", stderr.getvalue())

    def test_seed_is_comprehensive_and_idempotent(self):
        output = StringIO()
        call_command("seed_demo_data", stdout=output)

        self.assertEqual(
            get_user_model().objects.filter(username__startswith="demo_").count(), 11
        )
        self.assertEqual(Category.objects.filter(slug__startswith="demo-").count(), 33)
        self.assertEqual(Business.objects.filter(slug__startswith="demo-").count(), 22)
        self.assertEqual(Product.objects.filter(slug__startswith="demo-").count(), 52)
        self.assertEqual(Deal.objects.filter(slug__startswith="demo-deal-").count(), 3)
        self.assertEqual(
            Review.objects.filter(business__slug__startswith="demo-").count(), 15
        )
        self.assertEqual(
            Subscription.objects.filter(business__slug__startswith="demo-").count(), 22
        )
        self.assertEqual(
            Notification.objects.filter(user__username__startswith="demo_").count(), 6
        )
        self.assertTrue(Business.objects.filter(cover_image__endswith=".webp").exists())
        self.assertTrue(Product.objects.filter(image__image__endswith=".webp").exists())

        comparable_offers = Product.objects.filter(
            name_ar="هاتف ذكي 256 جيجابايت"
        ).order_by("price")
        self.assertEqual(comparable_offers.count(), 3)
        self.assertEqual(
            comparable_offers.values_list("price", flat=True).distinct().count(), 3
        )
        self.assertEqual(
            comparable_offers.values_list("business_id", flat=True).distinct().count(),
            3,
        )

        call_command("seed_demo_data", stdout=output)
        self.assertEqual(Business.objects.filter(slug__startswith="demo-").count(), 22)
        self.assertIn("موجودة بالفعل", output.getvalue())

    def test_clear_removes_only_demo_data(self):
        real_category = Category.objects.create(
            name_en="Real", name_ar="حقيقي", slug="real"
        )
        call_command("seed_demo_data", stdout=StringIO())
        call_command("seed_demo_data", "--clear", stdout=StringIO())

        self.assertFalse(
            get_user_model().objects.filter(username__startswith="demo_").exists()
        )
        self.assertFalse(Business.objects.filter(slug__startswith="demo-").exists())
        self.assertTrue(Category.objects.filter(pk=real_category.pk).exists())

    def test_unified_search_returns_comparable_product_prices(self):
        call_command("seed_demo_data", stdout=StringIO())

        response = self.client.get(
            reverse("directory:business_search"),
            {"q": "هاتف ذكي 256 جيجابايت"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["product_count"], 3)
        self.assertEqual(
            [product.price for product in response.context["products"]],
            [Decimal("27950"), Decimal("28999"), Decimal("29450")],
        )
        self.assertContains(response, "تِك وان للإلكترونيات")
        self.assertContains(response, "ديجيتال ماركت")
        self.assertContains(response, "سمارت زون")

    def test_repeated_seed_restores_missing_media_without_recreating_records(self):
        with TemporaryDirectory() as media_root, override_settings(
            MEDIA_ROOT=media_root
        ):
            call_command("seed_demo_data", stdout=StringIO())
            business = Business.objects.filter(slug__startswith="demo-").first()
            logo_path = Path(business.logo.path)
            business_count = Business.objects.filter(slug__startswith="demo-").count()
            self.assertTrue(logo_path.exists())

            logo_path.unlink()
            output = StringIO()
            call_command("seed_demo_data", stdout=output)

            self.assertTrue(logo_path.exists())
            self.assertEqual(
                Business.objects.filter(slug__startswith="demo-").count(),
                business_count,
            )
            self.assertIn("تمت استعادة 1 من ملفات الصور المفقودة", output.getvalue())


class DemoDataAdminTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.superuser = User.objects.create_superuser(
            username="admin_demo_test",
            email="admin@example.com",
            phone="01000000001",
            password="StrongPass123!",
        )
        cls.staff_user = User.objects.create_user(
            username="staff_demo_test",
            phone="01000000002",
            password="StrongPass123!",
            is_staff=True,
        )
        cls.url = reverse("admin_demo_data")

    def test_page_requires_login(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)
        self.assertIn(reverse("admin:login"), response.url)

    def test_page_rejects_non_superuser_staff(self):
        self.client.force_login(self.staff_user)
        self.assertEqual(self.client.get(self.url).status_code, 403)

    def test_superuser_can_open_page(self):
        self.client.force_login(self.superuser)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "إدارة الداتا التجريبية")

    def test_superuser_can_create_demo_data(self):
        self.client.force_login(self.superuser)
        response = self.client.post(self.url, {"action": "create"}, follow=True)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(Business.objects.filter(slug__startswith="demo-").exists())
        self.assertContains(response, "تم تنفيذ العملية بنجاح")

    def test_superuser_can_reset_old_demo_data_to_current_catalog(self):
        call_command("seed_demo_data", stdout=StringIO())
        product_ids = list(
            Product.objects.filter(slug__startswith="demo-")
            .order_by("pk")
            .values_list("pk", flat=True)[12:]
        )
        Product.objects.filter(pk__in=product_ids).delete()
        business_ids = list(
            Business.objects.filter(slug__startswith="demo-")
            .order_by("pk")
            .values_list("pk", flat=True)[6:]
        )
        Business.objects.filter(pk__in=business_ids).delete()

        self.client.force_login(self.superuser)
        response = self.client.post(self.url, {"action": "reset"}, follow=True)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(Category.objects.filter(slug__startswith="demo-").count(), 33)
        self.assertEqual(Business.objects.filter(slug__startswith="demo-").count(), 22)
        self.assertEqual(Product.objects.filter(slug__startswith="demo-").count(), 52)

    def test_superuser_can_process_each_image_group(self):
        call_command("seed_demo_data", stdout=StringIO())
        self.client.force_login(self.superuser)

        for action in (
            "images_categories",
            "images_businesses",
            "images_products",
            "images_deals",
        ):
            response = self.client.post(self.url, {"action": action}, follow=True)
            self.assertEqual(response.status_code, 200)
            self.assertContains(response, "تم تنفيذ العملية بنجاح")

    def test_clear_requires_exact_confirmation(self):
        call_command("seed_demo_data", stdout=StringIO())
        self.client.force_login(self.superuser)
        response = self.client.post(
            self.url,
            {"action": "clear", "confirmation": "wrong"},
            follow=True,
        )
        self.assertTrue(Business.objects.filter(slug__startswith="demo-").exists())
        self.assertContains(response, "اكتب عبارة التأكيد")

    def test_superuser_can_clear_demo_data(self):
        call_command("seed_demo_data", stdout=StringIO())
        self.client.force_login(self.superuser)
        response = self.client.post(
            self.url,
            {"action": "clear", "confirmation": "DELETE_DEMO_DATA"},
            follow=True,
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Business.objects.filter(slug__startswith="demo-").exists())
