from django.apps import AppConfig


class DirectoryConfig(AppConfig):
    """Directory App Configuration"""
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.directory'
    verbose_name = 'Directory Management'
    verbose_name_plural = 'Directory Management'
    
    def ready(self):
        """Import signals when app is ready"""
        try:
            import apps.directory.signals  # noqa
        except ImportError:
            pass
