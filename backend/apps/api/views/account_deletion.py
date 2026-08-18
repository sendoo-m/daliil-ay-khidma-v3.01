from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import AccountDeletionRequest
from apps.directory.models import Business
from apps.notifications.models import DeviceRegistration


class AccountDeletionRequestView(APIView):
    """Initiate an account deletion request after explicit re-authentication."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        user = request.user
        password = request.data.get('password', '')
        confirmation = request.data.get('confirmation', '')
        reason = request.data.get('reason', '').strip()[:1000]
        source = request.data.get('source', 'mobile').strip()[:20] or 'mobile'

        if user.is_staff or user.is_superuser:
            return Response(
                {'error': 'لا يمكن حذف حسابات الإدارة من تطبيق الهاتف.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if confirmation != 'DELETE':
            return Response(
                {'error': 'تأكيد الحذف غير صحيح.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not password or not user.check_password(password):
            return Response(
                {'error': 'كلمة المرور غير صحيحة.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        deletion_request, created = AccountDeletionRequest.objects.get_or_create(
            user=user,
            defaults={
                'user_id_snapshot': user.pk,
                'email_snapshot': user.email or '',
                'username_snapshot': user.username,
                'reason': reason,
                'source': source,
            },
        )
        if not created and deletion_request.status == AccountDeletionRequest.Status.PENDING:
            return Response(
                {
                    'status': 'pending',
                    'message': 'طلب حذف الحساب مسجل بالفعل.',
                },
                status=status.HTTP_200_OK,
            )

        if not created:
            deletion_request.status = AccountDeletionRequest.Status.PENDING
            deletion_request.reason = reason
            deletion_request.source = source
            deletion_request.completed_at = None
            deletion_request.save(update_fields=['status', 'reason', 'source', 'completed_at'])

        # Hide owned businesses immediately while preserving data until the
        # deletion request is processed, avoiding Business.owner CASCADE loss.
        Business.objects.filter(owner=user).update(is_active=False)
        DeviceRegistration.objects.filter(user=user).update(is_active=False)

        refresh_token = request.data.get('refresh', '').strip()
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except TokenError:
                pass

        user.is_active = False
        user.save(update_fields=['is_active'])

        return Response(
            {
                'status': 'pending',
                'message': 'تم استلام طلب حذف الحساب وتعطيل الحساب فورًا.',
                'request_id': deletion_request.pk,
            },
            status=status.HTTP_202_ACCEPTED,
        )
