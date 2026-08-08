from .models import SiteSettings


def site_settings(request):
    """
    Inject SiteSettings into every template context.
    Usage in templates:  {{ site_settings.app_store_url }}
    """
    return {'site_settings': SiteSettings.get()}
