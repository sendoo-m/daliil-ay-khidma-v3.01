"""
Public Browsing API
===================
النقاط التي تجعل التنقّل يشتغل: تصفّح بالقسم وتصفّح بالمحافظة.

كل نقطة هنا تعيد **عدّادات مع الأسماء**. السبب عملي: قائمة أقسام بلا
أعداد تجعل المستخدم يفتح قسمًا فارغًا ثم يرجع، ثم آخر فارغًا. العدد
يمنع الرحلة العمياء — ويكشف لك أنت أي الأقسام تحتاج بيانات.
"""

from django.db.models import Count, Q
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.categories.models import Category
from apps.directory.models import Business
from apps.directory.models.location import City, District, Governorate

#: الأدلة الثلاثة كما تُعرض في الواجهة.
DIRECTORIES = [
    {
        'key': 'shop',
        'name': 'محلات ومنتجات',
        'description': 'محلات تجارية بمنتجات وعروض',
        'icon': 'storefront',
    },
    {
        'key': 'craft',
        'name': 'حرف ومهن',
        'description': 'سبّاك · نجار · كهربائي · نقاش',
        'icon': 'handyman',
    },
    {
        'key': 'public',
        'name': 'خدمات عامة',
        'description': 'مستشفيات · شرطة · مطافي · حدائق',
        'icon': 'local_hospital',
    },
]


def _published():
    """
    الأنشطة الظاهرة للجمهور.

    الخدمة العامة يجب أن تكون موثَّقة: مستشفى برقم خطأ أسوأ من مستشفى
    غائب — الناس تبحث عن هذا الرقم وقت الأزمة.
    """
    return Business.objects.filter(is_active=True, is_verified=True)


@api_view(['GET'])
@permission_classes([AllowAny])
def directories(request):
    """
    GET /api/v2/browse/directories/

    الأدلة الثلاثة مع عدد الأنشطة في كل واحد. يبني الشاشة الرئيسية.
    """
    governorate = request.query_params.get('governorate')

    qs = _published()
    if governorate:
        qs = qs.filter(district__city__governorate_id=governorate)

    counts = dict(
        qs.values_list('business_type').annotate(n=Count('id')).values_list(
            'business_type', 'n'
        )
    )

    return Response([
        {**d, 'count': counts.get(d['key'], 0)} for d in DIRECTORIES
    ])


@api_view(['GET'])
@permission_classes([AllowAny])
def categories_by_directory(request):
    """
    GET /api/v2/browse/categories/?type=craft[&governorate=3]

    أقسام دليل واحد مع عدد الأنشطة في كل قسم. بدون `type` تُعاد كل
    الأقسام مجمّعة حسب الدليل.
    """
    directory = request.query_params.get('type')
    governorate = request.query_params.get('governorate')

    valid = {d['key'] for d in DIRECTORIES}
    if directory and directory not in valid:
        return Response(
            {'detail': 'نوع الدليل غير معروف.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    business_filter = Q(business__is_active=True, business__is_verified=True)
    if governorate:
        business_filter &= Q(
            business__district__city__governorate_id=governorate
        )

    qs = Category.objects.filter(is_active=True)
    if directory:
        qs = qs.filter(business_type=directory)

    # الاسم `n_items` لا `businesses_count`: الأخير موجود بالفعل
    # كـproperty على هذه الموديلات، و Django لا يستطيع الكتابة فوق
    # خاصية للقراءة فقط — الخطأ يظهر وقت التنفيذ لا وقت الفحص.
    qs = qs.annotate(
        n_items=Count('business', filter=business_filter, distinct=True)
    ).order_by('-n_items', 'order', 'name_ar')

    rows = [
        {
            'id': c.id,
            'slug': c.slug,
            'name': c.name_ar or c.name_en,
            'icon': c.icon or '',
            'image': c.image.url if c.image else None,
            'business_type': c.business_type,
            'count': c.n_items,
        }
        for c in qs
    ]

    if directory:
        return Response(rows)

    # بلا نوع: مجمّعة حسب الدليل — يوفّر ثلاث نداءات على الشاشة الواحدة.
    return Response([
        {
            **d,
            'categories': [r for r in rows if r['business_type'] == d['key']],
        }
        for d in DIRECTORIES
    ])


@api_view(['GET'])
@permission_classes([AllowAny])
def governorate_overview(request, pk):
    """
    GET /api/v2/browse/governorates/<id>/

    كل ما في محافظة: مدنها وأحياؤها وأقسامها مع الأعداد.

    نداء واحد لا أربعة — الشاشة تعرض كل هذا معًا، وأربعة نداءات على
    شبكة موبايل ضعيفة تعني أربع فرص للفشل وشاشة تتجمّع على مراحل.
    """
    governorate = Governorate.objects.filter(pk=pk, is_active=True).first()
    if governorate is None:
        return Response(
            {'detail': 'المحافظة غير موجودة.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    in_gov = _published().filter(district__city__governorate=governorate)

    by_type = dict(
        in_gov.values_list('business_type')
        .annotate(n=Count('id'))
        .values_list('business_type', 'n')
    )

    cities = (
        City.objects.filter(governorate=governorate, is_active=True)
        .annotate(
            n_items=Count(
                'districts__business',
                filter=Q(
                    districts__business__is_active=True,
                    districts__business__is_verified=True,
                ),
                distinct=True,
            )
        )
        .order_by('-n_items', 'name_ar')
    )

    districts = (
        District.objects.filter(
            city__governorate=governorate, is_active=True
        )
        .annotate(
            n_items=Count(
                'business',
                filter=Q(business__is_active=True, business__is_verified=True),
                distinct=True,
            )
        )
        .filter(n_items__gt=0)
        .order_by('-n_items', 'name_ar')
    )

    return Response({
        'id': governorate.id,
        'slug': governorate.slug,
        'name': governorate.name_ar or governorate.name_en,
        'total': in_gov.count(),
        'directories': [
            {**d, 'count': by_type.get(d['key'], 0)} for d in DIRECTORIES
        ],
        'cities': [
            {
                'id': c.id,
                'name': c.name_ar or c.name_en,
                'count': c.n_items,
            }
            for c in cities
        ],
        # الأحياء الفارغة محذوفة: قائمة من مئة حي أغلبها صفر لا تُتصفَّح.
        'districts': [
            {
                'id': d.id,
                'name': d.name_ar or d.name_en,
                'city': d.city_id,
                'count': d.n_items,
            }
            for d in districts[:80]
        ],
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def governorates_index(request):
    """
    GET /api/v2/browse/governorates/

    المحافظات مرتّبة بالأكثر امتلاءً — لا أبجديًا. المستخدم يريد أن
    يجد شيئًا، والمحافظة الفارغة في الأعلى تعلّمه أن التطبيق فاضي.
    """
    qs = (
        Governorate.objects.filter(is_active=True)
        .annotate(
            # المسار العكسي: cities → districts → business.
            # ‏Count تستعمل related_query_name وهو مختلف عن related_name
            # في بعض الحقول هنا — لذا الأسماء ليست موحّدة الصيغة.
            n_items=Count(
                'cities__districts__business',
                filter=Q(
                    cities__districts__business__is_active=True,
                    cities__districts__business__is_verified=True,
                ),
                distinct=True,
            )
        )
        .order_by('-n_items', 'name_ar')
    )

    return Response([
        {
            'id': g.id,
            'slug': g.slug,
            'name': g.name_ar or g.name_en,
            'count': g.n_items,
        }
        for g in qs
    ])
