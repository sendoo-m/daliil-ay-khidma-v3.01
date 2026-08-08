from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True
    dependencies = []

    operations = [
        migrations.CreateModel(
            name='SiteSettings',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('app_store_url', models.URLField(
                    blank=True,
                    help_text='رابط تحميل التطبيق من متجر Apple — اتركه فارغاً لإخفاء الزر',
                    verbose_name='رابط App Store (iOS)',
                )),
                ('google_play_url', models.URLField(
                    blank=True,
                    help_text='رابط تحميل التطبيق من Google Play — اتركه فارغاً لإخفاء الزر',
                    verbose_name='رابط Google Play (Android)',
                )),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'إعدادات الموقع',
                'verbose_name_plural': 'إعدادات الموقع',
            },
        ),
    ]
