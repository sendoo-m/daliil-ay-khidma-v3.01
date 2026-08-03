"""
Custom Translation System
=========================
نظام ترجمة مخصص شامل
"""

TRANSLATIONS = {
    # Navbar
    'Home': {'ar': 'الرئيسية', 'en': 'Home'},
    'Businesses': {'ar': 'المحلات', 'en': 'Businesses'},
    'Categories': {'ar': 'التصنيفات', 'en': 'Categories'},
    'Deals': {'ar': 'العروض', 'en': 'Deals'},
    'Locations': {'ar': 'المواقع', 'en': 'Locations'},
    'All Governorates': {'ar': 'جميع المحافظات', 'en': 'All Governorates'},
    'Dashboard': {'ar': 'لوحة التحكم', 'en': 'Dashboard'},
    'My Businesses': {'ar': 'محلاتي', 'en': 'My Businesses'},
    'Admin Panel': {'ar': 'لوحة الإدارة', 'en': 'Admin Panel'},
    'Logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    'Login': {'ar': 'تسجيل الدخول', 'en': 'Login'},
    'Register': {'ar': 'إنشاء حساب', 'en': 'Register'},
    'Search': {'ar': 'بحث', 'en': 'Search'},
    'Search for businesses, services...': {'ar': 'ابحث عن محلات، خدمات...', 'en': 'Search for businesses, services...'},
    'Hot': {'ar': 'ساخن', 'en': 'Hot'},
    
    # Common
    'View Details': {'ar': 'عرض التفاصيل', 'en': 'View Details'},
    'View All': {'ar': 'عرض الكل', 'en': 'View All'},
    'View All Businesses': {'ar': 'عرض جميع المحلات', 'en': 'View All Businesses'},
    'View All Categories': {'ar': 'عرض جميع التصنيفات', 'en': 'View All Categories'},
    'View All Deals': {'ar': 'عرض جميع العروض', 'en': 'View All Deals'},
    'businesses': {'ar': 'محل', 'en': 'businesses'},
    'Active Deals': {'ar': 'العروض النشطة', 'en': 'Active Deals'},
    'Featured': {'ar': 'مميز', 'en': 'Featured'},
    'Verified': {'ar': 'موثق', 'en': 'Verified'},
    'Hot Deal': {'ar': 'عرض ساخن', 'en': 'Hot Deal'},
    'Browse by Category': {'ar': 'تصفح حسب التصنيف', 'en': 'Browse by Category'},
    'Find businesses in different categories': {'ar': 'ابحث عن المحلات في مختلف التصنيفات', 'en': 'Find businesses in different categories'},
    'Featured Businesses': {'ar': 'محلات مميزة', 'en': 'Featured Businesses'},
    'Top rated and verified businesses': {'ar': 'محلات مميزة وموثقة', 'en': 'Top rated and verified businesses'},
    'Hot Deals': {'ar': 'عروض ساخنة', 'en': 'Hot Deals'},
    "Don't miss these amazing offers": {'ar': 'لا تفوت هذه العروض المذهلة', 'en': "Don't miss these amazing offers"},
    'Do you own a business?': {'ar': 'هل تملك محل تجاري؟', 'en': 'Do you own a business?'},
    'Join thousands of businesses and reach more customers': {'ar': 'انضم لآلاف المحلات واصل لعملاء أكثر', 'en': 'Join thousands of businesses and reach more customers'},
    'Add Your Business': {'ar': 'أضف محلك', 'en': 'Add Your Business'},
    'No results found': {'ar': 'لا توجد نتائج', 'en': 'No results found'},
    'No businesses found': {'ar': 'لا توجد محلات', 'en': 'No businesses found'},
    'No deals found': {'ar': 'لا توجد عروض', 'en': 'No deals found'},
    'Check back later for new deals': {'ar': 'تحقق لاحقاً من العروض الجديدة', 'en': 'Check back later for new deals'},
    
    # Filters & Sorting
    'All Types': {'ar': 'جميع الأنواع', 'en': 'All Types'},
    'Percentage Discount': {'ar': 'خصم بالنسبة', 'en': 'Percentage Discount'},
    'Fixed Discount': {'ar': 'خصم ثابت', 'en': 'Fixed Discount'},
    'Buy One Get One': {'ar': 'اشتري واحد واحصل على آخر', 'en': 'Buy One Get One'},
    'Reset': {'ar': 'إعادة تعيين', 'en': 'Reset'},
    'Found': {'ar': 'تم العثور على', 'en': 'Found'},
    'results for': {'ar': 'نتيجة لـ', 'en': 'results for'},
    'All Businesses': {'ar': 'جميع المحلات', 'en': 'All Businesses'},
    'Filters': {'ar': 'التصفية', 'en': 'Filters'},
    'Category': {'ar': 'التصنيف', 'en': 'Category'},
    'All Categories': {'ar': 'جميع التصنيفات', 'en': 'All Categories'},
    'Governorate': {'ar': 'المحافظة', 'en': 'Governorate'},
    'Sort By': {'ar': 'ترتيب حسب', 'en': 'Sort By'},
    'Newest First': {'ar': 'الأحدث أولاً', 'en': 'Newest First'},
    'Oldest First': {'ar': 'الأقدم أولاً', 'en': 'Oldest First'},
    'Most Popular': {'ar': 'الأكثر شعبية', 'en': 'Most Popular'},
    'Name (A-Z)': {'ar': 'الاسم (أ-ي)', 'en': 'Name (A-Z)'},
    'Apply Filters': {'ar': 'تطبيق التصفية', 'en': 'Apply Filters'},
    'Clear Filters': {'ar': 'مسح التصفية', 'en': 'Clear Filters'},
    
    # Business Details
    'Business Details': {'ar': 'تفاصيل المحل', 'en': 'Business Details'},
    'Contact Information': {'ar': 'معلومات التواصل', 'en': 'Contact Information'},
    'Phone': {'ar': 'الهاتف', 'en': 'Phone'},
    'Email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'Website': {'ar': 'الموقع الإلكتروني', 'en': 'Website'},
    'Address': {'ar': 'العنوان', 'en': 'Address'},
    'Opening Hours': {'ar': 'أوقات العمل', 'en': 'Opening Hours'},
    'About': {'ar': 'عن المحل', 'en': 'About'},
    'Description': {'ar': 'الوصف', 'en': 'Description'},
    'Location': {'ar': 'الموقع', 'en': 'Location'},
    'Map': {'ar': 'الخريطة', 'en': 'Map'},
    'Share': {'ar': 'مشاركة', 'en': 'Share'},
    'Add to Favorites': {'ar': 'إضافة للمفضلة', 'en': 'Add to Favorites'},
    'Remove from Favorites': {'ar': 'إزالة من المفضلة', 'en': 'Remove from Favorites'},
    'Call Now': {'ar': 'اتصل الآن', 'en': 'Call Now'},
    'Visit Website': {'ar': 'زيارة الموقع', 'en': 'Visit Website'},
    'Get Directions': {'ar': 'احصل على الاتجاهات', 'en': 'Get Directions'},
    'Related Businesses': {'ar': 'محلات مشابهة', 'en': 'Related Businesses'},
    'Similar in Category': {'ar': 'مشابه في التصنيف', 'en': 'Similar in Category'},
    
    # Deals
    'Ends': {'ar': 'ينتهي', 'en': 'Ends'},
    'Valid Until': {'ar': 'صالح حتى', 'en': 'Valid Until'},
    'Views': {'ar': 'المشاهدات', 'en': 'Views'},
    'Claims': {'ar': 'الطلبات', 'en': 'Claims'},
    'Per User': {'ar': 'لكل مستخدم', 'en': 'Per User'},
    'Claim This Deal': {'ar': 'احصل على العرض', 'en': 'Claim This Deal'},
    'Already Claimed': {'ar': 'تم الحصول عليه', 'en': 'Already Claimed'},
    'Login to Claim': {'ar': 'سجل دخول للحصول على العرض', 'en': 'Login to Claim'},
    'Deal Description': {'ar': 'وصف العرض', 'en': 'Deal Description'},
    'Terms & Conditions': {'ar': 'الشروط والأحكام', 'en': 'Terms & Conditions'},
    'More from this business': {'ar': 'المزيد من هذا المحل', 'en': 'More from this business'},
    'About Business': {'ar': 'عن المحل', 'en': 'About Business'},
    'View Business': {'ar': 'عرض المحل', 'en': 'View Business'},
    
    # Stats
    'Statistics': {'ar': 'الإحصائيات', 'en': 'Statistics'},
    'Total Businesses': {'ar': 'إجمالي المحلات', 'en': 'Total Businesses'},
    'Total Categories': {'ar': 'إجمالي التصنيفات', 'en': 'Total Categories'},
    'Total Deals': {'ar': 'إجمالي العروض', 'en': 'Total Deals'},
    'Verified Businesses': {'ar': 'محلات موثقة', 'en': 'Verified Businesses'},
    
    # Days
    'Sunday': {'ar': 'الأحد', 'en': 'Sunday'},
    'Monday': {'ar': 'الإثنين', 'en': 'Monday'},
    'Tuesday': {'ar': 'الثلاثاء', 'en': 'Tuesday'},
    'Wednesday': {'ar': 'الأربعاء', 'en': 'Wednesday'},
    'Thursday': {'ar': 'الخميس', 'en': 'Thursday'},
    'Friday': {'ar': 'الجمعة', 'en': 'Friday'},
    'Saturday': {'ar': 'السبت', 'en': 'Saturday'},
    
    # Actions
    'Edit': {'ar': 'تعديل', 'en': 'Edit'},
    'Delete': {'ar': 'حذف', 'en': 'Delete'},
    'Save': {'ar': 'حفظ', 'en': 'Save'},
    'Cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'Submit': {'ar': 'إرسال', 'en': 'Submit'},
    'Back': {'ar': 'رجوع', 'en': 'Back'},
    'Next': {'ar': 'التالي', 'en': 'Next'},
    'Previous': {'ar': 'السابق', 'en': 'Previous'},
    'Close': {'ar': 'إغلاق', 'en': 'Close'},
    'Confirm': {'ar': 'تأكيد', 'en': 'Confirm'},

    
    # إضافات جديدة للصفحات
    'Hot Deals': {'ar': 'عروض ساخنة', 'en': 'Hot Deals'},
    "Don't miss these amazing offers and discounts": {'ar': 'لا تفوت هذه العروض والخصومات المذهلة', 'en': "Don't miss these amazing offers and discounts"},
    'Ending Soon': {'ar': 'ينتهي قريباً', 'en': 'Ending Soon'},
    'Active Deals': {'ar': 'العروض النشطة', 'en': 'Active Deals'},
    'All Types': {'ar': 'جميع الأنواع', 'en': 'All Types'},
    'Reset': {'ar': 'إعادة تعيين', 'en': 'Reset'},
    'All Businesses': {'ar': 'جميع المحلات', 'en': 'All Businesses'},
    'View Details': {'ar': 'عرض التفاصيل', 'en': 'View Details'},
    'Category': {'ar': 'التصنيف', 'en': 'Category'},
    'All Categories': {'ar': 'جميع التصنيفات', 'en': 'All Categories'},
    'Governorate': {'ar': 'المحافظة', 'en': 'Governorate'},
    'All Governorates': {'ar': 'جميع المحافظات', 'en': 'All Governorates'},
    'Sort By': {'ar': 'ترتيب حسب', 'en': 'Sort By'},
    'Newest First': {'ar': 'الأحدث أولاً', 'en': 'Newest First'},
    'Oldest First': {'ar': 'الأقدم أولاً', 'en': 'Oldest First'},
    'Most Popular': {'ar': 'الأكثر شعبية', 'en': 'Most Popular'},
    'Apply Filters': {'ar': 'تطبيق الفلاتر', 'en': 'Apply Filters'},
    'Clear Filters': {'ar': 'مسح الفلاتر', 'en': 'Clear Filters'},
    'businesses': {'ar': 'محل', 'en': 'businesses'},
    'Search': {'ar': 'بحث', 'en': 'Search'},
    'Search...': {'ar': 'ابحث...', 'en': 'Search...'},
    'None': {'ar': 'لا شيء', 'en': 'None'},
    'Try different keywords or check your spelling': {'ar': 'جرب كلمات مختلفة أو تحقق من الإملاء', 'en': 'Try different keywords or check your spelling'},
    'Enter a search term to get started': {'ar': 'أدخل كلمة للبحث للبدء', 'en': 'Enter a search term to get started'},
    'Enter a search term': {'ar': 'أدخل كلمة البحث', 'en': 'Enter a search term'},

    
    # Categories
    'Browse businesses by category': {'ar': 'تصفح المحلات حسب التصنيف', 'en': 'Browse businesses by category'},
    'categories': {'ar': 'تصنيف', 'en': 'categories'},
    'No categories found': {'ar': 'لا توجد تصنيفات', 'en': 'No categories found'},
    'Categories will appear here': {'ar': 'التصنيفات ستظهر هنا', 'en': 'Categories will appear here'},

}


def translate(text, language='ar'):
    """
    ترجمة نص حسب اللغة
    """
    if text in TRANSLATIONS:
        return TRANSLATIONS[text].get(language, text)
    return text