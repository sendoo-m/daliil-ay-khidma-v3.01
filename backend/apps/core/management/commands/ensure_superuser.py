"""Create or update the production superuser from environment variables."""

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Ensure a superuser exists using ADMIN_* environment variables."

    def handle(self, *args, **options):
        values = {
            "username": os.environ.get("ADMIN_USERNAME", "").strip(),
            "email": os.environ.get("ADMIN_EMAIL", "").strip(),
            "phone": os.environ.get("ADMIN_PHONE", "").strip(),
            "password": os.environ.get("ADMIN_PASSWORD", ""),
        }
        missing = [name.upper() for name, value in values.items() if not value]
        if missing:
            raise CommandError(
                "Missing required environment variables: "
                + ", ".join(f"ADMIN_{name}" for name in missing)
            )

        User = get_user_model()
        username = values["username"]

        email_conflict = User.objects.filter(email=values["email"]).exclude(
            username=username
        )
        phone_conflict = User.objects.filter(phone=values["phone"]).exclude(
            username=username
        )
        if email_conflict.exists():
            raise CommandError("ADMIN_EMAIL is already used by another account.")
        if phone_conflict.exists():
            raise CommandError("ADMIN_PHONE is already used by another account.")

        user, created = User.objects.get_or_create(
            username=username,
            defaults={
                "email": values["email"],
                "phone": values["phone"],
                "is_staff": True,
                "is_superuser": True,
                "is_active": True,
            },
        )

        # Keep the account usable if it already existed with ordinary permissions.
        user.email = values["email"]
        user.phone = values["phone"]
        user.is_staff = True
        user.is_superuser = True
        user.is_active = True
        user.set_password(values["password"])
        user.save()

        action = "created" if created else "updated"
        self.stdout.write(
            self.style.SUCCESS(f"Superuser '{username}' {action} successfully.")
        )
