# apps/core/management/commands/populate_data.py
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from apps.directory.models import Governorate, City, District, Category, Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.subscriptions.models import SubscriptionPlan
from decimal import Decimal
from datetime import timedelta

User = get_user_model()


class Command(BaseCommand):
    help = 'Populate database with sample data'

    def handle(self, *args, **kwargs):
        self.stdout.write('🚀 Starting to populate data...\n')
        
        # 1. Create Users
        self.create_users()
        
        # 2. Create Locations
        self.create_locations()
        
        # 3. Create Categories
        self.create_categories()
        
        # 4. Create Businesses
        self.create_businesses()
        
        # 5. Create Products
        self.create_products()
        
        # 6. Create Deals
        self.create_deals()
        
        # 7. Create Subscription Plans
        self.create_subscription_plans()
        
        self.stdout.write(self.style.SUCCESS('\n✅ Data populated successfully!'))
    
    def create_users(self):
        self.stdout.write('👤 Creating users...')
        
        # Admin user
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser(
                username='admin',
                email='admin@daliilaaykhidma.com',
                password='admin123',
                phone='01012345678',
                first_name='Admin',
                last_name='User',
            )
            self.stdout.write('  ✓ Admin created')
        
        # Business Owner
        if not User.objects.filter(username='owner1').exists():
            User.objects.create_user(
                username='owner1',
                email='owner1@example.com',
                password='owner123',
                phone='01123456789',
                first_name='Ahmed',
                last_name='Mohamed',
                is_business_owner=True,
                email_verified=True,
            )
            self.stdout.write('  ✓ Business owner created')
        
        # Regular User
        if not User.objects.filter(username='user1').exists():
            User.objects.create_user(
                username='user1',
                email='user1@example.com',
                password='user123',
                phone='01234567890',
                first_name='Sara',
                last_name='Ali',
                email_verified=True,
            )
            self.stdout.write('  ✓ Regular user created')
    
    def create_locations(self):
        self.stdout.write('📍 Creating locations...')
        
        # Governorates
        cairo, _ = Governorate.objects.get_or_create(
            name_en='Cairo',
            defaults={'name_ar': 'القاهرة', 'slug': 'cairo', 'is_active': True}
        )
        
        giza, _ = Governorate.objects.get_or_create(
            name_en='Giza',
            defaults={'name_ar': 'الجيزة', 'slug': 'giza', 'is_active': True}
        )
        
        alex, _ = Governorate.objects.get_or_create(
            name_en='Alexandria',
            defaults={'name_ar': 'الإسكندرية', 'slug': 'alexandria', 'is_active': True}
        )
        
        # Cities
        nasr_city, _ = City.objects.get_or_create(
            name_en='Nasr City',
            governorate=cairo,
            defaults={'name_ar': 'مدينة نصر', 'slug': 'nasr-city', 'is_active': True}
        )
        
        maadi, _ = City.objects.get_or_create(
            name_en='Maadi',
            governorate=cairo,
            defaults={'name_ar': 'المعادي', 'slug': 'maadi', 'is_active': True}
        )
        
        dokki, _ = City.objects.get_or_create(
            name_en='Dokki',
            governorate=giza,
            defaults={'name_ar': 'الدقي', 'slug': 'dokki', 'is_active': True}
        )
        
        # Districts
        District.objects.get_or_create(
            name_en='Makram Ebeid',
            city=nasr_city,
            defaults={'name_ar': 'مكرم عبيد', 'slug': 'makram-ebeid', 'is_active': True}
        )
        
        District.objects.get_or_create(
            name_en='Zahraa Nasr City',
            city=nasr_city,
            defaults={'name_ar': 'زهراء مدينة نصر', 'slug': 'zahraa-nasr-city', 'is_active': True}
        )
        
        self.stdout.write('  ✓ Locations created')
    
    def create_categories(self):
        self.stdout.write('📁 Creating categories...')
        
        categories = [
            {'name_en': 'Restaurants', 'name_ar': 'مطاعم', 'icon': 'fas fa-utensils'},
            {'name_en': 'Cafes', 'name_ar': 'كافيهات', 'icon': 'fas fa-coffee'},
            {'name_en': 'Shopping', 'name_ar': 'تسوق', 'icon': 'fas fa-shopping-cart'},
            {'name_en': 'Healthcare', 'name_ar': 'رعاية صحية', 'icon': 'fas fa-hospital'},
            {'name_en': 'Education', 'name_ar': 'تعليم', 'icon': 'fas fa-graduation-cap'},
            {'name_en': 'Services', 'name_ar': 'خدمات', 'icon': 'fas fa-wrench'},
            {'name_en': 'Entertainment', 'name_ar': 'ترفيه', 'icon': 'fas fa-gamepad'},
            {'name_en': 'Beauty', 'name_ar': 'تجميل', 'icon': 'fas fa-spa'},
        ]
        
        for i, cat in enumerate(categories, start=1):
            Category.objects.get_or_create(
                slug=cat['name_en'].lower().replace(' ', '-'),
                defaults={
                    'name_en': cat['name_en'],
                    'name_ar': cat['name_ar'],
                    'icon': cat['icon'],
                    'order': i * 10,
                    'is_active': True,
                }
            )
        
        self.stdout.write('  ✓ Categories created')
    
    def create_businesses(self):
        self.stdout.write('🏪 Creating businesses...')
        
        owner = User.objects.get(username='owner1')
        category = Category.objects.first()
        district = District.objects.first()
        
        businesses = [
            {
                'name_en': 'Golden Restaurant',
                'name_ar': 'مطعم الذهبي',
                'description_en': 'Best traditional Egyptian food',
                'description_ar': 'أفضل الأكلات المصرية التقليدية',
                'phone': '0223456789',
                'is_featured': True,
            },
            {
                'name_en': 'Coffee House',
                'name_ar': 'كوفي هاوس',
                'description_en': 'Cozy cafe with great coffee',
                'description_ar': 'كافيه مريح مع قهوة رائعة',
                'phone': '0223456790',
                'is_promoted': True,
            },
            {
                'name_en': 'Tech Store',
                'name_ar': 'محل التكنولوجيا',
                'description_en': 'Latest electronics and gadgets',
                'description_ar': 'أحدث الإلكترونيات والأجهزة',
                'phone': '0223456791',
                'is_featured': True,
            },
        ]
        
        for biz in businesses:
            Business.objects.get_or_create(
                slug=biz['name_en'].lower().replace(' ', '-'),
                defaults={
                    **biz,
                    'owner': owner,
                    'category': category,
                    'district': district,
                    'is_active': True,
                    'is_verified': True,
                    'business_type': 'both',
                }
            )
        
        self.stdout.write('  ✓ Businesses created')
    
    def create_products(self):
        self.stdout.write('📦 Creating products...')
        
        business = Business.objects.first()
        
        if business:
            products = [
                {
                    'name_en': 'Premium Coffee',
                    'name_ar': 'قهوة مميزة',
                    'description_en': 'Rich and aromatic coffee',
                    'description_ar': 'قهوة غنية وعطرية',
                    'price': Decimal('50.00'),
                    'product_type': 'product',
                },
                {
                    'name_en': 'Delivery Service',
                    'name_ar': 'خدمة التوصيل',
                    'description_en': 'Fast delivery to your door',
                    'description_ar': 'توصيل سريع لبابك',
                    'price': Decimal('20.00'),
                    'product_type': 'service',
                },
            ]
            
            for prod in products:
                Product.objects.get_or_create(
                    slug=prod['name_en'].lower().replace(' ', '-'),
                    business=business,
                    defaults={
                        **prod,
                        'is_available': True,
                        'is_featured': True,
                    }
                )
            
            self.stdout.write('  ✓ Products created')
    
    def create_deals(self):
        self.stdout.write('🎁 Creating deals...')
        
        business = Business.objects.first()
        
        if business:
            deals = [
                {
                    'title_en': '50% Off on All Items',
                    'title_ar': 'خصم 50% على جميع المنتجات',
                    'description_en': 'Limited time offer!',
                    'description_ar': 'عرض لفترة محدودة!',
                    'discount_percentage': Decimal('50.00'),
                    'deal_type': 'percentage',
                    'start_date': timezone.now(),
                    'end_date': timezone.now() + timedelta(days=30),
                },
            ]
            
            for deal in deals:
                Deal.objects.get_or_create(
                    slug=deal['title_en'].lower().replace(' ', '-'),
                    business=business,
                    defaults={
                        **deal,
                        'is_active': True,
                        'is_featured': True,
                    }
                )
            
            self.stdout.write('  ✓ Deals created')
    
    def create_subscription_plans(self):
        self.stdout.write('💳 Creating subscription plans...')
        
        plans = [
            {
                'name': 'Basic',
                'display_name_en': 'Basic Plan',
                'display_name_ar': 'الباقة الأساسية',
                'description_en': 'Perfect for small businesses',
                'description_ar': 'مثالية للشركات الصغيرة',
                'price_monthly': Decimal('99.00'),
                'max_products': 10,
                'max_business_images': 5,
                'max_images_per_product': 3,
            },
            {
                'name': 'Premium',
                'display_name_en': 'Premium Plan',
                'display_name_ar': 'الباقة المميزة',
                'description_en': 'Great for growing businesses',
                'description_ar': 'رائعة للشركات النامية',
                'price_monthly': Decimal('299.00'),
                'max_products': 50,
                'max_business_images': 15,
                'max_images_per_product': 5,
                'can_create_deals': True,
            },
            {
                'name': 'Enterprise',
                'display_name_en': 'Enterprise Plan',
                'display_name_ar': 'باقة المؤسسات',
                'description_en': 'Best for large enterprises',
                'description_ar': 'الأفضل للمؤسسات الكبيرة',
                'price_monthly': Decimal('599.00'),
                'max_products': 200,
                'max_business_images': 50,
                'max_images_per_product': 10,
                'can_create_deals': True,
                'can_show_prices': True,
                'has_analytics': True,
            },
        ]
        
        for plan in plans:
            SubscriptionPlan.objects.get_or_create(
                name=plan['name'],
                defaults={
                    **plan,
                    'is_active': True,
                    'is_popular': plan['name'] == 'Premium',
                }
            )
        
        self.stdout.write('  ✓ Subscription plans created')
