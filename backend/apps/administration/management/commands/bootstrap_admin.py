"""
إنشاء أول حساب موظف من متغيّرات البيئة.

لماذا أمر منفصل بدل `createsuperuser`؟ لأن الخطة المجانية على Render لا
تمنحك shell، فلا سبيل لتشغيل أمر تفاعلي. هذا الأمر يقرأ كل شيء من البيئة
ويعمل بلا تفاعل، فيمكن وضعه في أمر البناء أو الإقلاع.

    BOOTSTRAP_ADMIN_USERNAME=owner
    BOOTSTRAP_ADMIN_EMAIL=you@example.com
    BOOTSTRAP_ADMIN_PASSWORD=<كلمة مرور قوية>
    BOOTSTRAP_ADMIN_ROLE=super_admin        # اختياري

ثم في Render — Settings ← Build Command:

    pip install -r requirements.txt && python manage.py migrate \\
      && python manage.py seed_roles && python manage.py bootstrap_admin

الأمر idempotent: يتخطّى العمل لو الحساب موجود، فلا مشكلة في بقائه
في أمر البناء بشكل دائم.

مهم: بعد أول نشر ناجح، امسح BOOTSTRAP_ADMIN_PASSWORD من متغيّرات البيئة
وغيّر كلمة المرور من داخل التطبيق. كلمة مرور في لوحة الاستضافة تظل
مقروءة لكل من يملك وصولًا لتلك اللوحة.
"""

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.administration.models import Role, StaffProfile

User = get_user_model()


class Command(BaseCommand):
    help = 'إنشاء أول حساب موظف إدارة من متغيّرات البيئة (بلا تفاعل)'

    def add_arguments(self, parser):
        parser.add_argument('--username', default=None)
        parser.add_argument('--email', default=None)
        parser.add_argument('--role', default=None)
        parser.add_argument(
            '--force-password',
            action='store_true',
            help='تحديث كلمة مرور حساب موجود',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        username = options['username'] or os.environ.get('BOOTSTRAP_ADMIN_USERNAME')
        email = options['email'] or os.environ.get('BOOTSTRAP_ADMIN_EMAIL', '')
        password = os.environ.get('BOOTSTRAP_ADMIN_PASSWORD')
        role_slug = (
            options['role']
            or os.environ.get('BOOTSTRAP_ADMIN_ROLE')
            or 'super_admin'
        )

        if not username:
            self.stdout.write(
                'BOOTSTRAP_ADMIN_USERNAME غير مضبوط — تم التخطي.'
            )
            return

        try:
            role = Role.objects.get(slug=role_slug)
        except Role.DoesNotExist:
            raise CommandError(
                f'الدور "{role_slug}" غير موجود. شغّل `manage.py seed_roles` أولًا.'
            )

        user = User.objects.filter(username=username).first()

        if user is None:
            if not password:
                raise CommandError(
                    'BOOTSTRAP_ADMIN_PASSWORD مطلوب لإنشاء حساب جديد.'
                )
            if len(password) < 10:
                raise CommandError('كلمة المرور يجب أن تكون 10 محارف على الأقل.')

            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
            )
            self.stdout.write(self.style.SUCCESS(f'  + أُنشئ المستخدم {username}'))
        else:
            self.stdout.write(f'  · المستخدم {username} موجود')
            if password and options['force_password']:
                user.set_password(password)
                self.stdout.write(self.style.WARNING('  ~ كلمة المرور حُدّثت'))

        # is_staff مطلوبة لوحة Django نفسها؛ صلاحيات لوحتنا تأتي من الدور.
        changed = []
        if not user.is_staff:
            user.is_staff = True
            changed.append('is_staff')
        if role.is_superuser_role and not user.is_superuser:
            user.is_superuser = True
            changed.append('is_superuser')
        if not user.is_active:
            user.is_active = True
            changed.append('is_active')
        user.save()
        if changed:
            self.stdout.write(f'  ~ حُدّث: {", ".join(changed)}')

        profile, created = StaffProfile.objects.get_or_create(
            user=user,
            defaults={'role': role, 'job_title': role.name_ar},
        )
        if created:
            self.stdout.write(
                self.style.SUCCESS(f'  + ملف موظف بدور "{role.name_ar}"')
            )
        elif profile.role_id != role.id:
            old = profile.role.name_ar
            profile.role = role
            profile.save(update_fields=['role'])
            self.stdout.write(
                self.style.WARNING(f'  ~ الدور: {old} → {role.name_ar}')
            )
        else:
            self.stdout.write(f'  · الدور بالفعل "{role.name_ar}"')

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'جاهز. ادخل لوحة الإدارة باسم "{username}".'
        ))
        if password:
            self.stdout.write(self.style.WARNING(
                'امسح BOOTSTRAP_ADMIN_PASSWORD من متغيّرات البيئة الآن.'
            ))
