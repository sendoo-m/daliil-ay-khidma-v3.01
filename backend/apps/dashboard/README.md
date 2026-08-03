# 🎨 Dashboard System

نظام لوحات التحكم لإدارة دليل أي خدمة

## 🎯 Overview

يحتوي النظام على لوحتي تحكم منفصلتين:

### 1️⃣ Owner Dashboard (لوحة أصحاب المحلات)
لوحة تحكم كاملة لأصحاب المحلات لإدارة:
- 🏪 **المحلات** - إضافة، تعديل، حذف (محل تجاري، حرفة، خدمة عامة)
- 📦 **المنتجات** - إدارة المنتجات والخدمات بأسعار مختلفة
- 🎁 **العروض** - إنشاء وإدارة العروض والخصومات
- ⭐ **التعليقات** - الرد على تعليقات العملاء
- 📊 **إحصائيات** - متابعة المشاهدات والتقييمات

### 2️⃣ Admin Dashboard (لوحة الإدارة)
لوحة تحكم شاملة للمديرين للتحكم في:
- 👥 **المستخدمين** - إضافة، تعديل، حذف، إدارة كلمات المرور
- 🏪 **المحلات** - موافقة، تفعيل، تعديل، حذف
- 📍 **المناطق** - إدارة المحافظات، المدن، والأحياء
- 🏷️ **التصنيفات** - إدارة التصنيفات
- 📦 **المنتجات** - مراجعة وحذف المنتجات
- 🎁 **العروض** - إدارة وتمييز العروض
- ⭐ **التعليقات** - موافقة أو حذف التعليقات

---

## 🛣️ URL Structure

### Owner Dashboard
```
/dashboard/                              # الرئيسية

/dashboard/businesses/                   # قائمة المحلات
/dashboard/businesses/create/            # إضافة محل
/dashboard/businesses/<slug>/            # تفاصيل المحل
/dashboard/businesses/<slug>/edit/       # تعديل محل
/dashboard/businesses/<slug>/delete/     # حذف محل

/dashboard/products/                     # قائمة المنتجات
/dashboard/products/create/              # إضافة منتج
/dashboard/products/<slug>/edit/         # تعديل منتج
/dashboard/products/<slug>/delete/       # حذف منتج

/dashboard/deals/                        # قائمة العروض
/dashboard/deals/create/                 # إضافة عرض

/dashboard/reviews/                      # قائمة التعليقات
/dashboard/reviews/<pk>/reply/           # الرد على تعليق
```

### Admin Dashboard
```
/dashboard/admin/                        # الرئيسية

/dashboard/admin/users/                  # قائمة المستخدمين
/dashboard/admin/users/<pk>/             # تفاصيل مستخدم
/dashboard/admin/users/<pk>/toggle-active/  # تفعيل/تعطيل
/dashboard/admin/users/<pk>/delete/      # حذف

/dashboard/admin/businesses/             # قائمة المحلات
/dashboard/admin/businesses/<slug>/verify/  # موافقة
/dashboard/admin/businesses/<slug>/toggle-active/  # تفعيل/تعطيل
/dashboard/admin/businesses/<slug>/delete/  # حذف

/dashboard/admin/categories/             # إدارة التصنيفات
/dashboard/admin/locations/              # إدارة المناطق

/dashboard/admin/products/               # قائمة المنتجات
/dashboard/admin/products/<slug>/delete/ # حذف

/dashboard/admin/deals/                  # قائمة العروض
/dashboard/admin/deals/<slug>/toggle-featured/  # تمييز
/dashboard/admin/deals/<slug>/delete/    # حذف

/dashboard/admin/reviews/                # قائمة التعليقات
/dashboard/admin/reviews/<pk>/approve/   # موافقة
/dashboard/admin/reviews/<pk>/delete/    # حذف
```

---

## 🛡️ Permissions

### Owner Dashboard
- يتطلب تسجيل الدخول (`@login_required`)
- يتطلب أن يكون لدى المستخدم محل واحد على الأقل (`@business_owner_required`)
- يمكن فقط إدارة محلاته الخاصة

### Admin Dashboard
- يتطلب أن يكون المستخدم `staff` (`@admin_required`)
- تحكم كامل في جميع البيانات

---

## 📊 Features

### Owner Dashboard Features

#### 🏪 Business Management
- إضافة محل جديد (محل تجاري، حرفة، خدمة عامة)
- تعديل بيانات المحل
- رفع صور (لوجو، cover image)
- إضافة معلومات الاتصال
- ربط Social Media
- حذف المحل

#### 📦 Product Management
- إضافة منتجات متعددة
- تحديد أسعار مختلفة
- إضافة خصومات (old price)
- رفع صور متعددة
- تعديل وحذف المنتجات
- تفعيل/تعطيل المنتج

#### 🎁 Deal Management
- إنشاء عروض بأنواع مختلفة
- تحديد فترة العرض
- متابعة العروض النشطة/المنتهية

#### ⭐ Review Management
- عرض كل التعليقات
- الرد على التعليقات
- متابعة التعليقات المنتظرة (بدون رد)

#### 📊 Statistics
- إجمالي المشاهدات
- متوسط التقييم
- عدد التعليقات
- عدد المنتجات والعروض

### Admin Dashboard Features

#### 👥 User Management
- عرض كل المستخدمين
- بحت وفلترة
- تفعيل/تعطيل مستخدم
- حذف مستخدم
- عرض تفاصيل كل مستخدم

#### 🏪 Business Management
- موافقة المحلات الجديدة
- تفعيل/تعطيل المحلات
- حذف المحلات
- فلتر حسب النوع (محل، حرفة، خدمة عامة)
- فلتر حسب الحالة (منتظر، نشط، معتمد)

#### 📍 Location Management
- إدارة المحافظات
- إدارة المدن
- إدارة الأحياء

#### 🏷️ Category Management
- عرض كل التصنيفات
- إحصائيات التصنيفات

#### ⭐ Review Moderation
- مراجعة التعليقات الجديدة
- موافقة أو حذف التعليقات
- فلتر حسب الحالة

#### 📦 Product & Deal Management
- مراجعة جميع المنتجات
- حذف منتجات غير مناسبة
- تمييز العروض
- إدارة العروض

---

## 🛠️ Setup Instructions

### 1. إضافة للـ INSTALLED_APPS

```python
# config/settings.py

INSTALLED_APPS = [
    # ...
    'apps.dashboard',
    # ...
]
```

### 2. إضافة للـ URLs

```python
# config/urls.py

from django.urls import path, include

urlpatterns = [
    # ...
    path('dashboard/', include('apps.dashboard.urls')),
    # ...
]
```

### 3. Run Migrations

```bash
python manage.py migrate
```

### 4. Create Superuser

```bash
python manage.py createsuperuser
```

---

## 🎯 Usage

### لصاحب محل:
1. تسجيل الدخول
2. زيارة `/dashboard/`
3. إضافة محل جديد
4. إضافة منتجات/خدمات
5. إنشاء عروض
6. الرد على التعليقات

### للمدير:
1. تسجيل الدخول كـ staff/admin
2. زيارة `/dashboard/admin/`
3. مراجعة وموافقة المحلات الجديدة
4. إدارة المستخدمين
5. مراجعة التعليقات

---

## 👨‍💻 Development Notes

### TODO:
- [ ] إضافة ModelForms لتسهيل النماذج
- [ ] إضافة Pagination للقوائم
- [ ] إضافة Templates (سيتم لاحقاً)
- [ ] إضافة Ajax للعمليات السريعة
- [ ] إضافة Charts للإحصائيات
- [ ] تحسين UI/UX

### Future Enhancements:
- Export data (CSV, Excel)
- Bulk operations
- Email notifications
- Activity logs
- Advanced analytics

---

## ⚠️ Important Notes

1. **Security**: جميع العمليات محمية بـ decorators
2. **Permissions**: Owner يرى فقط محلاته، Admin يرى كل شيء
3. **Validation**: يجب إضافة validation أكثر في المستقبل
4. **Templates**: Templates سيتم إضافتها لاحقاً

---

## 📝 License

Part of Daliil Ay Khidma project
