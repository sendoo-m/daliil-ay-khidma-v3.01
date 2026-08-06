"""
Admin API Views — إعادة كتابة على أساس apps.administration
===========================================================
ما تغيّر عن النسخة السابقة:

  · صلاحية منفصلة لكل عملية بدل `is_staff` للكل.
  · تقييد جغرافي تلقائي — مراجع أسيوط لا يرى محلات الإسكندرية.
  · تسجيل تلقائي لكل تعديل في AuditLog مع الفروق.
  · إصلاح `ordering_fields` — كانت `views_count` والحقل اسمه `view_count`
    فكان أي فرز بالمشاهدات يرمي FieldError (خطأ 500).
  · `analytics` كان 48 استعلامًا (12 شهر × 4 موديلات) → صار 4 استعلامات.
  · `stats` كان 18 استعلامًا بلا كاش → صار مجمّعًا ومخزّنًا 60 ثانية.
  · إزالة N+1 في عدّادات المستخدمين والتصنيفات عبر annotate.
  · عمليات جماعية.
"""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db.models import Avg, Count, Q, Sum
from django.db.models.functions import TruncMonth
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.administration.constants import Perm
from apps.administration.models import AuditLog
from apps.administration.permissions import (
    HasActionPermission,
    IsAdminPanelUser,
    get_staff_profile,
)
from apps.administration.viewsets import AdminModelViewSet
from apps.api.pagination import StandardResultsSetPagination
from apps.api.serializers.admin import (
    AdminBusinessListSerializer,
    AdminBusinessSerializer,
    AdminCategorySerializer,
    AdminDealSerializer,
    AdminProductSerializer,
    AdminReviewSerializer,
    AdminUserSerializer,
    DashboardStatsSerializer,
    MonthlyPointSerializer,
)
from apps.deals.models import Deal
from apps.directory.models import Business, Category
from apps.products.models import Product
from apps.reviews.models import Review

User = get_user_model()

MONTHS_AR = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
]


# ═══════════════════════════════════════════════════════
#  لوحة المعلومات
# ═══════════════════════════════════════════════════════

class AdminDashboardViewSet(viewsets.ViewSet):
    permission_classes = [IsAdminPanelUser, HasActionPermission]
    required_permissions = {
        'stats': Perm.ANALYTICS_VIEW,
        'analytics': Perm.ANALYTICS_VIEW,
        'pending_queue': [Perm.BUSINESS_VERIFY, Perm.REVIEW_MODERATE],
    }

    CACHE_TTL = 60  # ثانية

    def _scope_filter(self) -> Q:
        """قيد المحافظات كـQ object قابل لإعادة الاستخدام."""
        user = self.request.user
        if user.is_superuser:
            return Q()
        profile = get_staff_profile(user)
        allowed = profile.scope_governorate_ids() if profile else []
        if allowed is None:
            return Q()
        return Q(district__city__governorate__in=allowed)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        scope = self._scope_filter()
        cache_key = f'admin:stats:{request.user.id}'

        cached = cache.get(cache_key)
        if cached is not None:
            return Response(cached)

        week_ago = timezone.now() - timedelta(days=7)
        now = timezone.now()

        # الأنشطة داخل نطاق الموظف — أساس كل ما بعده.
        businesses_qs = Business.objects.filter(scope)

        def scoped(model_qs):
            """قصر أي queryset مرتبط بنشاط على نطاق الموظف."""
            return model_qs.filter(business__in=businesses_qs) if scope else model_qs

        # استعلام واحد مجمّع لكل موديل بدل عدّاد منفصل لكل رقم.
        user_agg = User.objects.aggregate(
            total=Count('id'),
            active=Count('id', filter=Q(is_active=True)),
            new_week=Count('id', filter=Q(date_joined__gte=week_ago)),
            owners=Count('id', filter=Q(is_business_owner=True)),
        )

        business_agg = businesses_qs.aggregate(
            total=Count('id'),
            verified=Count('id', filter=Q(is_verified=True)),
            pending=Count('id', filter=Q(is_verified=False, is_active=True)),
            featured=Count('id', filter=Q(is_featured=True)),
            views=Sum('view_count'),
            clicks=Sum('click_count'),
        )

        deal_agg = scoped(Deal.objects.all()).aggregate(
            total=Count('id'),
            active=Count(
                'id',
                filter=Q(is_active=True, start_date__lte=now, end_date__gte=now),
            ),
        )

        content_agg = {
            'products': scoped(Product.objects.all()).count(),
            'deals_total': deal_agg['total'],
            'deals_active': deal_agg['active'],
        }

        review_agg = scoped(Review.objects.all()).aggregate(
            total=Count('id'),
            pending=Count('id', filter=Q(is_approved=False)),
            avg_rating=Avg('rating', filter=Q(is_approved=True)),
        )

        payload = {
            'users': {
                'total': user_agg['total'],
                'active': user_agg['active'],
                'new_this_week': user_agg['new_week'],
                'business_owners': user_agg['owners'],
            },
            'businesses': {
                'total': business_agg['total'],
                'verified': business_agg['verified'],
                'pending_verification': business_agg['pending'],
                'featured': business_agg['featured'],
            },
            'content': {
                'products': content_agg['products'],
                'deals_total': content_agg['deals_total'],
                'deals_active': content_agg['deals_active'],
                'reviews_total': review_agg['total'],
                'reviews_pending': review_agg['pending'],
            },
            'engagement': {
                'total_views': business_agg['views'] or 0,
                'total_clicks': business_agg['clicks'] or 0,
                'average_rating': round(review_agg['avg_rating'] or 0, 2),
            },
            'generated_at': timezone.now(),
        }

        data = DashboardStatsSerializer(payload).data
        cache.set(cache_key, data, self.CACHE_TTL)
        return Response(data)

    @action(detail=False, methods=['get'])
    def analytics(self, request):
        """
        نمو شهري للسنة المطلوبة.

        النسخة السابقة كانت تنفّذ 12 استعلامًا لكل موديل = 48 استعلامًا.
        هذه تنفّذ استعلامًا واحدًا لكل موديل عبر TruncMonth + annotate.
        """
        try:
            year = int(request.query_params.get('year', timezone.now().year))
        except (TypeError, ValueError):
            return Response(
                {'detail': 'قيمة year غير صالحة.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        scope = self._scope_filter()

        def monthly(queryset, date_field: str) -> dict[int, int]:
            rows = (
                queryset
                .filter(**{f'{date_field}__year': year})
                .annotate(m=TruncMonth(date_field))
                .values('m')
                .annotate(n=Count('id'))
            )
            return {row['m'].month: row['n'] for row in rows if row['m']}

        businesses_qs = Business.objects.filter(scope)

        users_by_month = monthly(User.objects.all(), 'date_joined')
        biz_by_month = monthly(businesses_qs, 'created_at')
        products_by_month = monthly(
            Product.objects.filter(business__in=businesses_qs) if scope
            else Product.objects.all(),
            'created_at',
        )
        reviews_by_month = monthly(
            Review.objects.filter(business__in=businesses_qs) if scope
            else Review.objects.all(),
            'created_at',
        )

        data = [
            {
                'month': m,
                'label': MONTHS_AR[m - 1],
                'users': users_by_month.get(m, 0),
                'businesses': biz_by_month.get(m, 0),
                'products': products_by_month.get(m, 0),
                'reviews': reviews_by_month.get(m, 0),
            }
            for m in range(1, 13)
        ]
        return Response(MonthlyPointSerializer(data, many=True).data)

    @action(detail=False, methods=['get'], url_path='pending-queue')
    def pending_queue(self, request):
        """ما ينتظر تدخّل الموظف — الشاشة الأولى في تطبيق الإدارة."""
        scope = self._scope_filter()
        businesses = Business.objects.filter(scope)

        return Response({
            'businesses_awaiting_verification': businesses.filter(
                is_verified=False, is_active=True
            ).count(),
            'reviews_awaiting_moderation': Review.objects.filter(
                business__in=businesses, is_approved=False
            ).count(),
            'deals_expiring_soon': Deal.objects.filter(
                business__in=businesses,
                is_active=True,
                end_date__lte=timezone.now() + timedelta(days=3),
                end_date__gte=timezone.now(),
            ).count(),
        })


# ═══════════════════════════════════════════════════════
#  الأنشطة
# ═══════════════════════════════════════════════════════

class AdminBusinessViewSet(AdminModelViewSet):
    queryset = Business.objects.select_related(
        'owner', 'category', 'district__city__governorate'
    ).order_by('-created_at')

    pagination_class = StandardResultsSetPagination
    scope_lookup = 'district__city__governorate'

    required_permissions = {
        'list': Perm.BUSINESS_VIEW,
        'retrieve': Perm.BUSINESS_VIEW,
        'create': Perm.BUSINESS_CREATE,
        'update': Perm.BUSINESS_EDIT,
        'partial_update': Perm.BUSINESS_EDIT,
        'destroy': Perm.BUSINESS_DELETE,
        'verify': Perm.BUSINESS_VERIFY,
        'unverify': Perm.BUSINESS_VERIFY,
        'toggle_featured': Perm.BUSINESS_FEATURE,
        'suspend': Perm.BUSINESS_SUSPEND,
        'bulk_update': Perm.BUSINESS_EDIT,
    }

    filterset_fields = [
        'is_active', 'is_verified', 'is_featured', 'business_type', 'category',
    ]
    search_fields = ['name_ar', 'name_en', 'owner__username', 'owner__phone']

    # ✅ الإصلاح: الحقول اسمها view_count / click_count في الموديل.
    ordering_fields = ['created_at', 'view_count', 'click_count', 'name_ar']

    audited_fields = [
        'name_ar', 'name_en', 'owner', 'category', 'district',
        'is_active', 'is_verified', 'is_featured', 'phone', 'address',
    ]
    bulk_updatable_fields = {
        'is_verified': Perm.BUSINESS_VERIFY,
        'is_featured': Perm.BUSINESS_FEATURE,
        'is_active': Perm.BUSINESS_SUSPEND,
    }

    def get_serializer_class(self):
        if self.action == 'list':
            return AdminBusinessListSerializer
        return AdminBusinessSerializer

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        business = self.get_object()
        response = self.audited_toggle(
            business, 'is_verified', True,
            action_on=AuditLog.Action.VERIFY,
            action_off=AuditLog.Action.UNVERIFY,
        )
        # ختم التحقق: الخدمات العامة لا يحدّثها أحد من تلقاء نفسه،
        # فنحتاج معرفة عمر البيانات لا مجرد كونها موثّقة.
        if response.status_code < 400:
            business.verified_at = timezone.now()
            business.verified_by = request.user
            business.save(update_fields=['verified_at', 'verified_by'])
        return response

    @action(detail=True, methods=['post'])
    def unverify(self, request, pk=None):
        return self.audited_toggle(
            self.get_object(), 'is_verified', False,
            action_on=AuditLog.Action.VERIFY,
            action_off=AuditLog.Action.UNVERIFY,
        )

    @action(detail=True, methods=['post'], url_path='toggle-featured')
    def toggle_featured(self, request, pk=None):
        business = self.get_object()
        return self.audited_toggle(
            business, 'is_featured', not business.is_featured,
            action_on=AuditLog.Action.FEATURE,
            action_off=AuditLog.Action.UNFEATURE,
        )

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        """تعليق نشاط. السبب إلزامي — قرار يجب أن يكون مبرَّرًا."""
        if not request.data.get('reason'):
            return Response(
                {'reason': 'سبب التعليق مطلوب.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return self.audited_toggle(
            self.get_object(), 'is_active', False,
            action_on=AuditLog.Action.SUSPEND,
            action_off=AuditLog.Action.ACTIVATE,
        )


# ═══════════════════════════════════════════════════════
#  التقييمات
# ═══════════════════════════════════════════════════════

class AdminReviewViewSet(AdminModelViewSet):
    queryset = (
        Review.objects
        .select_related('user', 'business')
        .annotate(reports_count=Count('reports', distinct=True))
        .order_by('-created_at')
    )
    serializer_class = AdminReviewSerializer
    pagination_class = StandardResultsSetPagination
    scope_lookup = 'business__district__city__governorate'

    required_permissions = {
        'list': Perm.REVIEW_VIEW,
        'retrieve': Perm.REVIEW_VIEW,
        'destroy': Perm.REVIEW_DELETE,
        'approve': Perm.REVIEW_MODERATE,
        'reject': Perm.REVIEW_MODERATE,
        'bulk_update': Perm.REVIEW_MODERATE,
    }

    filterset_fields = ['is_approved', 'rating', 'business']
    search_fields = ['user__username', 'business__name_ar', 'comment']
    ordering_fields = ['created_at', 'rating', 'reports_count']

    bulk_updatable_fields = {'is_approved': Perm.REVIEW_MODERATE}

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        return self.audited_toggle(
            self.get_object(), 'is_approved', True,
            action_on=AuditLog.Action.APPROVE,
            action_off=AuditLog.Action.REJECT,
        )

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        return self.audited_toggle(
            self.get_object(), 'is_approved', False,
            action_on=AuditLog.Action.APPROVE,
            action_off=AuditLog.Action.REJECT,
        )


# ═══════════════════════════════════════════════════════
#  المستخدمون
# ═══════════════════════════════════════════════════════

class AdminUserViewSet(AdminModelViewSet):
    queryset = (
        User.objects
        .select_related('staff_profile__role')
        .annotate(
            # ‏annotate/filter تستعملان related_query_name لا related_name.
            # الحقل معرّف بـ related_name='businesses' لكن
            # related_query_name='business' — والثانية هي المقصودة هنا.
            businesses_count=Count('business', distinct=True),
            reviews_count=Count('reviews', distinct=True),
        )
        .order_by('-date_joined')
    )
    serializer_class = AdminUserSerializer
    pagination_class = StandardResultsSetPagination
    scope_lookup = None  # المستخدمون غير مقيّدين جغرافيًا

    required_permissions = {
        'list': Perm.USER_VIEW,
        'retrieve': Perm.USER_VIEW,
        'update': Perm.USER_EDIT,
        'partial_update': Perm.USER_EDIT,
        'destroy': Perm.USER_DELETE,
        'suspend': Perm.USER_SUSPEND,
        'activate': Perm.USER_SUSPEND,
    }

    filterset_fields = ['is_active', 'is_staff', 'is_business_owner', 'email_verified']
    search_fields = ['username', 'email', 'phone', 'first_name', 'last_name']
    ordering_fields = ['date_joined', 'username', 'last_login']

    audited_fields = [
        'username', 'email', 'phone', 'first_name', 'last_name',
        'is_active', 'is_staff', 'is_business_owner',
    ]

    def _guard_self_or_superuser(self, target) -> Response | None:
        """
        قاعدتا أمان أساسيتان:
          · لا أحد يعطّل حسابه بنفسه (يقفل نفسه خارج اللوحة).
          · لا أحد يمس superuser إلا superuser آخر.
        """
        if target.pk == self.request.user.pk:
            return Response(
                {'detail': 'لا يمكنك تنفيذ هذه العملية على حسابك.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if target.is_superuser and not self.request.user.is_superuser:
            return Response(
                {'detail': 'لا يمكن تعديل حساب مدير عام.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return None

    def perform_destroy(self, instance):
        # الحذف النهائي للمستخدمين ممنوع — التعطيل بديل قابل للتراجع.
        raise PermissionError(
            'حذف المستخدمين معطّل. استخدم التعطيل بدلًا منه.'
        )

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        target = self.get_object()
        if (blocked := self._guard_self_or_superuser(target)) is not None:
            return blocked
        if not request.data.get('reason'):
            return Response(
                {'reason': 'سبب التعطيل مطلوب.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return self.audited_toggle(
            target, 'is_active', False,
            action_on=AuditLog.Action.SUSPEND,
            action_off=AuditLog.Action.ACTIVATE,
        )

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        target = self.get_object()
        if (blocked := self._guard_self_or_superuser(target)) is not None:
            return blocked
        return self.audited_toggle(
            target, 'is_active', True,
            action_on=AuditLog.Action.SUSPEND,
            action_off=AuditLog.Action.ACTIVATE,
        )


# ═══════════════════════════════════════════════════════
#  التصنيفات · المنتجات · العروض
# ═══════════════════════════════════════════════════════

class AdminCategoryViewSet(AdminModelViewSet):
    queryset = (
        Category.objects
        .select_related('parent')
        .annotate(businesses_count=Count('business', distinct=True))
        .order_by('order', 'name_ar')
    )
    serializer_class = AdminCategorySerializer
    pagination_class = StandardResultsSetPagination
    scope_lookup = None

    required_permissions = {
        'list': Perm.BUSINESS_VIEW,
        'retrieve': Perm.BUSINESS_VIEW,
        'create': Perm.CATEGORY_MANAGE,
        'update': Perm.CATEGORY_MANAGE,
        'partial_update': Perm.CATEGORY_MANAGE,
        'destroy': Perm.CATEGORY_MANAGE,
        'reorder': Perm.CATEGORY_MANAGE,
    }

    filterset_fields = ['is_active', 'parent', 'business_type']
    search_fields = ['name_ar', 'name_en']
    ordering_fields = ['order', 'name_ar', 'businesses_count']

    def perform_destroy(self, instance):
        if instance.business_set.exists():
            raise PermissionError(
                'لا يمكن حذف تصنيف مرتبط بأنشطة. عطّله أو انقل الأنشطة أولًا.'
            )
        super().perform_destroy(instance)

    @action(detail=False, methods=['post'])
    def reorder(self, request):
        """POST {"order": [{"id": 3, "order": 0}, ...]} — سحب وإفلات."""
        items = request.data.get('order') or []
        updated = 0
        for item in items:
            updated += Category.objects.filter(id=item.get('id')).update(
                order=item.get('order', 0)
            )
        return Response({'status': 'success', 'updated': updated})


class AdminProductViewSet(AdminModelViewSet):
    queryset = Product.objects.select_related('business').order_by('-created_at')
    serializer_class = AdminProductSerializer
    pagination_class = StandardResultsSetPagination
    scope_lookup = 'business__district__city__governorate'

    required_permissions = {
        'list': Perm.PRODUCT_VIEW,
        'retrieve': Perm.PRODUCT_VIEW,
        'create': Perm.PRODUCT_EDIT,
        'update': Perm.PRODUCT_EDIT,
        'partial_update': Perm.PRODUCT_EDIT,
        'destroy': Perm.PRODUCT_DELETE,
        'bulk_update': Perm.PRODUCT_EDIT,
    }

    filterset_fields = ['is_available', 'is_featured', 'product_type', 'business']
    search_fields = ['name_ar', 'name_en', 'business__name_ar']
    ordering_fields = ['created_at', 'price', 'name_ar']

    bulk_updatable_fields = {
        'is_available': Perm.PRODUCT_EDIT,
        'is_featured': Perm.PRODUCT_EDIT,
    }


class AdminDealViewSet(AdminModelViewSet):
    queryset = Deal.objects.select_related('business').order_by('-created_at')
    serializer_class = AdminDealSerializer
    pagination_class = StandardResultsSetPagination
    scope_lookup = 'business__district__city__governorate'

    required_permissions = {
        'list': Perm.DEAL_VIEW,
        'retrieve': Perm.DEAL_VIEW,
        'create': Perm.DEAL_EDIT,
        'update': Perm.DEAL_EDIT,
        'partial_update': Perm.DEAL_EDIT,
        'destroy': Perm.DEAL_DELETE,
        'bulk_update': Perm.DEAL_EDIT,
    }

    filterset_fields = ['is_active', 'is_featured', 'deal_type', 'business']
    search_fields = ['title_ar', 'title_en', 'business__name_ar']
    ordering_fields = ['created_at', 'start_date', 'end_date', 'used_count']

    bulk_updatable_fields = {'is_active': Perm.DEAL_EDIT}
