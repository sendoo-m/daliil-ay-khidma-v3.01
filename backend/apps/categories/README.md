# 🏷️ Categories System - نظام التصنيفات

نظام تصنيفات هرمي متكامل لدليل أي خدمة مع دعم أنواع المحلات الثلاثة.

---

## 🎯 Overview

نظام تصنيفات متطور يدعم:
- ✅ **3 أنواع محلات:** Shop (محل تجاري) | Craft (حرفة) | Public (خدمات عامة)
- ✅ **تصنيفات هرمية** - Parent & Child categories
- ✅ **ثنائي اللغة** - عربي / English
- ✅ **SEO محسّن** - Meta keywords, Slugs
- ✅ **أيقونات وصور** - Font Awesome + Images
- ✅ **ترتيب مخصص** - Custom ordering

---

## 📊 Category Types by Business Type

### 🏪 Shop Categories (محلات تجارية)
أمثلة:
- 🍔 مطاعم ومقاهي (Restaurants & Cafes)
- 🛍️ تسوّق (Shopping)
- 💻 إلكترونيات (Electronics)
- 👗 ملابس (Clothing)
- 🏪 سوبر ماركت (Supermarkets)

### 🔧 Craft Categories (حرف وخدمات)
أمثلة:
- 🔧 سباكة (Plumbing)
- ⚡ كهرباء (Electricians)
- 🔨 نجارة (Carpentry)
- 🎨 دهانات (Painters)
- 🧱 محارة (Plastering)
- 🛠️ صيانة (Maintenance)

### 🏛️ Public Service Categories (خدمات عامة)
أمثلة:
- 🏥 مستشفيات حكومية (Public Hospitals)
- 👮 مراكز الشرطة (Police Stations)
- 🚒 المطافئ (Fire Stations)
- ⚽ ملاعب عامة (Public Playgrounds)
- 🌳 حدائق عامة (Public Parks)
- 📚 مكتبات عامة (Public Libraries)

---

## 📚 Model Documentation

### Category Model Fields

```python
class Category(models.Model):
    # البنية الهرمية
    parent = ForeignKey('self')      # التصنيف الأب (اختياري)
    
    # الأسماء
    name_en = CharField()            # الاسم بالإنجليزية
    name_ar = CharField()            # الاسم بالعربية
    slug = SlugField()               # URL Slug (فريد)
    
    # الوصف
    description_en = TextField()     # الوصف بالإنجليزية
    description_ar = TextField()     # الوصف بالعربية
    
    # المظهر
    icon = CharField()               # Font Awesome icon
    image = ImageField()             # صورة التصنيف
    order = IntegerField()           # ترتيب العرض
    
    # الحالة
    is_active = BooleanField()       # نشط/غير نشط
    
    # SEO
    meta_keywords_en = CharField()   # كلمات SEO بالإنجليزية
    meta_keywords_ar = CharField()   # كلمات SEO بالعربية
    
    # التواريخ
    created_at = DateTimeField()     # تاريخ الإنشاء
    updated_at = DateTimeField()     # تاريخ التحديث
```

### Properties & Methods

```python
# Properties
category.name                          # الاسم حسب اللغة الحالية
category.description                   # الوصف حسب اللغة الحالية

# Methods
category.get_absolute_url()            # رابط صفحة التصنيف
category.get_business_count()          # عدد المحلات في هذا التصنيف
category.get_all_business_count()      # عدد المحلات مع التصنيفات الفرعية
category.children.all()                # جميع التصنيفات الفرعية
```

---

## 🛠️ Setup Instructions

### 1. Install App

```python
# settings/base.py

INSTALLED_APPS = [
    # ...
    'apps.categories',   # ✅ Add this
    'apps.directory',    # Required (contains Category model)
    # ...
]
```

### 2. Run Migrations

```bash
# Category model is in apps.directory
python manage.py makemigrations directory
python manage.py migrate
```

### 3. Create Sample Categories

```bash
python manage.py shell
```

```python
from apps.directory.models import Category

# 🏪 Shop Categories
shops = Category.objects.create(
    name_en="Shops & Stores",
    name_ar="محلات تجارية",
    icon="fas fa-store",
    order=1
)

Category.objects.create(
    parent=shops,
    name_en="Restaurants",
    name_ar="مطاعم",
    icon="fas fa-utensils",
    order=1
)

# 🔧 Craft Categories
crafts = Category.objects.create(
    name_en="Crafts & Services",
    name_ar="حرف وخدمات",
    icon="fas fa-tools",
    order=2
)

Category.objects.create(
    parent=crafts,
    name_en="Plumbing",
    name_ar="سباكة",
    icon="fas fa-wrench",
    order=1
)

# 🏛️ Public Service Categories
public = Category.objects.create(
    name_en="Public Services",
    name_ar="خدمات عامة",
    icon="fas fa-landmark",
    order=3
)

Category.objects.create(
    parent=public,
    name_en="Public Hospitals",
    name_ar="مستشفيات حكومية",
    icon="fas fa-hospital",
    order=1
)
```

---

## 📊 Django Admin Panel

### Features

#### 📋 List Display
- Icon preview
- Name (English & Arabic)
- Parent category
- Business count (with subcategories)
- Order badge
- Status badge
- Created date

#### 🔍 Search & Filter

**Search Fields:**
- Name (English/Arabic)
- Slug
- Description

**Filter Options:**
- Active Status
- Parent Category
- Created Date

#### ⚡ Bulk Actions

1. **تفعيل التصنيفات** - Activate selected categories
2. **تعطيل التصنيفات** - Deactivate selected categories

#### 🎨 Custom Display

- **Icon Display:** Shows Font Awesome icon
- **Business Count:** Shows count with subcategories in gray
- **Order Badge:** Blue rounded badge
- **Status Badge:** Green (نشط) or Red (غير نشط)
- **Image Preview:** Shows uploaded image or "no image" message

---

## 🎯 Usage Examples

### في Views

```python
from apps.directory.models import Category

# جلب التصنيفات الرئيسية فقط
def get_main_categories():
    return Category.objects.filter(
        parent=None,
        is_active=True
    ).order_by('order')

# جلب تصنيف مع فروعه
def get_category_with_children(slug):
    category = Category.objects.get(slug=slug, is_active=True)
    children = category.children.filter(is_active=True)
    return category, children

# عدد المحلات في تصنيف
def get_category_stats(category):
    direct_count = category.get_business_count()
    total_count = category.get_all_business_count()
    return {
        'direct': direct_count,
        'total': total_count,
        'has_subcategories': total_count > direct_count
    }
```

### في Templates

```django
{# عرض التصنيفات الرئيسية #}
<div class="categories-grid">
    {% for category in main_categories %}
        <div class="category-card">
            <i class="{{ category.icon }}"></i>
            <h3>{{ category.name }}</h3>
            <p>{{ category.description|truncatewords:20 }}</p>
            <span class="badge">{{ category.get_business_count }} محل</span>
        </div>
    {% endfor %}
</div>

{# عرض التصنيفات الفرعية #}
<h2>{{ category.name }}</h2>
{% if category.children.exists %}
    <ul class="subcategories">
        {% for child in category.children.all %}
            <li>
                <a href="{{ child.get_absolute_url }}">
                    <i class="{{ child.icon }}"></i>
                    {{ child.name }}
                    <span>({{ child.get_business_count }})</span>
                </a>
            </li>
        {% endfor %}
    </ul>
{% endif %}
```

### في API

```python
# Get categories filtered by business type
from apps.directory.models import Category, Business

def get_categories_for_shops():
    """Get categories that have shop businesses"""
    return Category.objects.filter(
        businesses__business_type='shop',
        is_active=True
    ).distinct()

def get_categories_for_crafts():
    """Get categories that have craft businesses"""
    return Category.objects.filter(
        businesses__business_type='craft',
        is_active=True
    ).distinct()

def get_categories_for_public():
    """Get categories that have public service businesses"""
    return Category.objects.filter(
        businesses__business_type='public',
        is_active=True
    ).distinct()
```

---

## 🔒 Best Practices

### ✅ Do's

1. **استخدم slug للURLs** - SEO-friendly
2. **ضع order مناسب** - للترتيب الصحيح
3. **املأ meta_keywords** - للSEO
4. **استخدم icons واضحة** - Font Awesome
5. **فعّل is_active** - للتحكم في العرض

### ❌ Don'ts

1. **لا تحذف تصنيف به محلات** - عطّله فقط
2. **لا تستخدم نفس slug** - يجب أن يكون فريد
3. **لا تترك name فارغ** - في اللغتين
4. **لا تعمل nesting أكثر من مستويين** - يعقد البنية

---

## 🚀 Future Enhancements

### Planned Features

- [ ] **Business Type Filter**
  - Add `business_types` ManyToManyField
  - Filter categories by business type
  
- [ ] **Category Tags**
  - Additional tagging system
  - Flexible categorization

- [ ] **Custom Icons**
  - Upload custom SVG icons
  - Icon color customization

- [ ] **Analytics**
  - Category popularity
  - View counts
  - Conversion tracking

- [ ] **Multi-level Support**
  - Support more than 2 levels
  - Breadcrumb navigation

---

## 📞 Contact & Support

**Project:** Daliil Ay Khidma  
**Module:** Categories System  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

---

## 📝 License

Part of Daliil Ay Khidma project.
