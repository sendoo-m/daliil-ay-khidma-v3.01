import logging

from django.conf import settings
from django.db import transaction

from .models import DeviceRegistration, Notification


logger = logging.getLogger(__name__)


def send_push_notification(notification):
    """Send through Firebase when configured; keep the inbox functional otherwise."""
    if not settings.PUSH_NOTIFICATIONS_ENABLED:
        return 0
    if not settings.FIREBASE_CREDENTIALS_PATH:
        logger.warning('Push enabled without FIREBASE_CREDENTIALS_PATH')
        return 0

    import firebase_admin
    from firebase_admin import credentials, messaging

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        )

    devices = DeviceRegistration.objects.filter(
        user=notification.user, is_active=True
    ).only('token', 'language')
    sent = 0
    for device in devices:
        use_english = device.language == 'en'
        message = messaging.Message(
            token=device.token,
            notification=messaging.Notification(
                title=notification.title_en if use_english and notification.title_en else notification.title_ar,
                body=notification.body_en if use_english and notification.body_en else notification.body_ar,
            ),
            data={key: str(value) for key, value in notification.data.items()},
        )
        try:
            messaging.send(message)
            sent += 1
        except Exception:
            logger.exception('Failed to send push notification to device %s', device.pk)
    return sent


def create_notification(**kwargs):
    notification = Notification.objects.create(**kwargs)
    transaction.on_commit(lambda: send_push_notification(notification))
    return notification
