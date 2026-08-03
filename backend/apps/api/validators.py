"""Validation helpers shared by mobile API upload serializers."""

from PIL import Image, UnidentifiedImageError
from rest_framework import serializers


ALLOWED_IMAGE_TYPES = {'image/jpeg', 'image/png', 'image/webp'}
MAX_IMAGE_SIZE = 5 * 1024 * 1024


def validate_image_upload(uploaded_file):
    """Allow real JPEG/PNG/WebP images up to 5 MB."""
    if not uploaded_file:
        return uploaded_file

    if uploaded_file.size > MAX_IMAGE_SIZE:
        raise serializers.ValidationError('حجم الصورة يجب ألا يتجاوز 5 ميجابايت')

    content_type = getattr(uploaded_file, 'content_type', '')
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise serializers.ValidationError('الصيغ المسموحة هي JPEG وPNG وWebP فقط')

    try:
        image = Image.open(uploaded_file)
        image.verify()
        if image.format not in {'JPEG', 'PNG', 'WEBP'}:
            raise serializers.ValidationError('ملف الصورة غير صالح')
    except (UnidentifiedImageError, OSError, SyntaxError):
        raise serializers.ValidationError('ملف الصورة تالف أو غير صالح')
    finally:
        uploaded_file.seek(0)

    return uploaded_file
