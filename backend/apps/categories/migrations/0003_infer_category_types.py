"""
يستنتج نوع كل قسم من الأنشطة المسجّلة تحته.

الأقسام موجودة قبل هذا الحقل، فلا يصح أن تبدأ كلها بـ"محل تجاري":
قسم "سباكة" تحته حرفيون، وقسم "مستشفيات" تحته خدمات عامة. البيانات
نفسها تعرف الإجابة — نقرأها منها بدل أن نطلب من أحد تصنيف مئة قسم يدويًا.

القسم الفارغ (بلا أنشطة) يبقى على الافتراضي، ويصحّحه موظف عند أول استعمال.
"""

from collections import Counter

from django.db import migrations


def infer_types(apps, schema_editor):
    Category = apps.get_model('categories', 'Category')
    Business = apps.get_model('directory', 'Business')

    for category in Category.objects.all():
        types = Counter(
            Business.objects.filter(category_id=category.pk)
            .values_list('business_type', flat=True)
        )
        if not types:
            continue

        # الأغلبية تحسم. قسم فيه ١٩ حرفيًا ومحل واحد هو قسم حرف،
        # والمحل الشاذ خطأ تصنيف يصلحه موظف لاحقًا.
        winner, _ = types.most_common(1)[0]
        if winner and winner != category.business_type:
            category.business_type = winner
            category.save(update_fields=['business_type'])


def noop(apps, schema_editor):
    """لا تراجع: الحقل نفسه يُحذف في التراجع عن 0002."""


class Migration(migrations.Migration):

    dependencies = [
        ('categories', '0002_category_business_type'),
        ('directory', '0005_business_source_business_verified_by'),
    ]

    operations = [
        migrations.RunPython(infer_types, noop),
    ]
