"""
Merchant API — Serializers
==========================
كل serializer هنا يحدد حقوله **صراحةً**. لا `fields = '__all__'`
ولا `exclude`.

السبب: مع `__all__`، أي حقل يُضاف للموديل مستقبلًا يصبح قابلًا للكتابة
من تطبيق التاجر تلقائيًا. لو كان الحقل الجديد `is_verified` أو
`commission_rate`، تكون فتحت ثغرة بـmigration بريء.

القائمة الصريحة تعني أن توسيع الموديل لا يوسّع صلاحيات التاجر.
"""

from rest_framework import serializers

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product
from apps.reviews.models import Review, ReviewReply


class MerchantBusinessSerializer(serializers.ModelSerializer):
    """
    نشاط التاجر كما يراه ويعدّله.

    ما هو غائب هنا مقصود: `owner` و`is_verified` و`is_featured`
    و`category`. التوثيق والتمييز قرار إداري، والملكية لا تُنقل من
    التطبيق، والعدّادات يكتبها النظام لا التاجر.
    """

    category_name = serializers.CharField(source='category.name_ar', read_only=True)
    governorate_name = serializers.CharField(
        source='district.city.governorate.name_ar', read_only=True
    )
    city_name = serializers.CharField(source='district.city.name_ar', read_only=True)

    view_count = serializers.IntegerField(read_only=True)
    click_count = serializers.IntegerField(read_only=True)
    is_verified = serializers.BooleanField(read_only=True)
    is_featured = serializers.BooleanField(read_only=True)

    class Meta:
        model = Business
        fields = [
            'id', 'slug',
            'name_ar', 'name_en',
            'description_ar', 'description_en',
            'phone', 'whatsapp', 'email', 'website',
            'facebook', 'instagram',
            'address_ar', 'address_en',
            'latitude', 'longitude',
            'working_hours_ar', 'working_hours_en',
            'logo', 'cover_image',
            'category_name', 'governorate_name', 'city_name',
            'is_active', 'is_verified', 'is_featured',
            'view_count', 'click_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'slug', 'created_at', 'updated_at']

    def validate_name_ar(self, value):
        """
        تغيير الاسم يُبطل معنى التوثيق — لذا نمنعه على نشاط موثّق.
        بدون هذا يستطيع تاجر توثيق "مطعم النيل" ثم تحويله لأي شيء آخر
        محتفظًا بعلامة التوثيق التي مُنحت لشيء مختلف.
        """
        if (
            self.instance is not None
            and self.instance.is_verified
            and value != self.instance.name_ar
        ):
            raise serializers.ValidationError(
                'لا يمكن تغيير اسم نشاط موثّق. تواصل مع الدعم لطلب التغيير.'
            )
        return value


class MerchantProductSerializer(serializers.ModelSerializer):
    """
    منتج. `business` قابل للكتابة، لكن الـViewSet يتحقق أنه من أنشطة
    المستخدم — وإلا أمكن للتاجر إضافة منتج لمحل غيره.
    """

    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    product_type_display = serializers.CharField(
        source='get_product_type_display', read_only=True
    )
    # التمييز قرار إداري لا يُشترى من التطبيق.
    is_featured = serializers.BooleanField(read_only=True)

    class Meta:
        model = Product
        fields = [
            'id', 'slug', 'business', 'business_name',
            'name_ar', 'name_en',
            'description_ar', 'description_en',
            'product_type', 'product_type_display',
            'price', 'old_price',
            'is_available', 'stock_quantity',
            'has_delivery', 'delivery_cost',
            'delivery_time_ar', 'delivery_time_en',
            'order', 'view_count', 'is_featured',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'slug', 'view_count', 'created_at', 'updated_at',
        ]

    def validate(self, attrs):
        """`old_price` هو السعر قبل الخصم، فيجب أن يكون أعلى من الحالي."""
        price = attrs.get('price', getattr(self.instance, 'price', None))
        old = attrs.get('old_price', getattr(self.instance, 'old_price', None))
        if price is not None and old is not None and old <= price:
            raise serializers.ValidationError({
                'old_price': 'السعر قبل الخصم يجب أن يكون أعلى من السعر الحالي.'
            })
        return attrs


class MerchantDealSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    deal_type_display = serializers.CharField(
        source='get_deal_type_display', read_only=True
    )
    current_uses = serializers.IntegerField(read_only=True)
    is_featured = serializers.BooleanField(read_only=True)

    class Meta:
        model = Deal
        fields = [
            'id', 'slug', 'business', 'business_name',
            'title_ar', 'title_en',
            'description_ar', 'description_en',
            'deal_type', 'deal_type_display',
            'discount_percentage', 'discount_amount',
            'original_price', 'final_price',
            'terms_ar', 'terms_en',
            'start_date', 'end_date',
            'max_uses', 'max_uses_per_user', 'current_uses',
            'image', 'is_active', 'is_featured', 'order',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'slug', 'current_uses', 'created_at', 'updated_at',
        ]

    def validate(self, attrs):
        start = attrs.get('start_date', getattr(self.instance, 'start_date', None))
        end = attrs.get('end_date', getattr(self.instance, 'end_date', None))
        if start and end and end < start:
            raise serializers.ValidationError({
                'end_date': 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البداية.'
            })
        return attrs


class MerchantReplySerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewReply
        fields = ['id', 'comment', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_comment(self, value):
        text = (value or '').strip()
        if len(text) < 2:
            raise serializers.ValidationError('الرد قصير جدًا.')
        return text


class MerchantReviewSerializer(serializers.ModelSerializer):
    """
    تقييم على نشاط التاجر — للقراءة فقط.

    التقييم كلام العميل. التاجر يرد عليه ولا يعدّله ولا يحذفه، وإلا
    فقدت التقييمات معناها كإشارة. الإبلاغ عن تقييم مسيء يمر على
    الموظفين، وهذا هو الضمان الوحيد الذي يجعل التقييمات تُصدَّق.
    """

    reviewer_name = serializers.SerializerMethodField()
    business_name = serializers.CharField(source='business.name_ar', read_only=True)
    reply = MerchantReplySerializer(read_only=True)

    class Meta:
        model = Review
        fields = [
            'id', 'business', 'business_name',
            'reviewer_name', 'rating', 'comment',
            'reply', 'created_at',
        ]
        read_only_fields = fields

    def get_reviewer_name(self, obj) -> str:
        user = obj.user
        if user is None:
            return 'مستخدم محذوف'
        return user.get_full_name() or user.username
