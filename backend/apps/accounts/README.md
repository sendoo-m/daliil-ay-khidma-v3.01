# 👤 Accounts System - نظام الحسابات

نظام إدارة حسابات متكامل لدليل أي خدمة مع Custom User Model ونظام مصادقة كامل.

---

## 🎯 Overview

نظام حسابات احترافي مع:
- ✅ Custom User Model مخصص
- ✅ نظام تسجيل ودخول كامل
- ✅ إدارة الملف الشخصي
- ✅ استرجاع كلمة المرور
- ✅ صلاحيات متعددة
- ✅ Django Admin مخصص

---

## ✨ Features

### 🔐 Authentication
- ✅ **التسجيل (Register)** - إنشاء حساب جديد مع تحقق من البيانات
- ✅ **تسجيل الدخول (Login)** - دخول آمن مع session management
- ✅ **تسجيل الخروج (Logout)** - خروج آمن
- ✅ **استرجاع كلمة المرور** - عبر البريد الإلكتروني
- ✅ **تغيير كلمة المرور** - للمستخدمين المسجلين

### 👤 Profile Management
- ✅ **عرض الملف الشخصي** - صفحة profile كاملة
- ✅ **تحديث البيانات** - تعديل المعلومات الشخصية
- ✅ **رفع صورة شخصية** - مع معاينة
- ✅ **نبذة شخصية (Bio)** - وصف عن المستخدم
- ✅ **معلومات الموقع** - المدينة

### 📱 Custom User Model
- ✅ **رقم الهاتف** - إلزامي مع تحقق من الصيغة المصرية
- ✅ **البريد الإلكتروني** - فريد مع إمكانية التحقق
- ✅ **صورة شخصية** - مع رابط افتراضي
- ✅ **نوع الحساب** - Owner/Admin/User
- ✅ **حالة التفعيل** - email_verified

---

## 📚 User Model Documentation

### Model Fields

```python
class User(AbstractUser):
    # الحقول الأساسية من AbstractUser
    username            # اسم المستخدم (فريد)
    first_name          # الاسم الأول
    last_name           # الاسم الأخير
    email               # البريد الإلكتروني (فريد)
    
    # الحقول المخصصة
    phone               # رقم الهاتف المصري (01xxxxxxxxx) - فريد وإلزامي
    profile_picture     # الصورة الشخصية (اختياري)
    bio                 # نبذة شخصية (500 حرف كحد أقصى)
    city                # المدينة (اختياري)
    
    # حالة الحساب
    email_verified      # تم التحقق من البريد؟ (Boolean)
    is_business_owner   # صاحب محل؟ (Boolean)
    is_active           # الحساب نشط؟
    is_staff            # موظف إداري؟
    is_superuser        # مدير أعلى؟
    
    # التواريخ
    date_joined         # تاريخ الانضمام
    last_login          # آخر تسجيل دخول
    created_at          # تاريخ الإنشاء (auto)
    updated_at          # تاريخ التحديث (auto)
```

### Properties & Methods

```python
# Properties
user.full_name                    # الاسم الكامل (first + last) أو username
user.has_businesses               # هل لديه محلات نشطة؟ (Boolean)
user.total_businesses             # عدد المحلات النشطة (Integer)

# Methods
user.get_profile_picture_url()    # رابط الصورة الشخصية أو الافتراضية
user.__str__()                    # إرجاع username
```

---

## 🛣️ URL Structure

### Authentication URLs
```
/accounts/register/                              # صفحة التسجيل
/accounts/login/                                 # صفحة تسجيل الدخول
/accounts/logout/                                # تسجيل الخروج
```

### Profile URLs
```
/accounts/profile/                               # الملف الشخصي
```

### Password Management URLs
```
/accounts/password/change/                       # تغيير كلمة المرور
/accounts/password/reset/                        # طلب استرجاع كلمة المرور
/accounts/password/reset/done/                   # تم إرسال البريد
/accounts/password/reset/<uidb64>/<token>/       # تأكيد الاسترجاع
/accounts/password/reset/complete/               # تم الاسترجاع بنجاح
```

---

## 📝 Forms Documentation

### 1️⃣ RegistrationForm
**الغرض:** إنشاء حساب مستخدم جديد

**الحقول:**
- `username` - اسم المستخدم (فريد، إلزامي)
- `email` - البريد الإلكتروني (فريد، إلزامي)
- `phone` - رقم الهاتف المصري (فريد، إلزامي)
- `password1` - كلمة المرور (إلزامي)
- `password2` - تأكيد كلمة المرور (إلزامي)

**التحقق:**
- التأكد من عدم تكرار البريد الإلكتروني
- التأكد من عدم تكرار رقم الهاتف
- التحقق من صيغة رقم الهاتف المصري
- تطابق كلمتي المرور

### 2️⃣ LoginForm
**الغرض:** تسجيل دخول المستخدم

**الحقول:**
- `username` - اسم المستخدم أو البريد الإلكتروني
- `password` - كلمة المرور

### 3️⃣ ProfileUpdateForm
**الغرض:** تحديث بيانات الملف الشخصي

**الحقول:**
- `first_name` - الاسم الأول (اختياري)
- `last_name` - الاسم الأخير (اختياري)
- `email` - البريد الإلكتروني (فريد)
- `phone` - رقم الهاتف (فريد)
- `profile_picture` - الصورة الشخصية (اختياري)
- `bio` - نبذة شخصية (اختياري، 500 حرف)
- `city` - المدينة (اختياري)

**التحقق:**
- عدم تكرار البريد (باستثناء المستخدم الحالي)
- عدم تكرار الهاتف (باستثناء المستخدم الحالي)

### 4️⃣ PasswordChangeForm
**الغرض:** تغيير كلمة المرور للمستخدم المسجل

**الحقول:**
- `old_password` - كلمة المرور الحالية
- `new_password1` - كلمة المرور الجديدة
- `new_password2` - تأكيد كلمة المرور الجديدة

### 5️⃣ PasswordResetForm
**الغرض:** طلب استرجاع كلمة المرور

**الحقول:**
- `email` - البريد الإلكتروني

### 6️⃣ SetPasswordForm
**الغرض:** تعيين كلمة مرور جديدة بعد الاسترجاع

**الحقول:**
- `new_password1` - كلمة المرور الجديدة
- `new_password2` - تأكيد كلمة المرور

---

## 🛠️ Setup Instructions

### 1. Install App (Already Done ✅)

```python
# settings/base.py or config/settings.py

INSTALLED_APPS = [
    # Django Apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Local Apps
    'apps.accounts',        # ✅
    'apps.dashboard',
    'apps.directory',
    # ...
]
```

### 2. Set Custom User Model (Required)

```python
# settings/base.py

# Custom User Model
AUTH_USER_MODEL = 'accounts.User'
```

### 3. Configure Authentication Settings

```python
# settings/base.py

# Login/Logout URLs
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/dashboard/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# Password Validators
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
```

### 4. Add URLs (Already Done ✅)

```python
# config/urls.py

from django.urls import path, include

urlpatterns = [
    # ...
    path('accounts/', include('apps.accounts.urls', namespace='accounts')),  # ✅
    # ...
]
```

### 5. Configure Media Files

```python
# settings/base.py

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Media files (uploads)
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
```

### 6. Run Migrations

```bash
# Create migrations
python manage.py makemigrations accounts

# Apply migrations
python manage.py migrate
```

### 7. Create Superuser

```bash
python manage.py createsuperuser

# سيطلب منك:
# - Username
# - Email
# - Phone (01xxxxxxxxx)
# - Password
```

### 8. Collect Static Files (Production)

```bash
python manage.py collectstatic
```

---

## 📊 Django Admin Panel

### Features

#### 📋 List Display
- Username
- Email
- Phone Number
- Full Name
- Profile Picture (thumbnail)
- Account Type Badge (Superuser/Admin/Owner/User)
- Email Verification Status
- Active Status
- Date Joined

#### 🔍 Search & Filter

**Search Fields:**
- Username
- Email
- Phone
- First Name
- Last Name

**Filter Options:**
- Account Type (Business Owner)
- Email Verified Status
- Active Status
- Staff Status
- Superuser Status
- Date Joined

#### ⚡ Bulk Actions

1. **تفعيل البريد الإلكتروني** - Verify emails for selected users
2. **تحويل لصاحب محل** - Convert to business owner
3. **تفعيل المستخدمين** - Activate selected users

#### 🎨 Custom Display

- **Profile Picture:** Shows circular thumbnail or initial letter
- **Account Type Badge:** Color-coded badges
  - 🔑 Red: Superuser
  - ⚙️ Orange: Admin
  - 🏪 Blue: Business Owner
  - 👤 Green: Regular User
- **Email Status:** ✓ مفعّل or ⚠ غير مفعّل

---

## 🎯 Usage Examples

### في Views

```python
from django.contrib.auth.decorators import login_required
from apps.accounts.models import User

@login_required
def my_view(request):
    user = request.user
    
    # الوصول للحقول
    print(f"Username: {user.username}")
    print(f"Email: {user.email}")
    print(f"Phone: {user.phone}")
    print(f"Full Name: {user.full_name}")
    print(f"Profile Picture: {user.get_profile_picture_url()}")
    
    # التحقق من نوع الحساب
    if user.is_business_owner:
        print("This user is a business owner")
    
    # التحقق من المحلات
    if user.has_businesses:
        businesses = user.businesses.all()
        print(f"Total businesses: {user.total_businesses}")
    
    # التحقق من تفعيل البريد
    if user.email_verified:
        print("Email is verified")
```

### في Templates

```django
{% if user.is_authenticated %}
    <div class="user-info">
        <img src="{{ user.get_profile_picture_url }}" alt="Profile">
        <h3>مرحباً {{ user.full_name }}</h3>
        <p>{{ user.email }}</p>
        <p>{{ user.phone }}</p>
        
        {% if user.is_business_owner %}
            <span class="badge">🏪 صاحب محل</span>
            <p>عدد المحلات: {{ user.total_businesses }}</p>
        {% endif %}
        
        {% if not user.email_verified %}
            <div class="alert alert-warning">
                ⚠️ يرجى تفعيل بريدك الإلكتروني
            </div>
        {% endif %}
    </div>
{% else %}
    <a href="{% url 'accounts:login' %}">تسجيل الدخول</a>
    <a href="{% url 'accounts:register' %}">إنشاء حساب</a>
{% endif %}
```

### في Models (Foreign Key)

```python
from django.db import models
from django.conf import settings

class Business(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='businesses'
    )
    name = models.CharField(max_length=200)
    # ...
```

---

## 🔒 Security Features

### ✅ Implemented

1. **Password Validation**
   - Minimum length requirement
   - Common password check
   - User attribute similarity check
   - Numeric-only password prevention

2. **Phone Validation**
   - Egyptian format only: `01[0-2,5]{1}[0-9]{8}`
   - Examples: 01012345678, 01123456789, 01234567890, 01512345678
   - Uniqueness enforced

3. **Email Protection**
   - Uniqueness enforced
   - Format validation
   - Verification system ready

4. **Form Security**
   - CSRF protection on all forms
   - XSS prevention through Django templates
   - SQL injection prevention (ORM)

5. **Session Management**
   - Secure session cookies
   - Session invalidation on logout
   - Password change updates session

6. **Access Control**
   - `@login_required` decorator
   - Permission-based views
   - Owner-only access checks

---

## 🧪 Testing

### Run Tests

```bash
# Run all account tests
python manage.py test apps.accounts

# Run with verbosity
python manage.py test apps.accounts -v 2

# Test specific module
python manage.py test apps.accounts.tests.test_models
```

### Check Migrations

```bash
# Dry run
python manage.py makemigrations --dry-run

# Show plan
python manage.py migrate --plan

# Check for issues
python manage.py check
```

### Manual Testing Checklist

- [ ] التسجيل بحساب جديد
- [ ] تسجيل الدخول
- [ ] تحديث الملف الشخصي
- [ ] رفع صورة شخصية
- [ ] تغيير كلمة المرور
- [ ] استرجاع كلمة المرور (يتطلب إعداد SMTP)
- [ ] تسجيل الخروج
- [ ] التحقق من صلاحيات الوصول

---

## 🚀 Future Enhancements

### Planned Features

- [ ] **Email Verification (2FA)**
  - Send verification email on registration
  - Verify email before full access
  
- [ ] **Social Login**
  - Google OAuth
  - Facebook Login
  - Twitter/X Login

- [ ] **Phone SMS Verification**
  - Send OTP on registration
  - Verify phone number

- [ ] **Profile Completion Progress**
  - Show percentage complete
  - Encourage users to complete profile

- [ ] **Activity Logs**
  - Track user actions
  - Login history
  - Profile changes log

- [ ] **API Authentication**
  - JWT tokens
  - Token refresh
  - API key management

- [ ] **Two-Factor Authentication (2FA)**
  - TOTP (Google Authenticator)
  - SMS backup codes

---

## 📞 Contact & Support

**Project:** Daliil Ay Khidma  
**Module:** Accounts System  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

---

## 📝 License

Part of Daliil Ay Khidma project.
