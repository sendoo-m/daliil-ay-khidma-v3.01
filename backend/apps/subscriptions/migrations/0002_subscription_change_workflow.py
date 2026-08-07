from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('subscriptions', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='subscriptionplan',
            name='max_businesses',
            field=models.PositiveIntegerField(
                default=1,
                help_text='Maximum active businesses for the owner. 0 = Unlimited.',
                verbose_name='Max Businesses',
            ),
        ),
        migrations.CreateModel(
            name='SubscriptionChangeRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('change_type', models.CharField(choices=[('upgrade', 'Upgrade / ترقية'), ('downgrade', 'Downgrade / تخفيض'), ('same', 'Plan Change / تغيير')], max_length=12)),
                ('billing_period', models.CharField(choices=[('monthly', 'Monthly / شهري'), ('quarterly', 'Quarterly / ربع سنوي'), ('semi_annual', 'Semi-Annual / نصف سنوي'), ('annual', 'Annual / سنوي')], default='monthly', max_length=20)),
                ('status', models.CharField(choices=[('pending', 'Pending Review / بانتظار المراجعة'), ('approved', 'Approved / تمت الموافقة'), ('rejected', 'Rejected / مرفوض'), ('cancelled', 'Cancelled / ملغي'), ('applied', 'Applied / تم التطبيق')], db_index=True, default='pending', max_length=12)),
                ('keep_business_ids', models.JSONField(blank=True, default=list)),
                ('keep_product_ids', models.JSONField(blank=True, default=list)),
                ('preview', models.JSONField(blank=True, default=dict)),
                ('applied_changes', models.JSONField(blank=True, default=dict)),
                ('requested_amount', models.DecimalField(decimal_places=2, default=0, max_digits=10)),
                ('payment_confirmed', models.BooleanField(default=False)),
                ('payment_method', models.CharField(blank=True, max_length=50)),
                ('transaction_id', models.CharField(blank=True, max_length=100)),
                ('rejection_reason', models.TextField(blank=True)),
                ('admin_notes', models.TextField(blank=True)),
                ('reviewed_at', models.DateTimeField(blank=True, null=True)),
                ('applied_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('current_plan', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='change_requests_from', to='subscriptions.subscriptionplan')),
                ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='subscription_change_requests', to=settings.AUTH_USER_MODEL)),
                ('reviewed_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reviewed_subscription_change_requests', to=settings.AUTH_USER_MODEL)),
                ('subscription', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='change_requests', to='subscriptions.subscription')),
                ('target_plan', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='change_requests_to', to='subscriptions.subscriptionplan')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='subscriptionchangerequest',
            index=models.Index(fields=['owner', 'status', '-created_at'], name='subscriptio_owner_i_30f533_idx'),
        ),
        migrations.AddIndex(
            model_name='subscriptionchangerequest',
            index=models.Index(fields=['status', '-created_at'], name='subscriptio_status_40fa58_idx'),
        ),
        migrations.AddConstraint(
            model_name='subscriptionchangerequest',
            constraint=models.UniqueConstraint(condition=models.Q(('status', 'pending')), fields=('subscription',), name='one_pending_subscription_change_per_subscription'),
        ),
    ]
