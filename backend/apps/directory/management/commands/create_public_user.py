from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

class Command(BaseCommand):
    help = 'Creates the public_services system user'

    def handle(self, *args, **kwargs):
        if not User.objects.filter(username='public_services').exists():
            User.objects.create_user(
                username='public_services',
                email='public@system.local',
                password=None,
                first_name='خدمات',
                last_name='عامة',
                phone='00000000000',   # ← رقم placeholder فريد
                is_active=False,
            )
            self.stdout.write(self.style.SUCCESS('✅ تم إنشاء مستخدم public_services'))
        else:
            self.stdout.write(self.style.WARNING('⚠️ المستخدم موجود بالفعل'))
