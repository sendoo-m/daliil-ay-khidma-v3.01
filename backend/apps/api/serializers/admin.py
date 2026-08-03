"""
Admin API Serializers — إعادة كتابة
====================================
يعالج ثلاث مشاكل في النسخة السابقة:

1. `StringRelatedField` جعل الحقول المرتبطة للقراءة فقط، فكان مستحيلًا
   على تطبيق الإدارة إنشاء نشاط أو تغيير تصنيفه. الحل: حقل كتابة
   بالمعرّف (`category`) + حقل عرض منفصل (`category_detail`).

2. `fields = '__all__'` كان يسرّب أي حقل يُضاف للموديل مستقبلًا،
   ويكسر التطبيق عند أي migration. الحل: حقول صريحة.

3. `SerializerMethodField` مع `.count()` كان ينتج N+1. الحل: القيم
   تأتي من `annotate()` في الـViewSet.
"""

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import serializers

from apps.deals.models import Deal
from apps.directory.models import Business, Category
from apps.products.models import Product
from apps.reviews.models import Review

User = get_user_model()


class CompactRelationSerializer(serializers.Serializer):
    """تمثيل مختصر موحّد لأي كائن مرتبط. يقلّل حجم الاستجابة."""

    id = serializers.IntegerField(read_only=True)
    label = serializers.SerializerMethodField()

    def get_label(self, obj) -> str:
        return str(obj)


# ── المستخدمون ────────────────────────────────────────

class AdminUserSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='get_full_name', read_only=True)

    # تأتي من annotate() — بدون استعلام إضافي لكل صف.
    businesses_count = serializers.IntegerField(read_only=True)
    reviews_count = serializers.IntegerField(read_only=True)

    admin_role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'phone', 'first_name', 'last_name',
            'full_name', 'city', 'is_active', 'is_staff', 'is_business_owner',
            'email_verified', 'date_joined', 'last_login',
            'businesses_count', 'reviews_count', 'admin_role',
        ]
        read_only_fields = ['id', 'date_joined', 'last_login', 'username']

    def get_admin_role(self, obj) -> str | None:
        profile = getattr(obj, 'staff_profile', None)
        return profile.role.name_ar if profile and profile.is_active else None


# ── الأنشطة ───────────────────────────────────────────

class AdminBusinessListSerializer(serializers.ModelSerializer):
    """نسخة خفيفة للقوائم — لا تُرسل كل حقول الموديل."""

    owner_name = serializers.CharField(source='owner.username', read_only=True)
    category_name = serializers.CharField(source='category.name_ar', read_only=True)
    governorate_name = serializers.CharField(
        source='district.city.governorate.name_ar', read_only=True
    )

    class Meta:
        model = Business
        fields = [
            'id', 'name_ar', 'name_en', 'slug',
            'owner_name', 'category_name', 'governorate_name',
            'is_active', 'is_verified', 'is_featured',
            'view_count', 'click_count', 'created_at',
        ]


class AdminBusinessSerializer(serializers.ModelSerializer):
    """نسخة كاملة للتفاصيل والتعديل."""

    # حقول الكتابة — بالمعرّف
    owner = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())
    category = serializers.PrimaryKeyRelatedField(queryset=Category.objects.all())

    # حقول العرض — مشتقة، للقراءة فقط
    owner_detail = CompactRelationSerializer(source='owner', read_only=True)
    category_detail = CompactRelationSerializer(source='category', read_only=True)
    business_type_display = serializers.CharField(
        source='get_business_type_display', read_only=True
    )

    class Meta:
        model = Business
        exclude = ['search_vector'] if hasattr(Business, 'search_vector') else []
        read_only_fields = [
            'id', 'slug', 'created_at', 'updated_at',
            'view_count', 'click_count',  # لا تُعدَّل يدويًا أبدًا
        ]

    def validate(self, attrs):
        """
        الحماية الحقيقية: التوثيق والتمييز لا يُضبطان عبر PATCH العادي،
        بل عبر endpoints مخصّصة تتحقق من صلاحية منفصلة وتُسجَّل في السجل.
        """
        protected = {'is_verified', 'is_featured'}
        touched = protected.intersection(attrs)
        if touched and not self.context.get('allow_status_change'):
            raise serializers.ValidationError({
                field: 'استخدم العملية المخصّصة لهذا الحقل بدل التعديل المباشر.'
                for field in touched
            })
        return attrs


# ── التصنيفات ─────────────────────────────────────────

class AdminCategorySerializer(serializers.ModelSerializer):
    businesses_count = serializers.IntegerField(read_only=True)
    parent_name = serializers.CharField(
        source='parent.name_ar', read_only=True, allow_null=True
    )
    parent = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(), allow_null=True, required=False
    )

    class Meta:
        model = Category
        fields = [
            'id', 'name_ar', 'name_en', 'slug', 'icon', 'image',
            'parent', 'parent_name', 'order', 'is_active',
            'businesses_count', 'created_at',
        ]
        read_only_fields = ['id', 'slug', 'created_at']

    def validate_parent(self, value):
        """منع الحلقات: تصنيف لا يكون أبًا لنفسه أو لأحد أجداده."""
        if value is None or self.instance is None:
            return value

        node = value
        seen = set()
        while node is not None:
            if node.pk == self.instance.pk:
                raise serializers.ValidationError('لا يمكن أن يكون التصنيف أبًا لنفسه.')
            if node.pk in seen:
                break
            seen.add(node.pk)
            node = node.parent
        return value


# ── المنتجات والعروض ──────────────────────────────────

class AdminProductSerializer(serializers.ModelSerializer):
    business = serializers.PrimaryKeyRelatedField(queryset=Business.objects.all())
    business_detail = CompactRelationSerializer(source='business', read_only=True)
    product_type_display = serializers.CharField(
        source='get_product_type_display', read_only=True
    )

    class Meta:
        model = Product
        exclude = []
        read_only_fields = ['id', 'slug', 'created_at', 'updated_at']


class AdminDealSerializer(serializers.ModelSerializer):
    business = serializers.PrimaryKeyRelatedField(queryset=Business.objects.all())
    business_detail = CompactRelationSerializer(source='business', read_only=True)
    deal_type_display = serializers.CharField(
        source='get_deal_type_display', read_only=True
    )
    days_remaining = serializers.SerializerMethodField()

    class Meta:
        model = Deal
        exclude = []
        read_only_fields = ['id', 'slug', 'used_count', 'created_at', 'updated_at']

    def get_days_remaining(self, obj) -> int | None:
        if not obj.end_date:
            return None
        end = obj.end_date
        now = timezone.now()
        delta = (end - now) if timezone.is_aware(end) else (end - now.date())
        days = delta.days
        return max(days, 0)

    def validate(self, attrs):
        start = attrs.get('start_date', getattr(self.instance, 'start_date', None))
        end = attrs.get('end_date', getattr(self.instance, 'end_date', None))
        if start and end and end < start:
            raise serializers.ValidationError(
                {'end_date': 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البداية.'}
            )
        return attrs


# ── التقييمات ─────────────────────────────────────────

class AdminReviewSerializer(serializers.ModelSerializer):
    user_detail = CompactRelationSerializer(source='user', read_only=True)
    business_detail = CompactRelationSerializer(source='business', read_only=True)
    reports_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Review
        fields = [
            'id', 'user_detail', 'business_detail', 'rating', 'comment',
            'is_approved', 'reports_count', 'created_at', 'updated_at',
        ]
        read_only_fields = fields  # التعديل يتم عبر approve/reject فقط


# ── لوحة المعلومات ────────────────────────────────────

class DashboardStatsSerializer(serializers.Serializer):
    users = serializers.DictField()
    businesses = serializers.DictField()
    content = serializers.DictField()
    engagement = serializers.DictField()
    generated_at = serializers.DateTimeField()


class MonthlyPointSerializer(serializers.Serializer):
    month = serializers.IntegerField()
    label = serializers.CharField()
    users = serializers.IntegerField()
    businesses = serializers.IntegerField()
    products = serializers.IntegerField()
    reviews = serializers.IntegerField()
