# 🎯 Test Data Fixtures

## 📝 Overview

This directory contains comprehensive test data for the Daliil Ay Khidma dashboard.

## 🚀 Quick Start

### Method 1: Python Script (Recommended)

```bash
# From project root
python fixtures/load_test_data.py
```

### Method 2: Django Fixtures (if you have JSON fixtures)

```bash
python manage.py loaddata fixtures/test_data.json
```

## 👥 Test Users

### Business Owners

| Username | Password | Name | Email |
|----------|----------|------|-------|
| ahmed_owner | test123 | أحمد محمد | ahmed@test.com |
| fatima_owner | test123 | فاطمة علي | fatima@test.com |
| khaled_owner | test123 | خالد حسن | khaled@test.com |
| maha_owner | test123 | مها عبدالله | maha@test.com |
| omar_owner | test123 | عمر سعيد | omar@test.com |

### Customers

| Username | Password | Name |
|----------|----------|------|
| customer1 | test123 | محمد أحمد |
| customer2 | test123 | سارة خالد |
| customer3-10 | test123 | ... |

## 📋 Test Data Included

### 🏢 Businesses
- 10 businesses across different categories
- Mixed ownership between 5 owners
- Complete address and contact information
- Featured and verified businesses

### 🏷️ Categories
- مطاعم (Restaurants)
- مقاهي (Cafes)
- تسوق (Shopping)
- تقنية (Technology)
- صحة (Health)
- تعليم (Education)
- سيارات (Automotive)
- عقارات (Real Estate)

### 📍 Locations
- Riyadh Governorate
- Riyadh City
- 5 Districts:
  - العليا (Al Olaya)
  - الملز (Al Malaz)
  - النخيل (Al Nakheel)
  - العقيق (Al Aqeeq)
  - الربوة (Al Rabwah)

### 💻 Products & Services
- 10+ products and services
- Mix of physical products and services
- Price range: 15 SAR - 3500 SAR
- All marked as available

### 🎁 Deals
- **Active Deals** (3):
  - 50% off on meals
  - Buy 2 Get 1 Free
  - Back to school discount
- **Upcoming Deals** (2):
  - Eid Al Fitr offer
  - Summer sale
- **Expired Deals** (2):
  - Ramadan offer
  - Winter discount

### ⭐ Reviews
- 25 reviews total
- 5 reviews per business (first 5 businesses)
- Rating distribution:
  - 5 stars: 40%
  - 4 stars: 40%
  - 3 stars: 20%
- 10 reviews with owner replies
- 15 unreplied reviews

## 🧪 Testing Scenarios

### Dashboard Home
- View statistics cards
- Check recent activities
- View charts and graphs

### Business Management
- List all businesses
- Filter by category/status
- View business details
- Edit business information

### Product Management
- View products and services
- Filter by type/availability
- Add new products
- Edit existing products

### Deal Management
- View active/upcoming/expired deals
- Filter by status
- Create new deals
- Edit existing deals

### Review Management
- View all reviews
- Filter by rating/status
- Reply to reviews
- Approve/reject reviews

### Statistics Page
- View comprehensive analytics
- Check revenue charts
- View top performing businesses
- Analyze customer trends

## 🛠️ Troubleshooting

### Script Fails
```bash
# Make sure you're in the project root
cd /path/to/daliil-ay-khidma

# Activate virtual environment
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Run migrations first
python manage.py migrate

# Then run the script
python fixtures/load_test_data.py
```

### Data Already Exists
The script uses `get_or_create()` so it won't duplicate data. It's safe to run multiple times.

### Clear All Data
```bash
# Delete database (SQLite)
rm db.sqlite3

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Load test data
python fixtures/load_test_data.py
```

## ✅ Verification

After loading data, verify:

1. **Login** with any owner account
2. **Dashboard** shows statistics
3. **Businesses** page lists 10 businesses
4. **Products** page shows products
5. **Deals** page shows deals with different statuses
6. **Reviews** page shows reviews (some with replies)
7. **Statistics** page displays charts

## 📝 Notes

- All passwords are **test123** for easy testing
- Data is in Arabic and English
- Realistic Saudi business scenarios
- Complete relational data (no orphans)
- Dates are relative to current time

## 🚀 Next Steps

After loading test data:

1. Login to dashboard
2. Explore all features
3. Test filters and search
4. Try CRUD operations
5. Check pagination
6. Test forms and validation
7. Verify statistics accuracy

---

**Happy Testing! 🎉**
