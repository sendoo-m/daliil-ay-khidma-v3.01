"""Create a complete, repeatable demo dataset for design and journey testing."""

import logging
from datetime import time, timedelta
from decimal import Decimal
from pathlib import Path
from xml.sax.saxutils import escape

from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.categories.models import Category
from apps.deals.models import Deal, DealClaim
from apps.directory.models import (
    Business,
    BusinessImage,
    BusinessWorkingHours,
    City,
    District,
    Favorite,
    Governorate,
)
from apps.notifications.models import Notification
from apps.products.models import Product, ProductImage
from apps.reviews.models import Review, ReviewLike, ReviewReply, ReviewReport
from apps.subscriptions.models import Subscription, SubscriptionPlan

DEMO_PREFIX = "demo_"
DEMO_SLUG_PREFIX = "demo-"
DEMO_PASSWORD = "Demo@12345"
DEMO_ASSET_DIR = Path(__file__).resolve().parents[2] / "demo_assets"
logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "إنشاء داتا تجريبية شاملة، أو حذف الداتا التجريبية فقط"

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="حذف الداتا التجريبية فقط دون إنشاء بيانات جديدة",
        )
        parser.add_argument(
            "--reset",
            action="store_true",
            help="حذف الداتا التجريبية ثم إعادة إنشائها من البداية",
        )
        parser.add_argument(
            "--images-only",
            choices=("all", "categories", "businesses", "products", "deals"),
            help="إصلاح صور جزء محدد من الداتا الموجودة دون إعادة إنشاء السجلات",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        # Upload at most one copy of each shared demo asset per command run.
        # If the remote storage is unavailable, database seeding must still finish.
        self._shared_image_names = {}
        self._uploaded_shared_images = set()
        self._image_upload_failed = False

        if options["images_only"]:
            restored_images = self._repair_demo_images(options["images_only"])
            self.stdout.write(
                self.style.SUCCESS(
                    f"تمت معالجة {restored_images} من روابط وملفات الصور التجريبية."
                )
            )
            return

        if options["clear"] or options["reset"]:
            self._clear_demo_data()
            if options["clear"]:
                self.stdout.write(self.style.SUCCESS("تم حذف الداتا التجريبية فقط."))
                return

        if self._demo_exists():
            restored_images = self._repair_demo_images("all")
            self.stdout.write(
                self.style.WARNING(
                    "الداتا التجريبية موجودة بالفعل؛ لم يتم تكرارها. "
                    f"تمت استعادة {restored_images} من ملفات الصور المفقودة. "
                    "استخدم --reset لإعادة إنشاء جميع الداتا."
                )
            )
            self._print_summary()
            return

        self.stdout.write("جاري إنشاء الداتا التجريبية الشاملة...")
        owners, customers = self._create_users()
        districts = self._create_locations()
        categories = self._create_categories()
        businesses = self._create_businesses(owners, districts, categories)
        self._create_working_hours(businesses)
        products = self._create_products(businesses)
        deals = self._create_deals(businesses)
        self._create_reviews_and_activity(businesses, customers, deals)
        self._create_subscriptions(businesses)
        self._create_notifications(owners, customers, businesses, deals)
        self._add_images(categories, businesses, products, deals)

        self.stdout.write(self.style.SUCCESS("تم إنشاء الداتا التجريبية بنجاح."))
        self.stdout.write(f"كلمة مرور جميع الحسابات التجريبية: {DEMO_PASSWORD}")
        self._print_summary()

    def _demo_exists(self):
        return (
            get_user_model().objects.filter(username__startswith=DEMO_PREFIX).exists()
        )

    def _clear_demo_data(self):
        self.stdout.write("جاري حذف الداتا التجريبية فقط...")
        get_user_model().objects.filter(username__startswith=DEMO_PREFIX).delete()
        Business.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).delete()
        Category.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).delete()
        District.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).delete()
        City.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).delete()
        Governorate.objects.filter(slug__startswith=DEMO_SLUG_PREFIX).delete()
        SubscriptionPlan.objects.filter(name__startswith="demo_").delete()

    def _create_users(self):
        User = get_user_model()
        owner_names = [
            ("ahmed", "أحمد", "الطبيب"),
            ("mahmoud", "محمود", "الكهربائي"),
            ("youssef", "يوسف", "الحلاق"),
            ("nour", "نور", "المصممة"),
            ("mariam", "مريم", "صاحبة المتجر"),
            ("karim", "كريم", "مقدم الخدمة"),
        ]
        customer_names = [
            ("sara", "سارة", "محمد"),
            ("omar", "عمر", "علي"),
            ("layla", "ليلى", "حسن"),
            ("tarek", "طارق", "سعيد"),
            ("huda", "هدى", "خالد"),
        ]
        owners, customers = [], []
        for index, (key, first, last) in enumerate(owner_names, 1):
            user = User.objects.create_user(
                username=f"{DEMO_PREFIX}owner_{key}",
                password=DEMO_PASSWORD,
                email=f"demo.owner.{key}@example.com",
                phone=f"0109000{index:04d}",
                first_name=first,
                last_name=last,
                city="الإسماعيلية",
                is_business_owner=True,
                email_verified=True,
            )
            owners.append(user)
        for index, (key, first, last) in enumerate(customer_names, 101):
            user = User.objects.create_user(
                username=f"{DEMO_PREFIX}customer_{key}",
                password=DEMO_PASSWORD,
                email=f"demo.customer.{key}@example.com",
                phone=f"0119000{index:04d}",
                first_name=first,
                last_name=last,
                city="الإسماعيلية",
                email_verified=index % 2 == 1,
            )
            customers.append(user)
        return owners, customers

    def _create_locations(self):
        data = [
            (
                "Ismailia",
                "الإسماعيلية",
                [
                    (
                        "Ismailia",
                        "الإسماعيلية",
                        [
                            ("Sheikh Zayed", "الشيخ زايد"),
                            ("Al Salam", "حي السلام"),
                            ("Downtown", "وسط البلد"),
                        ],
                    )
                ],
            ),
            (
                "Cairo",
                "القاهرة",
                [
                    (
                        "Cairo",
                        "القاهرة",
                        [("Nasr City", "مدينة نصر"), ("Maadi", "المعادي")],
                    )
                ],
            ),
            (
                "Suez",
                "السويس",
                [
                    (
                        "Suez",
                        "السويس",
                        [("Faisal", "حي فيصل"), ("Arbaeen", "حي الأربعين")],
                    )
                ],
            ),
        ]
        districts = []
        for gov_order, (gov_en, gov_ar, cities) in enumerate(data, 1):
            gov = Governorate.objects.create(
                name_en=f"Demo {gov_en}",
                name_ar=f"{gov_ar} (تجريبي)",
                slug=f"{DEMO_SLUG_PREFIX}{gov_en.lower()}",
                order=gov_order,
            )
            for city_order, (city_en, city_ar, areas) in enumerate(cities, 1):
                city = City.objects.create(
                    governorate=gov,
                    name_en=f"Demo {city_en}",
                    name_ar=f"{city_ar} (تجريبي)",
                    slug=f"{DEMO_SLUG_PREFIX}{gov_en.lower()}-{city_en.lower().replace(' ', '-')}",
                    order=city_order,
                )
                for area_order, (area_en, area_ar) in enumerate(areas, 1):
                    districts.append(
                        District.objects.create(
                            city=city,
                            name_en=f"Demo {area_en}",
                            name_ar=f"{area_ar} (تجريبي)",
                            slug=(f"{DEMO_SLUG_PREFIX}{gov_en}-{city_en}-{area_en}")
                            .lower()
                            .replace(" ", "-"),
                            order=area_order,
                        )
                    )
        return districts

    def _create_categories(self):
        parent_data = [
            ("medical", "Medical Services", "الخدمات الطبية", "fas fa-stethoscope"),
            ("crafts", "Home Services", "الخدمات المنزلية والحرفية", "fas fa-tools"),
            ("beauty", "Beauty", "الجمال والعناية", "fas fa-cut"),
            ("creative", "Creative Services", "الخدمات الإبداعية", "fas fa-palette"),
            ("shopping", "Shopping", "التسوق", "fas fa-store"),
            ("food", "Food and Cafes", "المطاعم والمقاهي", "fas fa-utensils"),
            ("hotels", "Hotels and Accommodation", "الفنادق والإقامة", "fas fa-hotel"),
            ("travel", "Travel and Trips", "السياحة والرحلات", "fas fa-plane"),
            ("freelance", "Freelance Work", "الأعمال الحرة", "fas fa-laptop-code"),
            (
                "electronics",
                "Electronics",
                "الإلكترونيات والموبايلات",
                "fas fa-mobile-alt",
            ),
            ("appliances", "Home Appliances", "الأجهزة المنزلية", "fas fa-tv"),
            (
                "grocery",
                "Supermarkets",
                "السوبر ماركت والبقالة",
                "fas fa-shopping-basket",
            ),
            ("fashion", "Fashion", "الملابس والأحذية", "fas fa-tshirt"),
            ("furniture", "Furniture", "الأثاث والمفروشات", "fas fa-couch"),
            ("automotive", "Cars and Vehicles", "السيارات ووسائل النقل", "fas fa-car"),
            ("education", "Education", "التعليم والتدريب", "fas fa-graduation-cap"),
            ("realestate", "Real Estate", "العقارات", "fas fa-building"),
            ("events", "Events", "الأفراح والمناسبات", "fas fa-calendar-star"),
        ]
        categories = {}
        for order, (key, en, ar, icon) in enumerate(parent_data, 1):
            parent = Category.objects.create(
                name_en=f"Demo {en}",
                name_ar=f"{ar} (تجريبي)",
                slug=f"{DEMO_SLUG_PREFIX}{key}",
                icon=icon,
                order=order,
                description_ar=f"قسم تجريبي شامل لاختبار صفحات {ar}.",
                description_en=f"Demo category for testing {en} pages.",
            )
            categories[key] = parent

        child_data = [
            (
                "phones",
                "Mobile Phones",
                "الهواتف المحمولة",
                "electronics",
                "fas fa-mobile-alt",
            ),
            (
                "computers",
                "Computers",
                "الكمبيوتر واللابتوب",
                "electronics",
                "fas fa-laptop",
            ),
            (
                "televisions",
                "Televisions",
                "الشاشات والتلفزيونات",
                "appliances",
                "fas fa-tv",
            ),
            ("washers", "Washing Machines", "الغسالات", "appliances", "fas fa-soap"),
            ("resorts", "Resorts", "المنتجعات", "hotels", "fas fa-umbrella-beach"),
            (
                "apartments",
                "Hotel Apartments",
                "الشقق الفندقية",
                "hotels",
                "fas fa-bed",
            ),
            (
                "domestic-trips",
                "Domestic Trips",
                "الرحلات الداخلية",
                "travel",
                "fas fa-bus",
            ),
            (
                "international-trips",
                "International Trips",
                "الرحلات الخارجية",
                "travel",
                "fas fa-passport",
            ),
            ("design", "Design", "التصميم والجرافيك", "freelance", "fas fa-pen-nib"),
            (
                "programming",
                "Programming",
                "البرمجة وتطوير المواقع",
                "freelance",
                "fas fa-code",
            ),
            (
                "markets",
                "Grocery Markets",
                "البقالة والمواد الغذائية",
                "grocery",
                "fas fa-store-alt",
            ),
            ("mens-fashion", "Men's Fashion", "ملابس رجالي", "fashion", "fas fa-male"),
            (
                "womens-fashion",
                "Women's Fashion",
                "ملابس حريمي",
                "fashion",
                "fas fa-female",
            ),
            (
                "car-maintenance",
                "Car Maintenance",
                "صيانة السيارات",
                "automotive",
                "fas fa-car-side",
            ),
            ("photography", "Photography", "التصوير", "events", "fas fa-camera"),
        ]
        start_order = len(parent_data) + 1
        for offset, (key, en, ar, parent_key, icon) in enumerate(child_data):
            categories[key] = Category.objects.create(
                name_en=f"Demo {en}",
                name_ar=f"{ar} (تجريبي)",
                slug=f"{DEMO_SLUG_PREFIX}{key}",
                parent=categories[parent_key],
                icon=icon,
                order=start_order + offset,
                description_ar=f"قسم فرعي تجريبي لاختبار {ar}.",
                description_en=f"Demo subcategory for testing {en}.",
            )
        return categories

    def _create_businesses(self, owners, districts, categories):
        data = [
            (
                "doctor",
                "عيادة د. أحمد للقلب",
                "Dr Ahmed Cardiology Clinic",
                "public",
                "medical",
            ),
            (
                "electrician",
                "محمود للكهرباء المنزلية",
                "Mahmoud Home Electrician",
                "craft",
                "crafts",
            ),
            ("barber", "صالون يوسف للرجال", "Youssef Men's Salon", "shop", "beauty"),
            (
                "designer",
                "استوديو نور للتصميم",
                "Nour Design Studio",
                "craft",
                "creative",
            ),
            ("store", "بيت الهدايا", "Gift House", "shop", "shopping"),
            ("cafe", "كافيه المرسى", "Al Marsa Cafe", "shop", "food"),
            (
                "tech-one",
                "تِك وان للإلكترونيات",
                "Tech One Electronics",
                "shop",
                "phones",
            ),
            ("digital-market", "ديجيتال ماركت", "Digital Market", "shop", "phones"),
            ("smart-zone", "سمارت زون", "Smart Zone", "shop", "phones"),
            (
                "home-center",
                "هوم سنتر للأجهزة",
                "Home Center Appliances",
                "shop",
                "appliances",
            ),
            (
                "family-appliances",
                "أجهزة العائلة",
                "Family Appliances",
                "shop",
                "appliances",
            ),
            ("save-market", "ماركت التوفير", "Save Market", "shop", "markets"),
            ("city-market", "سيتي ماركت", "City Market", "shop", "markets"),
            ("family-market", "فاميلي ماركت", "Family Market", "shop", "markets"),
            ("blue-resort", "منتجع بلو سي", "Blue Sea Resort", "public", "resorts"),
            ("canal-hotel", "فندق القناة", "Canal Hotel", "public", "hotels"),
            (
                "sendoo-travel-demo",
                "سندو ترافيل للرحلات",
                "Sendoo Travel",
                "public",
                "domestic-trips",
            ),
            ("horizon-tours", "هورايزون للسياحة", "Horizon Tours", "public", "travel"),
            (
                "pixel-freelancer",
                "بيكسل للتصميم الحر",
                "Pixel Freelance Design",
                "craft",
                "design",
            ),
            (
                "web-freelancer",
                "مطور الويب الحر",
                "Freelance Web Developer",
                "craft",
                "programming",
            ),
            (
                "modern-furniture",
                "المودرن للأثاث",
                "Modern Furniture",
                "shop",
                "furniture",
            ),
            (
                "style-house",
                "ستايل هاوس للملابس",
                "Style House Fashion",
                "shop",
                "fashion",
            ),
        ]
        businesses = []
        for index, (key, ar, en, business_type, category_key) in enumerate(data):
            business = Business.objects.create(
                owner=owners[index % len(owners)],
                business_type=business_type,
                name_en=en,
                name_ar=ar,
                slug=f"{DEMO_SLUG_PREFIX}{key}",
                category=categories[category_key],
                district=districts[index % len(districts)],
                phone=f"0128000{index + 1:04d}",
                whatsapp=f"0128000{index + 1:04d}",
                email=f"{key}.demo@example.com",
                website="https://example.com",
                facebook="https://facebook.com/example",
                instagram="https://instagram.com/example",
                address_en="Main street, beside the public square",
                address_ar="الشارع الرئيسي، بجوار الميدان العام",
                description_en=f"A complete demo profile for {en}, with realistic services and contact details.",
                description_ar=f"ملف تجريبي متكامل لـ {ar} يضم خدمات وبيانات تواصل واقعية للاختبار.",
                working_hours_en="Saturday–Thursday: 9 AM–9 PM",
                working_hours_ar="السبت–الخميس: 9 صباحًا–9 مساءً",
                latitude=Decimal("30.590000") + Decimal(index) / 100,
                longitude=Decimal("32.270000") + Decimal(index) / 100,
                is_active=True,
                is_verified=True,
                is_featured=index in (0, 2, 3, 6, 9, 14),
                is_promoted=index in (1, 3, 7, 11, 16),
                view_count=max(90, 1250 - index * 55),
                click_count=max(15, 280 - index * 11),
            )
            businesses.append(business)
        return businesses

    def _create_working_hours(self, businesses):
        for business in businesses:
            for day in range(7):
                BusinessWorkingHours.objects.create(
                    business=business,
                    day=day,
                    opening_time=None if day == 5 else time(9),
                    closing_time=None if day == 5 else time(21),
                    is_closed=day == 5,
                )

    def _create_products(self, businesses):
        catalog = {
            "doctor": [
                ("كشف طبي", "Medical examination", "service", 450),
                ("استشارة متابعة", "Follow-up", "service", 250),
            ],
            "electrician": [
                ("زيارة وفحص أعطال", "Inspection visit", "service", 200),
                ("تركيب لوحة كهرباء", "Panel installation", "service", 1200),
            ],
            "barber": [
                ("قص شعر وتصفيف", "Haircut", "service", 180),
                ("باقة العريس", "Groom package", "service", 900),
            ],
            "designer": [
                ("تصميم هوية بصرية", "Brand identity", "service", 3500),
                ("تصميم منشورات", "Social posts", "service", 800),
            ],
            "store": [
                ("صندوق هدايا", "Gift box", "product", 650),
                ("كوب مخصص", "Custom mug", "product", 220),
            ],
            "cafe": [
                ("قهوة مختصة", "Specialty coffee", "product", 85),
                ("إفطار المرسى", "Marsa breakfast", "product", 240),
            ],
            "tech-one": [
                ("هاتف ذكي 256 جيجابايت", "Smartphone 256 GB", "product", 28999),
                ("سماعات لاسلكية", "Wireless earbuds", "product", 2199),
                ("لابتوب 15 بوصة", "15-inch laptop", "product", 32499),
            ],
            "digital-market": [
                ("هاتف ذكي 256 جيجابايت", "Smartphone 256 GB", "product", 27950),
                ("سماعات لاسلكية", "Wireless earbuds", "product", 2350),
                ("لابتوب 15 بوصة", "15-inch laptop", "product", 31900),
            ],
            "smart-zone": [
                ("هاتف ذكي 256 جيجابايت", "Smartphone 256 GB", "product", 29450),
                ("سماعات لاسلكية", "Wireless earbuds", "product", 1999),
                ("لابتوب 15 بوصة", "15-inch laptop", "product", 32990),
            ],
            "home-center": [
                ("غسالة أوتوماتيك 10 كجم", "10 kg washing machine", "product", 21999),
                ("شاشة ذكية 55 بوصة", "55-inch smart TV", "product", 18499),
                ("تكييف بارد 1.5 حصان", "1.5 HP air conditioner", "product", 26499),
            ],
            "family-appliances": [
                ("غسالة أوتوماتيك 10 كجم", "10 kg washing machine", "product", 21250),
                ("شاشة ذكية 55 بوصة", "55-inch smart TV", "product", 17990),
                ("تكييف بارد 1.5 حصان", "1.5 HP air conditioner", "product", 26950),
            ],
            "save-market": [
                ("زيت طعام 1 لتر", "Cooking oil 1 litre", "product", 79),
                ("أرز مصري 5 كجم", "Egyptian rice 5 kg", "product", 265),
                ("قهوة سادة 250 جرام", "Plain coffee 250 g", "product", 185),
            ],
            "city-market": [
                ("زيت طعام 1 لتر", "Cooking oil 1 litre", "product", 76),
                ("أرز مصري 5 كجم", "Egyptian rice 5 kg", "product", 279),
                ("قهوة سادة 250 جرام", "Plain coffee 250 g", "product", 179),
            ],
            "family-market": [
                ("زيت طعام 1 لتر", "Cooking oil 1 litre", "product", 82),
                ("أرز مصري 5 كجم", "Egyptian rice 5 kg", "product", 259),
                ("قهوة سادة 250 جرام", "Plain coffee 250 g", "product", 192),
            ],
            "blue-resort": [
                ("غرفة مزدوجة بإطلالة بحرية", "Sea-view double room", "service", 3850),
                ("إقامة عائلية ليلتين", "Two-night family stay", "service", 7200),
            ],
            "canal-hotel": [
                ("غرفة مزدوجة بإطلالة بحرية", "Sea-view double room", "service", 3200),
                ("إقامة عائلية ليلتين", "Two-night family stay", "service", 6500),
            ],
            "sendoo-travel-demo": [
                (
                    "رحلة شرم الشيخ 4 أيام",
                    "Four-day Sharm El Sheikh trip",
                    "service",
                    6900,
                ),
                ("رحلة يوم واحد إلى القاهرة", "Cairo day trip", "service", 950),
            ],
            "horizon-tours": [
                (
                    "رحلة شرم الشيخ 4 أيام",
                    "Four-day Sharm El Sheikh trip",
                    "service",
                    6450,
                ),
                ("رحلة يوم واحد إلى القاهرة", "Cairo day trip", "service", 1100),
            ],
            "pixel-freelancer": [
                ("تصميم شعار احترافي", "Professional logo design", "service", 1500),
                ("تصميم هوية بصرية", "Brand identity design", "service", 4200),
            ],
            "web-freelancer": [
                ("تصميم متجر إلكتروني", "E-commerce website design", "service", 12000),
                ("صفحة هبوط احترافية", "Professional landing page", "service", 4500),
            ],
            "modern-furniture": [
                ("غرفة نوم مودرن", "Modern bedroom set", "product", 48500),
                ("ركنة عائلية", "Family corner sofa", "product", 26900),
            ],
            "style-house": [
                ("قميص رجالي كاجوال", "Men's casual shirt", "product", 699),
                ("حذاء رياضي", "Sports shoes", "product", 1450),
            ],
        }
        products = []
        for business in businesses:
            key = business.slug.removeprefix(DEMO_SLUG_PREFIX)
            for order, (ar, en, product_type, price) in enumerate(catalog[key], 1):
                products.append(
                    Product.objects.create(
                        business=business,
                        name_ar=ar,
                        name_en=en,
                        slug=f"{business.slug}-{order}",
                        product_type=product_type,
                        description_ar=f"وصف تجريبي مفصل لخدمة أو منتج {ar}.",
                        description_en=f"Detailed demo description for {en}.",
                        price=Decimal(price),
                        old_price=(
                            Decimal(price) * Decimal("1.12") if order == 1 else None
                        ),
                        is_available=True,
                        stock_quantity=25 if product_type == "product" else None,
                        has_delivery=product_type == "product",
                        delivery_cost=(
                            Decimal(25 + (business.pk % 4) * 10)
                            if product_type == "product"
                            else None
                        ),
                        delivery_time_ar=f"خلال {1 + business.pk % 3} يوم",
                        delivery_time_en=f"Within {1 + business.pk % 3} days",
                        order=order,
                        is_featured=order == 1,
                        view_count=240 - order * 35,
                    )
                )
        return products

    def _create_deals(self, businesses):
        now = timezone.now()
        specs = [
            (
                businesses[2],
                "خصم 25% على باقة العريس",
                "25% off groom package",
                now - timedelta(days=3),
                now + timedelta(days=20),
                True,
            ),
            (
                businesses[4],
                "هدية مجانية مع كل طلب",
                "Free gift with every order",
                now + timedelta(days=5),
                now + timedelta(days=30),
                False,
            ),
            (
                businesses[5],
                "عرض الإفطار لشخصين",
                "Breakfast for two",
                now - timedelta(days=30),
                now - timedelta(days=2),
                False,
            ),
        ]
        deals = []
        for index, (business, ar, en, start, end, featured) in enumerate(specs, 1):
            deals.append(
                Deal.objects.create(
                    business=business,
                    title_ar=ar,
                    title_en=en,
                    slug=f"{DEMO_SLUG_PREFIX}deal-{index}",
                    description_ar=f"تفاصيل وشروط العرض التجريبي: {ar}.",
                    description_en=f"Demo offer details and terms: {en}.",
                    deal_type="percentage" if index == 1 else "special",
                    discount_percentage=25 if index == 1 else None,
                    original_price=900 if index == 1 else None,
                    final_price=675 if index == 1 else None,
                    start_date=start,
                    end_date=end,
                    terms_ar="للاستخدام مرة واحدة.",
                    terms_en="One use per customer.",
                    max_uses=100,
                    max_uses_per_user=1,
                    is_featured=featured,
                    view_count=480 - index * 70,
                )
            )
        return deals

    def _create_reviews_and_activity(self, businesses, customers, deals):
        comments = [
            "خدمة ممتازة والتزام بالموعد.",
            "تجربة جيدة وسأكررها.",
            "جودة رائعة وتعامل محترم.",
            "السعر مناسب والنتيجة مرضية.",
            "أنصح بالتجربة.",
        ]
        reviews = []
        for business_index, business in enumerate(businesses[:5]):
            for customer_index, customer in enumerate(customers[:3]):
                review = Review.objects.create(
                    business=business,
                    user=customer,
                    rating=5 - ((business_index + customer_index) % 3),
                    comment=comments[(business_index + customer_index) % len(comments)],
                    is_approved=not (business_index == 4 and customer_index == 2),
                )
                reviews.append(review)
                if customer_index == 0:
                    ReviewReply.objects.create(
                        review=review,
                        user=business.owner,
                        comment="شكرًا لتقييمك، نسعد بخدمتك دائمًا.",
                    )
        for index, review in enumerate(reviews[:5]):
            ReviewLike.objects.create(
                review=review, user=customers[(index + 1) % len(customers)]
            )
        ReviewReport.objects.create(
            review=reviews[-1],
            user=customers[4],
            reason="بلاغ تجريبي لاختبار رحلة المراجعة الإدارية.",
        )
        for index, business in enumerate(businesses[:4]):
            Favorite.objects.create(user=customers[index], business=business)
        for index, deal in enumerate(deals[:2]):
            DealClaim.objects.create(
                deal=deal,
                user=customers[index],
                is_used=index == 0,
                used_at=timezone.now() if index == 0 else None,
                notes="مطالبة تجريبية",
            )
            Deal.objects.filter(pk=deal.pk).update(current_uses=1)

    def _create_subscriptions(self, businesses):
        now = timezone.now()
        plan_specs = [
            ("demo_free", "Demo Free", "تجريبي مجاني", 0, 0, False),
            ("demo_basic", "Demo Basic", "تجريبي أساسي", 199, 10, False),
            ("demo_premium", "Demo Premium", "تجريبي مميز", 399, 30, True),
            ("demo_vip", "Demo VIP", "تجريبي نخبة", 699, 0, True),
        ]
        plans = []
        for order, (name, en, ar, price, max_products, popular) in enumerate(
            plan_specs
        ):
            plans.append(
                SubscriptionPlan.objects.create(
                    name=name,
                    display_name_en=en,
                    display_name_ar=ar,
                    description_ar="خطة تجريبية لاختبار الاشتراكات والصلاحيات.",
                    description_en="Demo plan for subscription and permissions testing.",
                    price_monthly=price,
                    price_quarterly=price * 3,
                    price_semi_annual=price * 6,
                    price_annual=price * 12,
                    max_products=max_products,
                    max_images_per_product=5,
                    max_business_images=10,
                    can_upload_images=name != "demo_free",
                    can_show_prices=name != "demo_free",
                    has_delivery_options=name in ("demo_premium", "demo_vip"),
                    has_analytics=name in ("demo_premium", "demo_vip"),
                    featured_in_search=name == "demo_vip",
                    can_create_deals=name in ("demo_premium", "demo_vip"),
                    has_verified_badge=name == "demo_vip",
                    order=order,
                    is_popular=popular,
                )
            )
        for index, business in enumerate(businesses):
            plan = plans[index % len(plans)]
            status = "expired" if index == 5 else "active"
            Subscription.objects.create(
                business=business,
                plan=plan,
                start_date=now - timedelta(days=20),
                end_date=(
                    now - timedelta(days=1)
                    if status == "expired"
                    else now + timedelta(days=40 + index)
                ),
                status=status,
                auto_renew=index % 2 == 0,
                amount_paid=plan.price_monthly,
                payment_method="Demo card",
                transaction_id=f"DEMO-TXN-{index + 1:03d}",
            )

    def _create_notifications(self, owners, customers, businesses, deals):
        users = owners[:3] + customers[:3]
        for index, user in enumerate(users):
            Notification.objects.create(
                user=user,
                notification_type=["business", "deal", "review"][index % 3],
                title_ar="إشعار تجريبي جديد",
                title_en="New demo notification",
                body_ar="هذا إشعار لاختبار شاشة الإشعارات وحالة القراءة.",
                body_en="This notification tests the list and read state.",
                data={
                    "demo": True,
                    "business_slug": businesses[index % len(businesses)].slug,
                },
                is_read=index % 2 == 0,
                read_at=timezone.now() if index % 2 == 0 else None,
            )

    def _svg(self, title, color, width=1200, height=600):
        title = escape(title)
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs><linearGradient id="g"><stop stop-color="{color}"/><stop offset="1" stop-color="#111827"/></linearGradient></defs>
<rect width="100%" height="100%" fill="url(#g)"/><circle cx="{width * .82}" cy="{height * .2}" r="{height * .28}" fill="#fff" opacity=".12"/>
<text x="50%" y="48%" fill="white" font-size="{max(28, height // 11)}" font-family="Arial" text-anchor="middle">{title}</text>
<text x="50%" y="62%" fill="white" opacity=".8" font-size="{max(18, height // 22)}" font-family="Arial" text-anchor="middle">Daliil Ay Khidma • Demo</text></svg>"""
        return ContentFile(svg.encode("utf-8"))

    def _asset_content(self, asset_name):
        """Return one optimized, generated demo photo as an uploadable file."""
        return ContentFile((DEMO_ASSET_DIR / asset_name).read_bytes())

    def _photo_for(self, text):
        """Choose a reusable generated photo for a category, business, or product."""
        text = text.lower()
        groups = (
            (
                "electronics.webp",
                (
                    "phone",
                    "mobile",
                    "smartphone",
                    "earbud",
                    "laptop",
                    "tech",
                    "digital",
                    "هاتف",
                    "سماعات",
                    "لابتوب",
                ),
            ),
            (
                "appliances.webp",
                (
                    "appliance",
                    "washing",
                    "television",
                    "smart tv",
                    "air conditioner",
                    "home center",
                    "غسالة",
                    "شاشة",
                    "تكييف",
                ),
            ),
            (
                "groceries.webp",
                (
                    "grocery",
                    "market",
                    "cooking oil",
                    "rice",
                    "coffee",
                    "زيت",
                    "أرز",
                    "قهوة",
                ),
            ),
            (
                "hotel-travel.webp",
                (
                    "hotel",
                    "resort",
                    "travel",
                    "trip",
                    "room",
                    "stay",
                    "فندق",
                    "منتجع",
                    "رحلة",
                    "غرفة",
                    "إقامة",
                ),
            ),
        )
        for asset_name, keywords in groups:
            if any(keyword in text for keyword in keywords):
                return asset_name
        return None

    def _image_content(self, title, color, width, height):
        asset_name = self._photo_for(title)
        if asset_name:
            return self._asset_content(asset_name), "webp"
        return self._svg(title, color, width, height), "svg"

    def _shared_image_name(self, field, title):
        """Upload a small shared asset set instead of one file per demo record."""
        asset_name = self._photo_for(title)
        cache_key = asset_name or "generic.svg"

        if cache_key in self._shared_image_names:
            return self._shared_image_names[cache_key]
        if self._image_upload_failed:
            return None

        field_name = field.name or ""
        existing_name = field_name if field_name.startswith("demo/shared/") else ""
        if existing_name:
            try:
                if field.storage.exists(existing_name):
                    self._shared_image_names[cache_key] = existing_name
                    return existing_name
            except Exception:
                logger.exception(
                    "Demo image check failed; continuing without demo image repair"
                )
                self.stderr.write(
                    self.style.WARNING(
                        "تعذر فحص الصور التجريبية؛ تم الاحتفاظ بالبيانات الحالية."
                    )
                )
                self._image_upload_failed = True
                return None

        if asset_name:
            content = self._asset_content(asset_name)
        else:
            content = self._svg("Daliil Ay Khidma", "#0f766e")

        try:
            stored_name = field.storage.save(
                existing_name or f"demo/shared/{cache_key}",
                content,
            )
        except Exception:
            # Images improve the demo but are not allowed to roll back all records.
            # The bounded Cloudinary timeout keeps this inside Gunicorn's deadline.
            logger.exception("Demo image upload failed; continuing without demo images")
            self.stderr.write(
                self.style.WARNING(
                    "تعذر رفع الصور التجريبية؛ تم إنشاء البيانات بدون صور."
                )
            )
            self._image_upload_failed = True
            return None

        self._shared_image_names[cache_key] = stored_name
        self._uploaded_shared_images.add(cache_key)
        return stored_name

    @staticmethod
    def _assign_image(instance, field_name, stored_name, *, save=True):
        """Assign an already uploaded shared file without uploading it again."""
        if not stored_name:
            return
        setattr(instance, field_name, stored_name)
        if save:
            instance.save(update_fields=[field_name])

    def _add_images(self, categories, businesses, products, deals):
        for category in categories.values():
            title = f"{category.slug} {category.name_en} {category.name_ar}"
            self._assign_image(
                category,
                "image",
                self._shared_image_name(category.image, title),
            )
        for business in businesses:
            image_title = (
                f"{business.slug} {business.name_en} {business.name_ar} "
                f"{business.category.slug}"
            )
            stored_name = self._shared_image_name(business.logo, image_title)
            if stored_name:
                business.logo = stored_name
                business.cover_image = stored_name
                business.save(update_fields=["logo", "cover_image"])
            for image_order in range(2):
                BusinessImage.objects.create(
                    business=business,
                    caption_ar="صورة تجريبية من معرض الأعمال",
                    caption_en="Demo gallery image",
                    order=image_order,
                    image=stored_name or "",
                )
        for product in products:
            title = f"{product.name_en} {product.name_ar} {product.business.name_en}"
            image = ProductImage(
                product=product,
                alt_text_ar=product.name_ar,
                alt_text_en=product.name_en,
                is_primary=True,
            )
            image.image = self._shared_image_name(image.image, title) or ""
            image.save()
        for deal in deals:
            self._assign_image(
                deal,
                "image",
                self._shared_image_name(deal.image, deal.title_en),
            )

    def _repair_demo_images(self, scope="all"):
        """Relink existing demo records to the small shared persistent asset set."""
        restored = 0

        if scope in ("all", "categories"):
            categories = Category.objects.filter(
                slug__startswith=DEMO_SLUG_PREFIX
            ).order_by("order", "pk")
            for category in categories:
                title = f"{category.slug} {category.name_en} {category.name_ar}"
                name = self._shared_image_name(category.image, title)
                if name and category.image.name != name:
                    self._assign_image(category, "image", name)
                    restored += 1

        if scope in ("all", "businesses"):
            businesses = Business.objects.filter(
                slug__startswith=DEMO_SLUG_PREFIX
            ).order_by("pk")
            for business in businesses:
                image_title = (
                    f"{business.slug} {business.name_en} {business.name_ar} "
                    f"{business.category.slug}"
                )
                name = self._shared_image_name(business.logo, image_title)
                if name:
                    changed = []
                    if business.logo.name != name:
                        business.logo = name
                        changed.append("logo")
                    if business.cover_image.name != name:
                        business.cover_image = name
                        changed.append("cover_image")
                    if changed:
                        business.save(update_fields=changed)
                        restored += len(changed)
                for image in business.images.all().order_by("order", "pk"):
                    if name and image.image.name != name:
                        self._assign_image(image, "image", name)
                        restored += 1

        if scope in ("all", "products"):
            products = Product.objects.filter(
                slug__startswith=DEMO_SLUG_PREFIX
            ).order_by("pk")
            for product in products:
                for image in product.images.all().order_by("pk"):
                    name = self._shared_image_name(
                        image.image,
                        f"{product.name_en} {product.name_ar} "
                        f"{product.business.name_en}",
                    )
                    if name and image.image.name != name:
                        self._assign_image(image, "image", name)
                        restored += 1

        if scope in ("all", "deals"):
            deals = Deal.objects.filter(slug__startswith="demo-deal-").order_by("pk")
            for deal in deals:
                name = self._shared_image_name(deal.image, deal.title_en)
                if name and deal.image.name != name:
                    self._assign_image(deal, "image", name)
                    restored += 1
        return restored + len(self._uploaded_shared_images)

    def _print_summary(self):
        counts = {
            "الحسابات": get_user_model()
            .objects.filter(username__startswith=DEMO_PREFIX)
            .count(),
            "الأنشطة": Business.objects.filter(
                slug__startswith=DEMO_SLUG_PREFIX
            ).count(),
            "المنتجات والخدمات": Product.objects.filter(
                slug__startswith=DEMO_SLUG_PREFIX
            ).count(),
            "العروض": Deal.objects.filter(
                slug__startswith=f"{DEMO_SLUG_PREFIX}deal-"
            ).count(),
            "التقييمات": Review.objects.filter(
                business__slug__startswith=DEMO_SLUG_PREFIX
            ).count(),
            "الإشعارات": Notification.objects.filter(
                user__username__startswith=DEMO_PREFIX
            ).count(),
        }
        self.stdout.write(
            "ملخص الداتا: "
            + "، ".join(f"{name}: {count}" for name, count in counts.items())
        )
