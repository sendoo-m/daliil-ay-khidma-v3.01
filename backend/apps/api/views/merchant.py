"""
Merchant API — Views
====================
نقاط تطبيق الأنشطة. كل ما يستطيع صاحب المحل عمله موجود هنا، وما ليس
هنا لا يستطيعه — لأنه غير مكتوب لا لأنه محجوب.

لاحظ ما لا يوجد في هذا الملف: توثيق، تمييز، تعليق أنشطة، إدارة
مستخدمين، إدارة موظفين، سجل عمليات، تصنيفات. تلك تعيش في
`/api/v2/admin/` ولا يوجد جسر بينهما.
"""

from datetime import timedelta

from django.db.models import Avg, Count, Q, Sum
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.api.merchant_base import (
    IsBusinessOwner,
    MerchantViewSet,
    OwnedQuerysetMixin,
)
from apps.api.pagination import StandardResultsSetPagination
from apps.api.serializers.merchant import (
    MerchantBusinessSerializer,
    MerchantDealSerializer,
    MerchantProductSerializer,
    MerchantReplySerializer,
    MerchantReviewSerializer,
)
from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product
from apps.reviews.models import Review, ReviewReply


class MerchantSessionView(APIView):
    """
    GET /api/v2/merchant/session/

    أول نداء بعد الدخول. يعيد أنشطة التاجر فيبني التطبيق واجهته منها:
    تاجر بنشاط واحد يفتح على نشاطه مباشرة، وصاحب عدة أنشطة يرى مبدّلًا.
    """

    permission_classes = [IsBusinessOwner]

    def get(self, request):
        businesses = Business.objects.filter(owner=request.user).select_related(
            'category', 'district__city__governorate'
        )
        return Response({
            'user': {
                'id': request.user.id,
                'username': request.user.username,
                'full_name': request.user.get_full_name() or request.user.username,
                'phone': getattr(request.user, 'phone', ''),
            },
            'businesses': MerchantBusinessSerializer(
                businesses, many=True, context={'request': request}
            ).data,
            'businesses_count': businesses.count(),
        })


class MerchantBusinessViewSet(OwnedQuerysetMixin, viewsets.ModelViewSet):
    """
    أنشطة التاجر. لا `create` ولا `destroy`.

    إنشاء نشاط يمر على مراجعة، وحذفه يمس تقييمات عملاء حقيقيين —
    القرارَان إداريان. `http_method_names` تحجبهما على مستوى الـHTTP
    فلا يوجد مسار إليهما أصلًا.
    """

    queryset = Business.objects.select_related(
        'category', 'district__city__governorate'
    ).order_by('name_ar')
    serializer_class = MerchantBusinessSerializer
    permission_classes = [IsBusinessOwner]
    ownership_lookup = 'owner'
    http_method_names = ['get', 'patch', 'head', 'options']

    audited_fields = [
        'name_ar', 'name_en', 'phone', 'whatsapp', 'email', 'website',
        'facebook', 'instagram', 'address_ar', 'description_ar',
        'working_hours_ar', 'is_active',
    ]

    def perform_update(self, serializer):
        from apps.administration import services
        from apps.administration.models import AuditLog

        before = services.snapshot(serializer.instance, self.audited_fields)
        instance = serializer.save()
        changes = services.diff(
            before, services.snapshot(instance, self.audited_fields)
        )
        if changes:
            services.record(
                actor=self.request.user,
                action=AuditLog.Action.UPDATE,
                target=instance,
                changes=changes,
                request=self.request,
            )

    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """أرقام هذا النشاط وحده."""
        business = self.get_object()
        month_ago = timezone.now() - timedelta(days=30)

        reviews = Review.objects.filter(business=business, is_approved=True)
        return Response({
            'views': business.view_count,
            'clicks': business.click_count,
            'products': Product.objects.filter(business=business).count(),
            'deals_active': Deal.objects.filter(
                business=business,
                is_active=True,
                start_date__lte=timezone.now(),
                end_date__gte=timezone.now(),
            ).count(),
            'reviews_total': reviews.count(),
            'reviews_last_30_days': reviews.filter(
                created_at__gte=month_ago
            ).count(),
            'average_rating': round(
                reviews.aggregate(avg=Avg('rating'))['avg'] or 0, 2
            ),
            'reviews_awaiting_reply': reviews.filter(reply__isnull=True).count(),
        })


class MerchantScopedWriteMixin:
    """
    يتحقق أن `business` المرسل من أنشطة المستخدم.

    ضروري لأن `business` حقل قابل للكتابة — بدون هذا التحقق يستطيع
    التاجر إرسال معرّف محل غيره وإضافة منتج أو عرض إليه.
    """

    def _reject_foreign_business(self, serializer):
        business = serializer.validated_data.get('business')
        if business is None:
            return None
        if not self.owned_businesses().filter(pk=business.pk).exists():
            return Response(
                {'business': 'هذا النشاط ليس من أنشطتك.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return None

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if (rejected := self._reject_foreign_business(serializer)) is not None:
            return rejected
        self.perform_create(serializer)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(
            instance, data=request.data, partial=kwargs.pop('partial', False)
        )
        serializer.is_valid(raise_exception=True)
        if (rejected := self._reject_foreign_business(serializer)) is not None:
            return rejected
        self.perform_update(serializer)
        return Response(serializer.data)


class MerchantProductViewSet(MerchantScopedWriteMixin, MerchantViewSet):
    queryset = Product.objects.select_related('business').order_by('-created_at')
    serializer_class = MerchantProductSerializer
    pagination_class = StandardResultsSetPagination
    ownership_lookup = 'business__owner'

    filterset_fields = ['business', 'is_available', 'product_type']
    search_fields = ['name_ar', 'name_en']
    ordering_fields = ['created_at', 'price', 'name_ar']

    audited_fields = [
        'name_ar', 'price', 'old_price', 'is_available', 'stock_quantity',
    ]


class MerchantDealViewSet(MerchantScopedWriteMixin, MerchantViewSet):
    queryset = Deal.objects.select_related('business').order_by('-created_at')
    serializer_class = MerchantDealSerializer
    pagination_class = StandardResultsSetPagination
    ownership_lookup = 'business__owner'

    filterset_fields = ['business', 'is_active', 'deal_type']
    search_fields = ['title_ar', 'title_en']
    ordering_fields = ['created_at', 'start_date', 'end_date']

    audited_fields = [
        'title_ar', 'start_date', 'end_date', 'is_active', 'deal_type',
    ]


class MerchantReviewViewSet(OwnedQuerysetMixin, viewsets.ReadOnlyModelViewSet):
    """
    تقييمات أنشطة التاجر. قراءة فقط + إضافة رد.

    المعتمَدة وحدها تظهر — التقييم قبل المراجعة ليس شأن التاجر، ورؤيته
    مبكرًا تفتح باب الضغط على العميل قبل النشر.
    """

    queryset = (
        Review.objects
        .filter(is_approved=True)
        .select_related('user', 'business', 'reply')
        .order_by('-created_at')
    )
    serializer_class = MerchantReviewSerializer
    permission_classes = [IsBusinessOwner]
    pagination_class = StandardResultsSetPagination
    ownership_lookup = 'business__owner'

    filterset_fields = ['business', 'rating']
    ordering_fields = ['created_at', 'rating']

    @action(detail=True, methods=['post', 'patch'])
    def reply(self, request, pk=None):
        """
        POST /merchant/reviews/{id}/reply/   {"comment": "..."}

        `get_object()` يمر على الـqueryset المقصور على الملكية، فالرد
        على تقييم محل غيرك يرجّع 404 — لا يصل إلى هنا.
        """
        review = self.get_object()
        existing = getattr(review, 'reply', None)

        serializer = MerchantReplySerializer(
            existing, data=request.data, partial=existing is not None
        )
        serializer.is_valid(raise_exception=True)

        if existing is None:
            reply = ReviewReply.objects.create(
                review=review,
                user=request.user,
                comment=serializer.validated_data['comment'],
            )
            created = True
        else:
            reply = serializer.save()
            created = False

        from apps.administration import services
        from apps.administration.models import AuditLog

        services.record(
            actor=request.user,
            action=AuditLog.Action.CREATE if created else AuditLog.Action.UPDATE,
            target=reply,
            target_label=f'رد على تقييم #{review.pk}',
            changes={'comment': {'to': reply.comment[:200]}},
            request=request,
        )

        return Response(
            MerchantReplySerializer(reply).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class MerchantDashboardView(APIView):
    """
    GET /api/v2/merchant/dashboard/

    ملخّص عبر كل أنشطة التاجر. يبدأ بما ينتظر تدخّله — تقييمات بلا رد
    وعروض على وشك الانتهاء — لا بالأرقام الإجمالية.
    """

    permission_classes = [IsBusinessOwner]

    def get(self, request):
        businesses = Business.objects.filter(owner=request.user)
        now = timezone.now()

        totals = businesses.aggregate(
            count=Count('id'),
            verified=Count('id', filter=Q(is_verified=True)),
            views=Sum('view_count'),
            clicks=Sum('click_count'),
        )

        reviews = Review.objects.filter(
            business__in=businesses, is_approved=True
        )

        return Response({
            'needs_attention': {
                'reviews_without_reply': reviews.filter(
                    reply__isnull=True
                ).count(),
                'deals_expiring_soon': Deal.objects.filter(
                    business__in=businesses,
                    is_active=True,
                    end_date__gte=now,
                    end_date__lte=now + timedelta(days=3),
                ).count(),
                'businesses_awaiting_verification': businesses.filter(
                    is_verified=False, is_active=True
                ).count(),
            },
            'totals': {
                'businesses': totals['count'],
                'verified': totals['verified'],
                'views': totals['views'] or 0,
                'clicks': totals['clicks'] or 0,
                'products': Product.objects.filter(
                    business__in=businesses
                ).count(),
                'reviews': reviews.count(),
                'average_rating': round(
                    reviews.aggregate(avg=Avg('rating'))['avg'] or 0, 2
                ),
            },
            'generated_at': now,
        })
