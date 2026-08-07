"""
يملأ إحداثيات الأنشطة الموجودة من روابط الخرائط المحفوظة.

الروابط كانت تُخزَّن نصًا بلا استخراج، فبقيت `latitude` و`longitude`
فارغتين وبقيت الخريطة فارغة معهما. هذا الترحيل يقرأ ما هو محفوظ بالفعل
— بلا نداء شبكة وبلا مفتاح API.
"""

from django.db import migrations


def fill(apps, schema_editor):
    from apps.directory.map_links import extract_coordinates

    Business = apps.get_model('directory', 'Business')

    pending = Business.objects.filter(
        latitude__isnull=True,
        longitude__isnull=True,
    ).exclude(location_url='').exclude(location_url__isnull=True)

    filled = 0
    for business in pending.iterator():
        found = extract_coordinates(business.location_url)
        if found.ok:
            business.latitude = found.latitude
            business.longitude = found.longitude
            # ‏update لا save: الموديل التاريخي في الترحيل لا يملك
            # ‏save() المخصّص، والكتابة المباشرة أوضح هنا.
            Business.objects.filter(pk=business.pk).update(
                latitude=found.latitude,
                longitude=found.longitude,
            )
            filled += 1

    if filled:
        print(f'\n  ← اتملت إحداثيات {filled} نشاط من روابطهم')


def noop(apps, schema_editor):
    """لا تراجع: الإحداثيات المستخرجة صحيحة ولا سبب لمحوها."""


class Migration(migrations.Migration):

    dependencies = [
        ('directory', '0005_business_source_business_verified_by'),
    ]

    operations = [
        migrations.RunPython(fill, noop),
    ]
