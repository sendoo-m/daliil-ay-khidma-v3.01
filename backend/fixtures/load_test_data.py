#!/usr/bin/env python
"""
Script to load comprehensive test data for Daliil Ay Khidma
Focus: Canal Cities (Ismailia, Port Said, Suez) + 10th of Ramadan + Cairo + Alexandria

Usage:
    python fixtures/load_test_data.py
"""

import os
import sys
import django
from datetime import datetime, timedelta
from decimal import Decimal
import random

# Setup Django
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Respect DJANGO_SETTINGS_MODULE from the deployment environment.\n# Local runs still default to development settings.\nos.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from django.contrib.auth import get_user_model
from django.db import IntegrityError
from apps.directory.models import Business, Governorate, City, District
from apps.categories.models import Category
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review, ReviewReply

User = get_user_model()


def get_or_create_governorate(name_ar, name_en):
    """Helper to safely get or create governorate"""
    # Try to find by Arabic name first
    gov = Governorate.objects.filter(name_ar=name_ar).first()
    if gov:
        return gov
    
    # Try to find by English name
    gov = Governorate.objects.filter(name_en=name_en).first()
    if gov:
        return gov
    
    # Create new one
    try:
        gov = Governorate.objects.create(name_ar=name_ar, name_en=name_en)
        print(f"  - تم إنشاء محافظة: {name_ar}")
        return gov
    except IntegrityError:
        # Race condition - try to get again
        gov = Governorate.objects.filter(name_ar=name_ar).first()
        if not gov:
            gov = Governorate.objects.filter(name_en=name_en).first()
        return gov


def create_users():
    """إنشاء مستخدمين تجريبيين"""
    print("✅ إنشاء المستخدمين...")
    
    # Business owners
    owners = [
        {'username': 'ahmed_owner', 'email': 'ahmed@daliil.com', 'phone': '+20101234567', 'first_name': 'أحمد', 'last_name': 'محمد', 'password': 'test123'},
        {'username': 'fatima_owner', 'email': 'fatima@daliil.com', 'phone': '+20101234568', 'first_name': 'فاطمة', 'last_name': 'علي', 'password': 'test123'},
        {'username': 'khaled_owner', 'email': 'khaled@daliil.com', 'phone': '+20101234569', 'first_name': 'خالد', 'last_name': 'حسن', 'password': 'test123'},
        {'username': 'maha_owner', 'email': 'maha@daliil.com', 'phone': '+20101234570', 'first_name': 'مها', 'last_name': 'عبدالله', 'password': 'test123'},
        {'username': 'omar_owner', 'email': 'omar@daliil.com', 'phone': '+20101234571', 'first_name': 'عمر', 'last_name': 'سعيد', 'password': 'test123'},
        {'username': 'nour_owner', 'email': 'nour@daliil.com', 'phone': '+20101234572', 'first_name': 'نور', 'last_name': 'حسين', 'password': 'test123'},
        {'username': 'sara_owner', 'email': 'sara@daliil.com', 'phone': '+20101234573', 'first_name': 'سارة', 'last_name': 'عبدالرحمن', 'password': 'test123'},
    ]
    
    created_owners = []
    for owner_data in owners:
        user, created = User.objects.get_or_create(
            username=owner_data['username'],
            defaults={
                'email': owner_data['email'],
                'phone': owner_data['phone'],
                'first_name': owner_data['first_name'],
                'last_name': owner_data['last_name'],
            }
        )
        if created:
            user.set_password(owner_data['password'])
            user.save()
            print(f"  - تم إنشاء: {user.get_full_name()} ({user.username})")
        created_owners.append(user)
    
    # Customers
    customers_data = [
        {'username': 'customer1', 'phone': '+20102234567', 'first_name': 'محمد', 'last_name': 'أحمد'},
        {'username': 'customer2', 'phone': '+20102234568', 'first_name': 'سارة', 'last_name': 'خالد'},
        {'username': 'customer3', 'phone': '+20102234569', 'first_name': 'يوسف', 'last_name': 'محمود'},
        {'username': 'customer4', 'phone': '+20102234570', 'first_name': 'نور', 'last_name': 'عبدالرحمن'},
        {'username': 'customer5', 'phone': '+20102234571', 'first_name': 'ليلى', 'last_name': 'حسين'},
        {'username': 'customer6', 'phone': '+20102234572', 'first_name': 'عبدالله', 'last_name': 'عمر'},
        {'username': 'customer7', 'phone': '+20102234573', 'first_name': 'مريم', 'last_name': 'فاروق'},
        {'username': 'customer8', 'phone': '+20102234574', 'first_name': 'طارق', 'last_name': 'رشيد'},
        {'username': 'customer9', 'phone': '+20102234575', 'first_name': 'هدى', 'last_name': 'عبدالعزيز'},
        {'username': 'customer10', 'phone': '+20102234576', 'first_name': 'كريم', 'last_name': 'السيد'},
    ]
    
    created_customers = []
    for customer_data in customers_data:
        user, created = User.objects.get_or_create(
            username=customer_data['username'],
            defaults={
                'email': f"{customer_data['username']}@test.com",
                'phone': customer_data['phone'],
                'first_name': customer_data['first_name'],
                'last_name': customer_data['last_name'],
            }
        )
        if created:
            user.set_password('test123')
            user.save()
        created_customers.append(user)
    
    print(f"  ✅ {len(created_owners)} أصحاب محلات + {len(created_customers)} عميل")
    return created_owners, created_customers


def create_locations():
    """إنشاء المواقع الجغرافية - التركيز على مدن القناة والعاشر من رمضان"""
    print("✅ إنشاء المواقع الجغرافية...")
    
    all_districts = []
    
    # ========== 1. محافظة الإسماعيلية ==========
    ismailia_gov = get_or_create_governorate('الإسماعيلية', 'Ismailia')
    
    ismailia_districts_data = [
        {'city': 'الإسماعيلية', 'city_en': 'Ismailia', 'districts': [
            {'name_ar': 'حي السلام', 'name_en': 'Al Salam'},
            {'name_ar': 'حي الشيخ زايد', 'name_en': 'Sheikh Zayed'},
            {'name_ar': 'حي الضواحي', 'name_en': 'Al Dawahy'},
            {'name_ar': 'المستقبل', 'name_en': 'Al Mostakbal'},
            {'name_ar': 'عرب المعادي', 'name_en': 'Arab Al Maadi'},
        ]},
        {'city': 'فايد', 'city_en': 'Fayed', 'districts': [
            {'name_ar': 'وسط فايد', 'name_en': 'Fayed Center'},
            {'name_ar': 'منطقة الشاطئ', 'name_en': 'Beach Area'},
        ]},
        {'city': 'القنطرة شرق', 'city_en': 'Qantara East', 'districts': [
            {'name_ar': 'وسط القنطرة', 'name_en': 'Qantara Center'},
        ]},
    ]
    
    for city_data in ismailia_districts_data:
        city = City.objects.filter(governorate=ismailia_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=ismailia_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    # ========== 2. محافظة بورسعيد ==========
    portsaid_gov = get_or_create_governorate('بورسعيد', 'Port Said')
    
    portsaid_districts_data = [
        {'city': 'بورسعيد', 'city_en': 'Port Said', 'districts': [
            {'name_ar': 'حي الشرق', 'name_en': 'East District'},
            {'name_ar': 'حي العرب', 'name_en': 'Al Arab'},
            {'name_ar': 'حي الزهور', 'name_en': 'Al Zohour'},
            {'name_ar': 'حي المناخ', 'name_en': 'Al Manakh'},
            {'name_ar': 'بورفؤاد', 'name_en': 'Port Fouad'},
        ]},
    ]
    
    for city_data in portsaid_districts_data:
        city = City.objects.filter(governorate=portsaid_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=portsaid_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    # ========== 3. محافظة السويس ==========
    suez_gov = get_or_create_governorate('السويس', 'Suez')
    
    suez_districts_data = [
        {'city': 'السويس', 'city_en': 'Suez', 'districts': [
            {'name_ar': 'حي الأربعين', 'name_en': 'Al Arbaeen'},
            {'name_ar': 'حي السلام', 'name_en': 'Al Salam'},
            {'name_ar': 'حي فيصل', 'name_en': 'Faisal'},
            {'name_ar': 'حي الجناين', 'name_en': 'Al Ganayem'},
            {'name_ar': 'عتاقة', 'name_en': 'Ataqah'},
        ]},
    ]
    
    for city_data in suez_districts_data:
        city = City.objects.filter(governorate=suez_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=suez_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    # ========== 4. محافظة الشرقية (العاشر من رمضان) ==========
    sharqia_gov = get_or_create_governorate('الشرقية', 'Sharqia')
    
    sharqia_districts_data = [
        {'city': 'العاشر من رمضان', 'city_en': '10th of Ramadan', 'districts': [
            {'name_ar': 'المنطقة الأولى', 'name_en': 'Zone 1'},
            {'name_ar': 'المنطقة الثانية', 'name_en': 'Zone 2'},
            {'name_ar': 'المنطقة الصناعية', 'name_en': 'Industrial Zone'},
            {'name_ar': 'منطقة الأحياء', 'name_en': 'Residential Zone'},
        ]},
    ]
    
    for city_data in sharqia_districts_data:
        city = City.objects.filter(governorate=sharqia_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=sharqia_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    # ========== 5. محافظة القاهرة ==========
    cairo_gov = get_or_create_governorate('القاهرة', 'Cairo')
    
    cairo_districts_data = [
        {'city': 'القاهرة', 'city_en': 'Cairo', 'districts': [
            {'name_ar': 'مدينة نصر', 'name_en': 'Nasr City'},
            {'name_ar': 'مصر الجديدة', 'name_en': 'Heliopolis'},
            {'name_ar': 'المعادي', 'name_en': 'Maadi'},
            {'name_ar': 'وسط البلد', 'name_en': 'Downtown'},
        ]},
    ]
    
    for city_data in cairo_districts_data:
        city = City.objects.filter(governorate=cairo_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=cairo_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    # ========== 6. محافظة الإسكندرية ==========
    alex_gov = get_or_create_governorate('الإسكندرية', 'Alexandria')
    
    alex_districts_data = [
        {'city': 'الإسكندرية', 'city_en': 'Alexandria', 'districts': [
            {'name_ar': 'سموحة', 'name_en': 'Smouha'},
            {'name_ar': 'سيدي جابر', 'name_en': 'Sidi Gaber'},
            {'name_ar': 'ميامي', 'name_en': 'Miami'},
            {'name_ar': 'العجمي', 'name_en': 'Al Agamy'},
        ]},
    ]
    
    for city_data in alex_districts_data:
        city = City.objects.filter(governorate=alex_gov, name_ar=city_data['city']).first()
        if not city:
            city = City.objects.create(governorate=alex_gov, name_ar=city_data['city'], name_en=city_data['city_en'])
        
        for dist in city_data['districts']:
            district = District.objects.filter(city=city, name_ar=dist['name_ar']).first()
            if not district:
                district = District.objects.create(city=city, name_ar=dist['name_ar'], name_en=dist['name_en'])
            all_districts.append(district)
    
    print(f"  ✅ 6 محافظات + {len(all_districts)} حي")
    return all_districts


def create_categories():
    """إنشاء تصنيفات شاملة مع أيقونات مصححة"""
    print("✅ إنشاء التصنيفات...")
    
    categories_data = [
        # مطاعم وكافيهات
        {'name_ar': 'مطاعم', 'name_en': 'Restaurants', 'icon': 'fas fa-utensils'},
        {'name_ar': 'مقاهي', 'name_en': 'Cafes', 'icon': 'fas fa-coffee'},
        {'name_ar': 'حلويات', 'name_en': 'Sweets', 'icon': 'fas fa-birthday-cake'},
        {'name_ar': 'مطاعم سريعة', 'name_en': 'Fast Food', 'icon': 'fas fa-hamburger'},
        
        # تسوق
        {'name_ar': 'ملابس وأزياء', 'name_en': 'Fashion', 'icon': 'fas fa-shopping-bag'},
        {'name_ar': 'إلكترونيات', 'name_en': 'Electronics', 'icon': 'fas fa-laptop'},
        {'name_ar': 'أثاث ومفروشات', 'name_en': 'Furniture', 'icon': 'fas fa-couch'},
        {'name_ar': 'مجوهرات', 'name_en': 'Jewelry', 'icon': 'fas fa-gem'},
        {'name_ar': 'كتب ومكتبات', 'name_en': 'Books', 'icon': 'fas fa-book'},
        {'name_ar': 'سوبر ماركت', 'name_en': 'Supermarket', 'icon': 'fas fa-shopping-cart'},
        
        # صحة
        {'name_ar': 'مستشفيات', 'name_en': 'Hospitals', 'icon': 'fas fa-hospital'},
        {'name_ar': 'عيادات طبية', 'name_en': 'Clinics', 'icon': 'fas fa-stethoscope'},
        {'name_ar': 'صيدليات', 'name_en': 'Pharmacies', 'icon': 'fas fa-pills'},
        {'name_ar': 'مراكز أسنان', 'name_en': 'Dental', 'icon': 'fas fa-tooth'},
        {'name_ar': 'مختبرات طبية', 'name_en': 'Labs', 'icon': 'fas fa-flask'},
        
        # تعليم
        {'name_ar': 'مدارس', 'name_en': 'Schools', 'icon': 'fas fa-school'},
        {'name_ar': 'جامعات', 'name_en': 'Universities', 'icon': 'fas fa-university'},
        {'name_ar': 'معاهد تدريب', 'name_en': 'Training', 'icon': 'fas fa-graduation-cap'},
        {'name_ar': 'حضانات', 'name_en': 'Nurseries', 'icon': 'fas fa-child'},
        
        # سيارات
        {'name_ar': 'معارض سيارات', 'name_en': 'Car Showrooms', 'icon': 'fas fa-car'},
        {'name_ar': 'ورش صيانة', 'name_en': 'Car Service', 'icon': 'fas fa-wrench'},
        {'name_ar': 'غسيل سيارات', 'name_en': 'Car Wash', 'icon': 'fas fa-soap'},
        {'name_ar': 'قطع غيار', 'name_en': 'Auto Parts', 'icon': 'fas fa-tools'},
        
        # جمال وعناية
        {'name_ar': 'صالونات تجميل', 'name_en': 'Beauty Salons', 'icon': 'fas fa-cut'},
        {'name_ar': 'صالونات رجالي', 'name_en': 'Barber Shops', 'icon': 'fas fa-user-tie'},
        {'name_ar': 'سبا ومساج', 'name_en': 'Spa', 'icon': 'fas fa-spa'},
        
        # رياضة
        {'name_ar': 'نوادي رياضية', 'name_en': 'Gyms', 'icon': 'fas fa-dumbbell'},
        {'name_ar': 'ملاعب رياضية', 'name_en': 'Sports Fields', 'icon': 'fas fa-futbol'},
        
        # ترفيه وسياحة
        {'name_ar': 'فنادق', 'name_en': 'Hotels', 'icon': 'fas fa-hotel'},
        {'name_ar': 'حدائق', 'name_en': 'Parks', 'icon': 'fas fa-tree'},
        {'name_ar': 'شواطئ', 'name_en': 'Beaches', 'icon': 'fas fa-water'},
        {'name_ar': 'سينما', 'name_en': 'Cinema', 'icon': 'fas fa-film'},
        
        # عبادة
        {'name_ar': 'مساجد', 'name_en': 'Mosques', 'icon': 'fas fa-mosque'},
        {'name_ar': 'كنائس', 'name_en': 'Churches', 'icon': 'fas fa-church'},
        
        # خدمات
        {'name_ar': 'بنوك', 'name_en': 'Banks', 'icon': 'fas fa-university'},
        {'name_ar': 'محطات وقود', 'name_en': 'Gas Stations', 'icon': 'fas fa-gas-pump'},
        {'name_ar': 'شحن ونقل', 'name_en': 'Shipping', 'icon': 'fas fa-truck'},
    ]
    
    created_categories = []
    for i, cat_data in enumerate(categories_data):
        category, created = Category.objects.get_or_create(
            slug=f"cat-{i+1}",
            defaults={
                'name_ar': cat_data['name_ar'],
                'name_en': cat_data['name_en'],
                'icon': cat_data['icon'],
                'is_active': True,
                'order': (i + 1) * 10,
            }
        )
        if not created and category.icon != cat_data['icon']:
            category.icon = cat_data['icon']
            category.save(update_fields=['icon'])
        created_categories.append(category)
    
    print(f"  ✅ {len(created_categories)} تصنيف")
    return created_categories


def create_businesses(owners, districts, categories):
    """إنشاء محلات وأماكن عامة"""
    print("✅ إنشاء المحلات والأماكن...")
    
    # تقسيم التصنيفات
    restaurants_cat = next((c for c in categories if 'مطاعم' in c.name_ar and 'سريعة' not in c.name_ar), categories[0])
    cafes_cat = next((c for c in categories if 'مقاهي' in c.name_ar), categories[1])
    hospitals_cat = next((c for c in categories if 'مستشفيات' in c.name_ar), categories[10])
    parks_cat = next((c for c in categories if 'حدائق' in c.name_ar), categories[30])
    beaches_cat = next((c for c in categories if 'شواطئ' in c.name_ar), categories[31])
    mosques_cat = next((c for c in categories if 'مساجد' in c.name_ar), categories[33])
    churches_cat = next((c for c in categories if 'كنائس' in c.name_ar), categories[34])
    
    businesses_data = [
        # مطاعم ومقاهي
        {'name_ar': 'مطعم النافورة', 'name_en': 'Al Nafora Restaurant', 'category': restaurants_cat, 'owner': 0},
        {'name_ar': 'كافيه السلام', 'name_en': 'Al Salam Cafe', 'category': cafes_cat, 'owner': 1},
        {'name_ar': 'مطعم البحر المتوسط', 'name_en': 'Mediterranean Restaurant', 'category': restaurants_cat, 'owner': 2},
        {'name_ar': 'مقهى القناة', 'name_en': 'Canal Cafe', 'category': cafes_cat, 'owner': 3},
        
        # حدائق عامة
        {'name_ar': 'حديقة السلام - الإسماعيلية', 'name_en': 'Al Salam Park', 'category': parks_cat, 'owner': 4, 'public': True},
        {'name_ar': 'حديقة الأطفال - بورسعيد', 'name_en': 'Children Park', 'category': parks_cat, 'owner': 4, 'public': True},
        {'name_ar': 'حديقة فريال - السويس', 'name_en': 'Ferial Park', 'category': parks_cat, 'owner': 4, 'public': True},
        
        # مستشفيات
        {'name_ar': 'مستشفى الإسماعيلية العام', 'name_en': 'Ismailia General Hospital', 'category': hospitals_cat, 'owner': 5, 'public': True},
        {'name_ar': 'مستشفى بورسعيد العام', 'name_en': 'Port Said General Hospital', 'category': hospitals_cat, 'owner': 5, 'public': True},
        {'name_ar': 'مستشفى السويس العام', 'name_en': 'Suez General Hospital', 'category': hospitals_cat, 'owner': 5, 'public': True},
        
        # شواطئ
        {'name_ar': 'شاطئ فايد العام', 'name_en': 'Fayed Public Beach', 'category': beaches_cat, 'owner': 6, 'public': True},
        {'name_ar': 'شاطئ بورسعيد الشعبي', 'name_en': 'Port Said Beach', 'category': beaches_cat, 'owner': 6, 'public': True},
        
        # مساجد
        {'name_ar': 'مسجد الشهداء - الإسماعيلية', 'name_en': 'Shohada Mosque', 'category': mosques_cat, 'owner': 4, 'public': True},
        {'name_ar': 'مسجد الفتح - بورسعيد', 'name_en': 'Al Fath Mosque', 'category': mosques_cat, 'owner': 4, 'public': True},
        
        # كنائس
        {'name_ar': 'كنيسة العذراء مريم - الإسماعيلية', 'name_en': 'Virgin Mary Church', 'category': churches_cat, 'owner': 5, 'public': True},
    ]
    
    created_businesses = []
    for i, bus_data in enumerate(businesses_data):
        district = districts[i % len(districts)]
        owner = owners[bus_data['owner']]
        is_public = bus_data.get('public', False)
        
        business, created = Business.objects.get_or_create(
            slug=f"biz-{i+1}",
            defaults={
                'name_ar': bus_data['name_ar'],
                'name_en': bus_data['name_en'],
                'description_ar': f"وصف {bus_data['name_ar']} - {'مكان عام مفتوح للجميع' if is_public else 'نقدم أفضل الخدمات'}",
                'description_en': f"{bus_data['name_en']} - {'Public place' if is_public else 'Best services'}",
                'owner': owner,
                'category': bus_data['category'],
                'district': district,
                'address_ar': f"{district.name_ar}، {district.city.name_ar}",
                'address_en': f"{district.name_en}, {district.city.name_en}",
                'phone': f"+2010{i+1:07d}",
                'email': f"info@biz{i+1}.com",
                'is_active': True,
                'is_verified': True,
                'is_featured': i < 5,
                'view_count': random.randint(50, 500),
            }
        )
        created_businesses.append(business)
    
    print(f"  ✅ {len(created_businesses)} محل ومكان")
    return created_businesses


def create_products(businesses):
    """إنشاء منتجات وخدمات"""
    print("✅ إنشاء المنتجات...")
    
    products_data = [
        {'name_ar': 'وجبة شاورما', 'name_en': 'Shawarma Meal', 'price': 45},
        {'name_ar': 'كابتشينو', 'name_en': 'Cappuccino', 'price': 25},
        {'name_ar': 'سمك مشوي', 'name_en': 'Grilled Fish', 'price': 120},
        {'name_ar': 'عصير برتقال', 'name_en': 'Orange Juice', 'price': 20},
    ]
    
    # فقط للمحلات التجارية
    commercial = [b for b in businesses if not any(x in b.name_ar for x in ['مسجد', 'كنيسة', 'شاطئ', 'حديقة', 'مستشفى'])]
    
    created_products = []
    for i, prod_data in enumerate(products_data[:len(commercial)]):
        product, created = Product.objects.get_or_create(
            slug=f"prod-{i+1}",
            defaults={
                'name_ar': prod_data['name_ar'],
                'name_en': prod_data['name_en'],
                'description_ar': f"وصف {prod_data['name_ar']}",
                'description_en': f"{prod_data['name_en']} description",
                'business': commercial[i],
                'product_type': 'product',
                'price': Decimal(str(prod_data['price'])),
                'is_available': True,
            }
        )
        created_products.append(product)
    
    print(f"  ✅ {len(created_products)} منتج")
    return created_products


def create_deals(businesses):
    """إنشاء عروض"""
    print("✅ إنشاء العروض...")
    
    now = datetime.now()
    commercial = [b for b in businesses if not any(x in b.name_ar for x in ['مسجد', 'كنيسة', 'شاطئ', 'حديقة', 'مستشفى'])]
    
    deals_data = [
        {'title_ar': 'خصم 50%', 'title_en': '50% Off', 'discount': 50, 'days': 10},
        {'title_ar': 'اشتر 2 احصل على 1', 'title_en': 'Buy 2 Get 1', 'discount': 33, 'days': 7},
    ]
    
    created_deals = []
    for i, deal_data in enumerate(deals_data[:len(commercial)]):
        deal, created = Deal.objects.get_or_create(
            slug=f"deal-{i+1}",
            defaults={
                'title_ar': deal_data['title_ar'],
                'title_en': deal_data['title_en'],
                'description_ar': f"عرض {deal_data['title_ar']}",
                'description_en': deal_data['title_en'],
                'business': commercial[i],
                'deal_type': 'percentage',
                'discount_percentage': deal_data['discount'],
                'start_date': now,
                'end_date': now + timedelta(days=deal_data['days']),
            }
        )
        created_deals.append(deal)
    
    print(f"  ✅ {len(created_deals)} عرض")
    return created_deals


def create_reviews(businesses, customers):
    """إنشاء تقييمات"""
    print("✅ إنشاء التقييمات...")
    
    comments = ['تجربة رائعة', 'خدمة ممتازة', 'مكان نظيف', 'أنصح به']
    
    created_reviews = []
    for i, business in enumerate(businesses[:5]):
        for j in range(3):
            customer = customers[(i * 3 + j) % len(customers)]
            review, created = Review.objects.get_or_create(
                business=business,
                user=customer,
                defaults={
                    'rating': random.choice([4, 5]),
                    'comment': comments[j % len(comments)],
                    'is_approved': True,
                }
            )
            created_reviews.append(review)
    
    print(f"  ✅ {len(created_reviews)} تقييم")
    return created_reviews


def main():
    """Main function"""
    print("\n" + "="*60)
    print("✨ بدء تحميل البيانات التجريبية لـ دليل أي خدمة")
    print("🌊 التركيز: مدن القناة + العاشر من رمضان + القاهرة والإسكندرية")
    print("="*60 + "\n")
    
    owners, customers = create_users()
    districts = create_locations()
    categories = create_categories()
    businesses = create_businesses(owners, districts, categories)
    products = create_products(businesses)
    deals = create_deals(businesses)
    reviews = create_reviews(businesses, customers)
    
    print("\n" + "="*60)
    print("✅ تم تحميل البيانات بنجاح!")
    print("="*60)
    print("\n📊 الإحصائيات:")
    print(f"  - المستخدمين: {len(owners)} + {len(customers)}")
    print(f"  - المحافظات: 6 (الإسماعيلية، بورسعيد، السويس، الشرقية، القاهرة، الإسكندرية)")
    print(f"  - الأحياء: {len(districts)}")
    print(f"  - التصنيفات: {len(categories)}")
    print(f"  - المحلات: {len(businesses)}")
    print(f"  - المنتجات: {len(products)}")
    print(f"  - العروض: {len(deals)}")
    print(f"  - التقييمات: {len(reviews)}")
    print("\n🔑 الدخول: ahmed_owner / test123")
    print("="*60 + "\n")


if __name__ == '__main__':
    main()
