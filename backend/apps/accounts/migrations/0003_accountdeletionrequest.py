from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_magiclinktoken'),
    ]

    operations = [
        migrations.CreateModel(
            name='AccountDeletionRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('user_id_snapshot', models.PositiveBigIntegerField()),
                ('email_snapshot', models.EmailField(blank=True, max_length=254)),
                ('username_snapshot', models.CharField(max_length=150)),
                ('reason', models.TextField(blank=True, max_length=1000)),
                ('source', models.CharField(default='mobile', max_length=20)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('completed', 'Completed'), ('cancelled', 'Cancelled')], db_index=True, default='pending', max_length=20)),
                ('requested_at', models.DateTimeField(auto_now_add=True)),
                ('completed_at', models.DateTimeField(blank=True, null=True)),
                ('user', models.OneToOneField(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='account_deletion_request', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-requested_at'],
            },
        ),
    ]
