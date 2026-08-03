from django.utils import timezone
from rest_framework import serializers

from .models import DeviceRegistration, Notification


class DeviceRegistrationSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceRegistration
        fields = [
            'id', 'token', 'platform', 'device_id', 'app_version',
            'language', 'is_active', 'last_seen_at', 'created_at',
        ]
        read_only_fields = ['id', 'is_active', 'last_seen_at', 'created_at']

    def validate_language(self, value):
        if value not in {'ar', 'en'}:
            raise serializers.ValidationError('اللغة يجب أن تكون ar أو en')
        return value

    def create(self, validated_data):
        user = self.context['request'].user
        token = validated_data.pop('token')
        device, _ = DeviceRegistration.objects.update_or_create(
            token=token,
            defaults={
                **validated_data,
                'user': user,
                'is_active': True,
                'last_seen_at': timezone.now(),
            },
        )
        return device


class NotificationSerializer(serializers.ModelSerializer):
    title = serializers.SerializerMethodField()
    body = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = [
            'id', 'notification_type', 'title', 'body', 'data',
            'is_read', 'read_at', 'created_at',
        ]

    def _language(self):
        request = self.context.get('request')
        if request:
            return request.query_params.get(
                'language', request.headers.get('Accept-Language', 'ar')
            )[:2]
        return 'ar'

    def get_title(self, obj) -> str:
        return obj.title_en if self._language() == 'en' and obj.title_en else obj.title_ar

    def get_body(self, obj) -> str:
        return obj.body_en if self._language() == 'en' and obj.body_en else obj.body_ar
