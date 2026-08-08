from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path, re_path
from django.views.static import serve

from apps.core.admin_views import demo_data_admin
from apps.accounts.magic_link import issue_magic_link, redeem_magic_link

urlpatterns = [
    # Temporary superuser-only tool for Render's free plan (no Shell access).
    path("admin/demo-data/", demo_data_admin, name="admin_demo_data"),
    # Django Admin
    path("admin/", admin.site.urls),
    # Apps
    path("", include("apps.core.urls", namespace="core")),
    path("accounts/", include("apps.accounts.urls", namespace="accounts")),
    path("dashboard/", include("apps.dashboard.urls")),
    path("categories/", include("apps.categories.urls", namespace="categories")),
    path("directory/", include("apps.directory.urls", namespace="directory")),
    path("products/", include("apps.products.urls", namespace="products")),
    path("deals/", include("apps.deals.urls", namespace="deals")),
    path("reviews/", include("apps.reviews.urls", namespace="reviews")),
    path("subscriptions/", include("apps.subscriptions.urls", namespace="subscriptions")),
    # API
    path("api/v1/", include("apps.api.urls", namespace="api")),
    path("api/v2/", include("apps.api.urls_v2", namespace="api_v2")),
    path("api/dashboard/", include("apps.dashboard.api.urls")),

    # ── Magic-Link Web Handoff ──────────────────────────────────────────────
    # Flutter يستدعي POST /api/auth/magic-link/ بـ DRF token
    # فيحصل على URL يفتحه في WebView فيُسجَّل الدخول ويُحوَّل للخطط
    path("api/auth/magic-link/", issue_magic_link, name="api_magic_link_issue"),
    path("auth/magic/",           redeem_magic_link, name="magic_link_redeem"),
    # ───────────────────────────────────────────────────────────────────────
]

# Static & Media
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

# ``django.conf.urls.static.static`` adds media routes only while DEBUG=True.
# Use an explicit, narrowly scoped route so Render can serve uploaded/demo
# images while DEBUG=False. Replace this with object storage for permanent
# production uploads.
urlpatterns += [
    re_path(
        r"^media/(?P<path>.*)$",
        serve,
        {"document_root": settings.MEDIA_ROOT},
    ),
]

# Debug Toolbar
if settings.DEBUG and "debug_toolbar" in settings.INSTALLED_APPS:
    import debug_toolbar

    urlpatterns = [
        path("__debug__/", include(debug_toolbar.urls)),
    ] + urlpatterns
