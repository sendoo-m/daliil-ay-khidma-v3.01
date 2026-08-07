"""Merchant onboarding API shared by customer, merchant and web clients."""

from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.directory.models import Business
from apps.subscriptions.models import SubscriptionPlan
from apps.subscriptions.onboarding import build_onboarding_state, get_or_create_onboarding


class MerchantOnboardingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        onboarding = get_or_create_onboarding(request.user)
        return Response(build_onboarding_state(onboarding))


class MerchantOnboardingPlanView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        try:
            plan_id = int(request.data.get('plan_id'))
        except (TypeError, ValueError):
            return Response({'detail': 'plan_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        billing_period = str(request.data.get('billing_period', 'monthly')).strip()
        if billing_period not in dict(SubscriptionPlan.DURATION_CHOICES):
            return Response({'detail': 'Invalid billing period.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            plan = SubscriptionPlan.objects.get(pk=plan_id, is_active=True)
        except SubscriptionPlan.DoesNotExist:
            return Response({'detail': 'Plan not found.'}, status=status.HTTP_404_NOT_FOUND)

        onboarding = get_or_create_onboarding(request.user)
        plan_changed = onboarding.selected_plan_id != plan.id
        period_changed = onboarding.billing_period != billing_period
        onboarding.selected_plan = plan
        onboarding.billing_period = billing_period

        if plan_changed or period_changed:
            onboarding.payment_method = ''
            onboarding.payment_reference = ''
            onboarding.payment_receipt = None

        onboarding.payment_status = 'pending' if plan.get_price(billing_period) > 0 else 'not_required'
        onboarding.status = 'plan_selected' if not onboarding.business_id else 'business_created'
        onboarding.save()
        return Response(build_onboarding_state(onboarding))


class MerchantOnboardingBusinessView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        try:
            business_id = int(request.data.get('business_id'))
        except (TypeError, ValueError):
            return Response({'detail': 'business_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            business = Business.objects.get(pk=business_id, owner=request.user)
        except Business.DoesNotExist:
            return Response({'detail': 'Business not found.'}, status=status.HTTP_404_NOT_FOUND)

        onboarding = get_or_create_onboarding(request.user)
        if not onboarding.selected_plan_id:
            return Response(
                {'detail': 'Select a plan before attaching a business.'},
                status=status.HTTP_409_CONFLICT,
            )

        onboarding.business = business
        onboarding.status = 'business_created'
        onboarding.save(update_fields=['business', 'status', 'updated_at'])
        return Response(build_onboarding_state(onboarding))


class MerchantOnboardingPaymentView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        onboarding = get_or_create_onboarding(request.user)
        if not onboarding.selected_plan_id:
            return Response({'detail': 'Select a plan first.'}, status=status.HTTP_409_CONFLICT)
        if not onboarding.business_id:
            return Response({'detail': 'Create or attach a business first.'}, status=status.HTTP_409_CONFLICT)
        if not onboarding.payment_required:
            return Response(
                {'detail': 'Payment is not required for the selected plan.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        payment_method = str(request.data.get('payment_method', '')).strip()
        if not payment_method:
            return Response({'detail': 'payment_method is required.'}, status=status.HTTP_400_BAD_REQUEST)

        onboarding.payment_method = payment_method
        onboarding.payment_reference = str(request.data.get('payment_reference', '')).strip()
        receipt = request.FILES.get('payment_receipt')
        if receipt is not None:
            onboarding.payment_receipt = receipt
        onboarding.payment_status = 'submitted'
        onboarding.status = 'admin_review'
        onboarding.save()
        return Response(build_onboarding_state(onboarding))
