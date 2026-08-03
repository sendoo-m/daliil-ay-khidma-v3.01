from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema

from apps.api.pagination import StandardResultsSetPagination
from apps.api.permissions import IsAdminUser
from apps.core.models import SiteSettings
from .models import DeviceRegistration, Notification
from .serializers import DeviceRegistrationSerializer, NotificationSerializer
from .services import send_push_notification


User = get_user_model()


def version_tuple(value):
    try:
        return tuple(int(part) for part in value.split('.'))
    except (AttributeError, ValueError):
        return (0,)


class MobileAppConfigView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        config = SiteSettings.get_settings()
        platform = request.query_params.get('platform', 'android')
        if platform not in {'android', 'ios'}:
            return Response(
                {'error': 'platform يجب أن يكون android أو ios'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        current_version = request.query_params.get('version', '0')
        is_ios = platform == 'ios'
        minimum = config.ios_min_version if is_ios else config.android_min_version
        latest = config.ios_latest_version if is_ios else config.android_latest_version
        store_url = config.ios_store_url if is_ios else config.android_store_url

        return Response({
            'site_name_ar': config.site_name_ar,
            'site_name_en': config.site_name_en,
            'logo': request.build_absolute_uri(config.logo.url) if config.logo else None,
            'contact_email': config.contact_email,
            'contact_phone': config.contact_phone,
            'maintenance_mode': config.maintenance_mode,
            'allow_registration': config.allow_registration,
            'allow_reviews': config.allow_reviews,
            'notifications_enabled': config.notifications_enabled,
            'support_url': config.support_url,
            'minimum_version': minimum,
            'latest_version': latest,
            'store_url': store_url,
            'update_available': version_tuple(current_version) < version_tuple(latest),
            'update_required': config.force_update and bool(
                version_tuple(current_version) < version_tuple(minimum)
            ),
        })


class DeviceRegistrationViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = DeviceRegistrationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return DeviceRegistration.objects.none()
        return DeviceRegistration.objects.filter(user=self.request.user)

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save(update_fields=['is_active', 'updated_at'])


class NotificationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def read(self, request, pk=None):
        notification = self.get_object()
        notification.mark_as_read()
        return Response(self.get_serializer(notification).data)

    @action(detail=False, methods=['post'], url_path='read-all')
    def read_all(self, request):
        updated = self.get_queryset().filter(is_read=False).update(
            is_read=True, read_at=timezone.now()
        )
        return Response({'updated': updated})

    @action(detail=False, methods=['get'], url_path='unread-count')
    def unread_count(self, request):
        return Response({'count': self.get_queryset().filter(is_read=False).count()})


class AdminSendNotificationView(APIView):
    permission_classes = [IsAdminUser]

    @extend_schema(request=OpenApiTypes.OBJECT, responses=OpenApiTypes.OBJECT)
    def post(self, request):
        user_ids = request.data.get('user_ids', [])
        send_to_all = request.data.get('send_to_all', False)
        required = ['title_ar', 'body_ar']
        if not all(request.data.get(field, '').strip() for field in required):
            return Response(
                {'error': 'title_ar وbody_ar مطلوبان'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not send_to_all and not user_ids:
            return Response(
                {'error': 'حدد user_ids أو send_to_all'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(user_ids, list):
            return Response(
                {'error': 'user_ids يجب أن تكون قائمة'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(user_ids) > 500:
            return Response(
                {'error': 'الحد الأقصى 500 مستخدم في الطلب'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        notification_type = request.data.get('notification_type', 'general')
        allowed_types = {choice[0] for choice in Notification.TYPE_CHOICES}
        if notification_type not in allowed_types:
            return Response(
                {'error': 'نوع الإشعار غير صالح'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        data = request.data.get('data', {})
        if not isinstance(data, dict):
            return Response(
                {'error': 'data يجب أن تكون object'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        users = User.objects.filter(is_active=True)
        if not send_to_all:
            users = users.filter(id__in=user_ids)

        notifications = []
        with transaction.atomic():
            for user in users.iterator():
                notifications.append(Notification.objects.create(
                    user=user,
                    notification_type=notification_type,
                    title_ar=request.data['title_ar'].strip(),
                    title_en=request.data.get('title_en', '').strip(),
                    body_ar=request.data['body_ar'].strip(),
                    body_en=request.data.get('body_en', '').strip(),
                    data=data,
                ))
            transaction.on_commit(
                lambda: [send_push_notification(item) for item in notifications]
            )

        return Response({'created': len(notifications)}, status=status.HTTP_201_CREATED)
