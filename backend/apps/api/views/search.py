"""
Unified Search
==============
بحث واحد يغطّي المحلات والحرف والخدمات العامة **والمنتجات معًا**.

القرار المعماري الأهم هنا: **الخريطة تعرض أماكن لا منتجات.**

لو بحثت عن "قهوة" وكان في كافيه عنده سبعة أصناف قهوة، فالنتيجة الصحيحة
دبوس واحد على الكافيه — لا سبعة دبابيس فوق بعضها في نفس الإحداثيات.
المنتج ليس له موقع أصلًا؛ موقعه هو موقع محله.

لذلك نجمع النتائج **حسب المكان**، ونرفق مع كل مكان المنتجات التي طابقت
كسبب للظهور. المستخدم يرى: "كافيه المرسى — عنده: قهوة تركي، قهوة فرنساوي".
وهذه معلومة أنفع من دبوس بلا سياق.
"""

from django.db.models import Prefetch, Q
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.directory.models import Business
from apps.products.models import Product

#: أقصى عدد أماكن في الرد. الخريطة لا تُقرأ بأكثر من ذلك، والقائمة
#: تُصفَّح بالفلاتر لا بالتمرير اللانهائي.
MAX_PLACES = 60

#: أقصى منتجات مُطابِقة تُعرض تحت كل مكان.
MAX_MATCHED_PRODUCTS = 4

MIN_QUERY = 2


def _published():
    return Business.objects.filter(is_active=True, is_verified=True)


def _place_payload(business, term):
    """يبني تمثيل المكان مع سبب المطابقة."""
    matched = list(getattr(business, 'matched_products', []))

    name_hit = term in (business.name_ar or '').lower() or term in (
        business.name_en or ''
    ).lower()
    category_name = (
        business.category.name_ar or business.category.name_en
        if business.category_id
        else ''
    )
    category_hit = term in (category_name or '').lower()

    if name_hit:
        reason = 'name'
    elif matched:
        reason = 'product'
    elif category_hit:
        reason = 'category'
    else:
        reason = 'description'

    return {
        'id': business.id,
        'slug': business.slug,
        'name': business.name_ar or business.name_en,
        'business_type': business.business_type,
        'category': category_name,
        'address': business.address_ar or business.address_en or '',
        'phone': business.phone or '',
        'whatsapp': business.whatsapp or '',
        'logo': business.logo.url if business.logo else None,
        'rating': float(business.average_rating or 0),
        'is_featured': business.is_featured,
        'latitude': float(business.latitude) if business.latitude else None,
        'longitude': float(business.longitude) if business.longitude else None,
        'match_reason': reason,
        'matched_products': [
            {
                'id': p.id,
                'name': p.name_ar or p.name_en,
                'price': str(p.price),
            }
            for p in matched[:MAX_MATCHED_PRODUCTS]
        ],
        'matched_products_count': len(matched),
    }


@api_view(['GET'])
@permission_classes([AllowAny])
def unified_search(request):
    """
    GET /api/v2/search/?q=قهوة

    معاملات اختيارية:
        type=shop|craft|public     قصر على دليل
        governorate / city / district
        has_location=true          للخريطة: الأماكن ذات الإحداثيات فقط
    """
    term = (request.query_params.get('q') or '').strip()
    if len(term) < MIN_QUERY:
        return Response(
            {'detail': f'اكتب {MIN_QUERY} حروف على الأقل.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    lowered = term.lower()

    # ── من يطابق ──
    direct = (
        Q(name_ar__icontains=term)
        | Q(name_en__icontains=term)
        | Q(description_ar__icontains=term)
        | Q(description_en__icontains=term)
    )
    by_category = (
        Q(category__name_ar__icontains=term)
        | Q(category__name_en__icontains=term)
    )
    # `product` لا `products`: العلاقة معرّفة بـrelated_query_name مفرد.
    by_product = (
        Q(product__name_ar__icontains=term)
        | Q(product__name_en__icontains=term)
        | Q(product__description_ar__icontains=term)
    )

    queryset = _published().filter(direct | by_category | by_product)

    # ── الفلاتر ──
    directory = request.query_params.get('type')
    if directory in {'shop', 'craft', 'public'}:
        queryset = queryset.filter(business_type=directory)

    for param, path in (
        ('governorate', 'district__city__governorate_id'),
        ('city', 'district__city_id'),
        ('district', 'district_id'),
    ):
        value = request.query_params.get(param)
        if value:
            queryset = queryset.filter(**{path: value})


    # المنتجات المطابقة تُجلب مع المكان في استعلام واحد — بدونها يصبح
    # كل مكان استعلامًا إضافيًا، وستون مكانًا تعني واحدًا وستين استعلامًا.
    matching_products = Product.objects.filter(
        Q(name_ar__icontains=term)
        | Q(name_en__icontains=term)
        | Q(description_ar__icontains=term),
        is_available=True,
    ).only('id', 'name_ar', 'name_en', 'price', 'business_id')

    queryset = (
        queryset.select_related('category', 'district__city__governorate')
        .prefetch_related(
            # ‏Prefetch يأخذ اسم الوصول `products`، بينما الفلترة أعلاه
            # تأخذ `product`. الاسمان مختلفان على نفس العلاقة: الأول
            # related_name والثاني related_query_name.
            Prefetch(
                'products',
                queryset=matching_products,
                to_attr='matched_products',
            )
        )
        .distinct()
    )

    places = [_place_payload(b, lowered) for b in queryset[:MAX_PLACES]]

    # ── الترتيب ──
    # مَن اسمه يطابق أولًا: من يكتب "قهوة" يريد الكافيه قبل البقالة التي
    # تبيع ظرف قهوة. ثم من عنده منتج مطابق، ثم الباقي.
    rank = {'name': 0, 'product': 1, 'category': 2, 'description': 3}
    places.sort(
        key=lambda p: (
            rank.get(p['match_reason'], 9),
            0 if p['is_featured'] else 1,
            -p['rating'],
            -p['matched_products_count'],
        )
    )

    # نفصل ما له موقع عمّا ليس له — ولا نحذف الثاني.
    #
    # الخريطة تعرض الدبابيس، والقائمة تحتها تعرض الباقي. الحذف يجعل
    # البحث يبدو معطّلًا: المستخدم يعرف أن المحل موجود ولا يراه، فيستنتج
    # أن التطبيق لا يعمل — بينما المشكلة أن أحدًا لم يضع إحداثيات المحل.
    located = [p for p in places if p['latitude'] is not None]
    unlocated = [p for p in places if p['latitude'] is None]

    return Response({
        'query': term,
        'count': len(places),
        'truncated': len(places) >= MAX_PLACES,
        'places': places,
        'on_map': located,
        'off_map': unlocated,
        'on_map_count': len(located),
        'off_map_count': len(unlocated),
        'summary': _summarise(places),
    })


def _summarise(places) -> dict:
    """أعداد حسب الدليل — تبني شرائح الفلترة فوق النتائج."""
    counts = {'shop': 0, 'craft': 0, 'public': 0}
    products = 0
    for place in places:
        counts[place['business_type']] = counts.get(
            place['business_type'], 0
        ) + 1
        products += place['matched_products_count']
    return {
        'shops': counts.get('shop', 0),
        'crafts': counts.get('craft', 0),
        'public': counts.get('public', 0),
        'matched_products': products,
    }


@api_view(['GET'])
@permission_classes([AllowAny])
def search_suggestions(request):
    """
    GET /api/v2/search/suggest/?q=قه

    اقتراحات سريعة أثناء الكتابة: أسماء أماكن ومنتجات وأقسام.
    خفيفة عمدًا — تُنادى مع كل حرف تقريبًا.
    """
    term = (request.query_params.get('q') or '').strip()
    if len(term) < MIN_QUERY:
        return Response([])

    suggestions = []

    for business in (
        _published()
        .filter(Q(name_ar__icontains=term) | Q(name_en__icontains=term))
        .only('id', 'name_ar', 'name_en', 'business_type')[:5]
    ):
        suggestions.append({
            'kind': 'place',
            'id': business.id,
            'label': business.name_ar or business.name_en,
            'business_type': business.business_type,
        })

    for product in (
        Product.objects.filter(
            Q(name_ar__icontains=term) | Q(name_en__icontains=term),
            is_available=True,
            business__is_active=True,
            business__is_verified=True,
        )
        .select_related('business')
        .only('id', 'name_ar', 'name_en', 'business__name_ar')[:5]
    ):
        suggestions.append({
            'kind': 'product',
            'id': product.id,
            'label': product.name_ar or product.name_en,
            'place': product.business.name_ar,
            'place_id': product.business_id,
        })

    return Response(suggestions)
