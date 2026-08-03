# apps/dashboard/api/views/admin_api.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Count, Sum, Avg, Q
from django.utils import timezone
from datetime import timedelta

from apps.accounts.models import User
from apps.directory.models import Business
from apps.products.models import Product
from apps.deals.models import Deal
from apps.reviews.models import Review
from apps.categories.models import Category

from ..permissions import IsAdminDashboard
from ..serializers.admin_serializers import (
    AdminStatsSerializer,
    AdminUserSerializer,
    AdminBusinessSerializer,
    AdminReviewSerializer,
)


# ══════════════════════════════════════════
# STATS
# ══════════════════════════════════════════
class AdminStatsAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def get(self, request):
        today       = timezone.now()
        last_7_days = today - timedelta(days=7)

        data = {
            'total_users':          User.objects.count(),
            'active_users':         User.objects.filter(is_active=True).count(),
            'new_users_week':       User.objects.filter(date_joined__gte=last_7_days).count(),

            'total_businesses':     Business.objects.count(),
            'verified_businesses':  Business.objects.filter(is_verified=True).count(),
            'pending_verification': Business.objects.filter(is_verified=False, is_active=True).count(),
            'new_businesses_week':  Business.objects.filter(created_at__gte=last_7_days).count(),

            'total_products':       Product.objects.count(),
            'active_products':      Product.objects.filter(is_available=True).count(),

            'total_deals':          Deal.objects.count(),
            'active_deals':         Deal.objects.filter(
                start_date__lte=today, end_date__gte=today, is_active=True
            ).count(),

            'total_reviews':        Review.objects.count(),
            'pending_reviews':      Review.objects.filter(is_approved=False).count(),
            'average_rating':       round(
                Review.objects.filter(is_approved=True).aggregate(
                    Avg('rating'))['rating__avg'] or 0, 2
            ),

            'total_views':          Business.objects.aggregate(
                Sum('view_count'))['view_count__sum'] or 0,
            'total_clicks':         Business.objects.aggregate(
                Sum('click_count'))['click_count__sum'] or 0,
        }

        serializer = AdminStatsSerializer(data)
        return Response(serializer.data)


# ══════════════════════════════════════════
# CHART DATA
# ══════════════════════════════════════════
class AdminChartDataAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def get(self, request):
        today = timezone.now()

        # آخر 6 أشهر
        months_data = []
        for i in range(5, -1, -1):
            month_start = (today.replace(day=1) - timedelta(days=i * 30)).replace(
                day=1, hour=0, minute=0, second=0
            )
            month_end = (month_start + timedelta(days=32)).replace(day=1)

            months_data.append({
                'month':      month_start.strftime('%b'),
                'businesses': Business.objects.filter(
                    created_at__gte=month_start, created_at__lt=month_end
                ).count(),
                'users':      User.objects.filter(
                    date_joined__gte=month_start, date_joined__lt=month_end
                ).count(),
                'reviews':    Review.objects.filter(
                    created_at__gte=month_start, created_at__lt=month_end
                ).count(),
            })

        # توزيع التصنيفات
        categories = Category.objects.annotate(
            count=Count('business')
        ).order_by('-count')[:6].values('name_ar', 'count')

        # أفضل المحلات
        top_businesses = Business.objects.filter(
            is_active=True
        ).order_by('-view_count')[:5].values(
            'name_ar', 'view_count', 'click_count', 'average_rating'
        )

        return Response({
            'monthly_growth':  months_data,
            'categories_dist': list(categories),
            'top_businesses':  list(top_businesses),
        })


# ══════════════════════════════════════════
# USERS
# ══════════════════════════════════════════
class AdminUsersAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def get(self, request):
        users  = User.objects.all().order_by('-date_joined')
        search = request.query_params.get('search', '')
        status_filter = request.query_params.get('status', '')

        if search:
            users = users.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search)
            )
        if status_filter == 'active':
            users = users.filter(is_active=True)
        elif status_filter == 'inactive':
            users = users.filter(is_active=False)
        elif status_filter == 'staff':
            users = users.filter(is_staff=True)

        serializer = AdminUserSerializer(users, many=True)
        return Response({
            'count':   users.count(),
            'results': serializer.data,
        })


class AdminUserToggleAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, user_id):
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'المستخدم غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        if user == request.user:
            return Response(
                {'error': 'لا يمكنك تعطيل حسابك الخاص'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user.is_active = not user.is_active
        user.save()
        return Response({
            'success':   True,
            'is_active': user.is_active,
            'message':   f"تم {'تفعيل' if user.is_active else 'تعطيل'} المستخدم"
        })


# ══════════════════════════════════════════
# BUSINESSES
# ══════════════════════════════════════════
class AdminBusinessesAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def get(self, request):
        businesses = Business.objects.select_related(
            'owner', 'category'
        ).order_by('-created_at')

        search        = request.query_params.get('search', '')
        status_filter = request.query_params.get('status', '')
        btype         = request.query_params.get('type', '')

        if search:
            businesses = businesses.filter(
                Q(name_ar__icontains=search) |
                Q(name_en__icontains=search) |
                Q(owner__username__icontains=search)
            )
        if status_filter == 'verified':
            businesses = businesses.filter(is_verified=True)
        elif status_filter == 'pending':
            businesses = businesses.filter(is_verified=False, is_active=True)
        elif status_filter == 'inactive':
            businesses = businesses.filter(is_active=False)
        elif status_filter == 'featured':
            businesses = businesses.filter(is_featured=True)
        if btype:
            businesses = businesses.filter(business_type=btype)

        serializer = AdminBusinessSerializer(businesses, many=True)
        return Response({
            'count':   businesses.count(),
            'results': serializer.data,
        })


class AdminBusinessVerifyAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, business_id):
        try:
            business = Business.objects.get(id=business_id)
        except Business.DoesNotExist:
            return Response(
                {'error': 'المحل غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        business.is_verified = not business.is_verified
        if business.is_verified:
            business.verified_at = timezone.now()
        business.save()

        return Response({
            'success':     True,
            'is_verified': business.is_verified,
            'message':     f"تم {'توثيق' if business.is_verified else 'إلغاء توثيق'} المحل"
        })


class AdminBusinessFeatureAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, business_id):
        try:
            business = Business.objects.get(id=business_id)
        except Business.DoesNotExist:
            return Response(
                {'error': 'المحل غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        business.is_featured = not business.is_featured
        business.save()

        return Response({
            'success':     True,
            'is_featured': business.is_featured,
            'message':     f"تم {'تمييز' if business.is_featured else 'إلغاء تمييز'} المحل"
        })


class AdminBusinessToggleAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, business_id):
        try:
            business = Business.objects.get(id=business_id)
        except Business.DoesNotExist:
            return Response(
                {'error': 'المحل غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        business.is_active = not business.is_active
        business.save()

        return Response({
            'success':   True,
            'is_active': business.is_active,
            'message':   f"تم {'تفعيل' if business.is_active else 'تعطيل'} المحل"
        })


# ══════════════════════════════════════════
# REVIEWS
# ══════════════════════════════════════════
class AdminReviewsAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def get(self, request):
        reviews = Review.objects.select_related(
            'business', 'user'
        ).order_by('-created_at')

        status_filter = request.query_params.get('status', '')
        if status_filter == 'pending':
            reviews = reviews.filter(is_approved=False)
        elif status_filter == 'approved':
            reviews = reviews.filter(is_approved=True)

        serializer = AdminReviewSerializer(reviews, many=True)
        return Response({
            'count':   reviews.count(),
            'results': serializer.data,
        })


class AdminReviewApproveAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, review_id):
        try:
            review = Review.objects.get(id=review_id)
        except Review.DoesNotExist:
            return Response(
                {'error': 'التقييم غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        review.is_approved  = True
        review.approved_by  = request.user
        review.approved_at  = timezone.now()
        review.save()

        return Response({
            'success': True,
            'message': 'تم قبول التقييم'
        })


class AdminReviewRejectAPIView(APIView):
    permission_classes = [IsAdminDashboard]

    def post(self, request, review_id):
        try:
            review = Review.objects.get(id=review_id)
        except Review.DoesNotExist:
            return Response(
                {'error': 'التقييم غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )

        review.is_approved = False
        review.save()

        return Response({
            'success': True,
            'message': 'تم رفض التقييم'
        })
