"""
Populate Initial Categories
===========================
Command to create initial categories for Daliil Ay Khidma

Usage:
    python manage.py populate_categories
    python manage.py populate_categories --reset  # Delete all and recreate
"""

from django.core.management.base import BaseCommand
from django.db import transaction
from apps.directory.models import Category


class Command(BaseCommand):
    help = 'Populate initial categories for shops, crafts, and public services'

    def add_arguments(self, parser):
        parser.add_argument(
            '--reset',
            action='store_true',
            help='Delete all categories and recreate'
        )

    def handle(self, *args, **options):
        if options['reset']:
            self.stdout.write(self.style.WARNING('⚠️ Deleting all categories...'))
            Category.objects.all().delete()
            self.stdout.write(self.style.SUCCESS('✓ All categories deleted'))

        with transaction.atomic():
            self.create_categories()

        self.stdout.write(self.style.SUCCESS(
            f'\n🎉 Successfully created {Category.objects.count()} categories!'
        ))

    def create_categories(self):
        """إنشاء جميع التصنيفات"""
        
        # ========================================
        # 🏪 Shop Categories
        # ========================================
        self.stdout.write('\n🏪 Creating Shop Categories...')
        
        shops_main = Category.objects.create(
            name_en="Shops & Stores",
            name_ar="محلات تجارية",
            icon="fas fa-store",
            order=1,
            description_en="Commercial shops and retail stores",
            description_ar="محلات تجارية ومتاجر التجزئة"
        )
        self.stdout.write(f'  ✓ {shops_main.name_en} / {shops_main.name_ar}')

        shop_subcats = [
            {
                'name_en': 'Restaurants & Cafes',
                'name_ar': 'مطاعم ومقاهي',
                'icon': 'fas fa-utensils',
                'order': 1
            },
            {
                'name_en': 'Supermarkets',
                'name_ar': 'سوبر ماركت',
                'icon': 'fas fa-shopping-cart',
                'order': 2
            },
            {
                'name_en': 'Clothing & Fashion',
                'name_ar': 'ملابس وأزياء',
                'icon': 'fas fa-tshirt',
                'order': 3
            },
            {
                'name_en': 'Electronics',
                'name_ar': 'إلكترونيات',
                'icon': 'fas fa-laptop',
                'order': 4
            },
            {
                'name_en': 'Pharmacies',
                'name_ar': 'صيدليات',
                'icon': 'fas fa-pills',
                'order': 5
            },
            {
                'name_en': 'Bakeries',
                'name_ar': 'مخابز ومعجنات',
                'icon': 'fas fa-bread-slice',
                'order': 6
            },
            {
                'name_en': 'Mobile & Accessories',
                'name_ar': 'محمول وإكسسوارات',
                'icon': 'fas fa-mobile-alt',
                'order': 7
            },
            {
                'name_en': 'Furniture',
                'name_ar': 'أثاث ومفروشات',
                'icon': 'fas fa-couch',
                'order': 8
            },
        ]

        for cat_data in shop_subcats:
            cat = Category.objects.create(parent=shops_main, **cat_data)
            self.stdout.write(f'    • {cat.name_en} / {cat.name_ar}')

        # ========================================
        # 🔧 Craft & Service Categories
        # ========================================
        self.stdout.write('\n🔧 Creating Craft & Service Categories...')
        
        crafts_main = Category.objects.create(
            name_en="Crafts & Professional Services",
            name_ar="حرف وخدمات مهنية",
            icon="fas fa-tools",
            order=2,
            description_en="Professional craftsmen and service providers",
            description_ar="حرفيون ومقدمو خدمات مهنية"
        )
        self.stdout.write(f'  ✓ {crafts_main.name_en} / {crafts_main.name_ar}')

        craft_subcats = [
            {
                'name_en': 'Plumbing',
                'name_ar': 'سباكة',
                'icon': 'fas fa-wrench',
                'order': 1
            },
            {
                'name_en': 'Electricians',
                'name_ar': 'كهرباء',
                'icon': 'fas fa-bolt',
                'order': 2
            },
            {
                'name_en': 'Carpentry',
                'name_ar': 'نجارة',
                'icon': 'fas fa-hammer',
                'order': 3
            },
            {
                'name_en': 'Painting & Decoration',
                'name_ar': 'دهانات وديكور',
                'icon': 'fas fa-paint-roller',
                'order': 4
            },
            {
                'name_en': 'Plastering',
                'name_ar': 'محارة',
                'icon': 'fas fa-trowel',
                'order': 5
            },
            {
                'name_en': 'Air Conditioning',
                'name_ar': 'تكييف وتبريد',
                'icon': 'fas fa-fan',
                'order': 6
            },
            {
                'name_en': 'Auto Repair',
                'name_ar': 'تصليح سيارات',
                'icon': 'fas fa-car',
                'order': 7
            },
            {
                'name_en': 'Cleaning Services',
                'name_ar': 'خدمات نظافة',
                'icon': 'fas fa-broom',
                'order': 8
            },
            {
                'name_en': 'Moving & Transportation',
                'name_ar': 'نقل وترحيلات',
                'icon': 'fas fa-truck',
                'order': 9
            },
        ]

        for cat_data in craft_subcats:
            cat = Category.objects.create(parent=crafts_main, **cat_data)
            self.stdout.write(f'    • {cat.name_en} / {cat.name_ar}')

        # ========================================
        # 🏛️ Public Service Categories
        # ========================================
        self.stdout.write('\n🏛️ Creating Public Service Categories...')
        
        public_main = Category.objects.create(
            name_en="Public Services",
            name_ar="خدمات عامة",
            icon="fas fa-landmark",
            order=3,
            description_en="Government and public service facilities",
            description_ar="منشآت حكومية وخدمات عامة"
        )
        self.stdout.write(f'  ✓ {public_main.name_en} / {public_main.name_ar}')

        public_subcats = [
            {
                'name_en': 'Public Hospitals',
                'name_ar': 'مستشفيات حكومية',
                'icon': 'fas fa-hospital',
                'order': 1
            },
            {
                'name_en': 'Police Stations',
                'name_ar': 'مراكز شرطة',
                'icon': 'fas fa-shield-alt',
                'order': 2
            },
            {
                'name_en': 'Fire Stations',
                'name_ar': 'محطات إطفاء',
                'icon': 'fas fa-fire-extinguisher',
                'order': 3
            },
            {
                'name_en': 'Public Schools',
                'name_ar': 'مدارس حكومية',
                'icon': 'fas fa-school',
                'order': 4
            },
            {
                'name_en': 'Public Libraries',
                'name_ar': 'مكتبات عامة',
                'icon': 'fas fa-book',
                'order': 5
            },
            {
                'name_en': 'Public Parks',
                'name_ar': 'حدائق عامة',
                'icon': 'fas fa-tree',
                'order': 6
            },
            {
                'name_en': 'Sports Facilities',
                'name_ar': 'ملاعب ومنشآت رياضية',
                'icon': 'fas fa-futbol',
                'order': 7
            },
            {
                'name_en': 'Post Offices',
                'name_ar': 'مكاتب بريد',
                'icon': 'fas fa-envelope',
                'order': 8
            },
            {
                'name_en': 'Government Offices',
                'name_ar': 'مكاتب حكومية',
                'icon': 'fas fa-building',
                'order': 9
            },
        ]

        for cat_data in public_subcats:
            cat = Category.objects.create(parent=public_main, **cat_data)
            self.stdout.write(f'    • {cat.name_en} / {cat.name_ar}')
