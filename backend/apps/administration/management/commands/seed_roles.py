"""
python manage.py seed_roles
python manage.py seed_roles --sync    # يحدّث صلاحيات الأدوار الافتراضية

الأمر idempotent — تشغيله مرارًا آمن. بدون `--sync` لا يلمس
الأدوار الموجودة، حتى لا يمسح تعديلات المدير من التطبيق.
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.administration.constants import DEFAULT_ROLES, all_permissions
from apps.administration.models import Role


class Command(BaseCommand):
    help = 'إنشاء الأدوار الإدارية الافتراضية'

    def add_arguments(self, parser):
        parser.add_argument(
            '--sync',
            action='store_true',
            help='تحديث صلاحيات الأدوار الافتراضية الموجودة مسبقًا',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        sync = options['sync']
        created_count = updated_count = 0

        for slug, spec in DEFAULT_ROLES.items():
            perms = spec['permissions']
            if perms == '__all__':
                perms = all_permissions()

            role, created = Role.objects.get_or_create(
                slug=slug,
                defaults={
                    'name_ar': spec['name_ar'],
                    'name_en': spec.get('name_en', ''),
                    'description': spec.get('description', ''),
                    'permissions': sorted(perms),
                    'is_protected': spec.get('is_protected', False),
                },
            )

            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f'  + {role.name_ar} ({slug})'))
            elif sync:
                role.permissions = sorted(perms)
                role.description = spec.get('description', role.description)
                role.save()
                updated_count += 1
                self.stdout.write(self.style.WARNING(f'  ~ {role.name_ar} ({slug})'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'تم: {created_count} دور جديد، {updated_count} محدّث، '
            f'{len(all_permissions())} صلاحية مسجّلة.'
        ))

        if not sync and not created_count:
            self.stdout.write(
                'كل الأدوار موجودة. استخدم --sync لتحديث صلاحياتها.'
            )
