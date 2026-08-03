"""Production storage customizations."""

import os

import cloudinary.uploader
import requests
from cloudinary_storage.storage import MediaCloudinaryStorage
from django.conf import settings


class BoundedMediaCloudinaryStorage(MediaCloudinaryStorage):
    """Prevent a stalled upload from blocking a web worker indefinitely."""

    @property
    def request_timeout(self):
        return getattr(settings, "CLOUDINARY_UPLOAD_TIMEOUT", 8)

    def _upload(self, name, content):
        options = {
            "use_filename": True,
            "resource_type": self._get_resource_type(name),
            "tags": self.TAG,
            "timeout": self.request_timeout,
        }
        folder = os.path.dirname(name)
        if folder:
            options["folder"] = folder
        return cloudinary.uploader.upload(content, **options)

    def exists(self, name):
        response = requests.head(self._get_url(name), timeout=self.request_timeout)
        if response.status_code == 404:
            return False
        response.raise_for_status()
        return True
