"""Temporary admin tools used while reviewing the demo dataset."""

import logging
from io import StringIO

from django.contrib import admin, messages
from django.contrib.admin.views.decorators import staff_member_required
from django.core.exceptions import PermissionDenied
from django.core.management import call_command
from django.db import transaction
from django.shortcuts import redirect, render
from django.urls import reverse

from apps.categories.models import Category
from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product
from apps.reviews.models import Review

logger = logging.getLogger(__name__)


def _demo_counts():
    """Return a compact summary without depending on private command methods."""
    return {
        "businesses": Business.objects.filter(slug__startswith="demo-").count(),
        "categories": Category.objects.filter(slug__startswith="demo-").count(),
        "products": Product.objects.filter(slug__startswith="demo-").count(),
        "deals": Deal.objects.filter(slug__startswith="demo-deal-").count(),
        "reviews": Review.objects.filter(business__slug__startswith="demo-").count(),
    }


@staff_member_required
def demo_data_admin(request):
    """Create or remove demo records from a protected Django Admin page."""
    if not request.user.is_superuser:
        raise PermissionDenied

    if request.method == "POST":
        action = request.POST.get("action")
        command_options = {}

        if action == "clear":
            if request.POST.get("confirmation") != "DELETE_DEMO_DATA":
                messages.error(request, "اكتب عبارة التأكيد كما هي قبل حذف الداتا.")
                return redirect("admin_demo_data")
            command_options["clear"] = True
        elif action == "reset":
            command_options["reset"] = True
        elif action == "create":
            pass
        elif action in {
            "images_all",
            "images_categories",
            "images_businesses",
            "images_products",
            "images_deals",
        }:
            command_options["images_only"] = action.removeprefix("images_")
        else:
            messages.error(request, "العملية المطلوبة غير معروفة.")
            return redirect("admin_demo_data")

        output = StringIO()
        try:
            # The management command is atomic; a failure rolls back the operation.
            with transaction.atomic():
                call_command("seed_demo_data", stdout=output, **command_options)
        except Exception:
            logger.exception("Demo data admin action failed: %s", action)
            messages.error(
                request,
                "تعذر تنفيذ العملية. لم تُحفظ عملية غير مكتملة؛ راجع سجل Render.",
            )
        else:
            result = output.getvalue().strip()
            messages.success(
                request,
                "تم تنفيذ العملية بنجاح." + (f"\n{result}" if result else ""),
            )
        return redirect("admin_demo_data")

    context = {
        **admin.site.each_context(request),
        "title": "إدارة الداتا التجريبية",
        "counts": _demo_counts(),
        "has_demo_data": Business.objects.filter(slug__startswith="demo-").exists(),
        "image_actions": (
            ("images_categories", "صور وأيقونات الأقسام"),
            ("images_businesses", "صور وشعارات المحلات"),
            ("images_products", "صور المنتجات والخدمات"),
            ("images_deals", "صور العروض"),
            ("images_all", "معالجة جميع الصور"),
        ),
        "admin_index_url": reverse("admin:index"),
    }
    return render(request, "admin/demo_data.html", context)
