"""
Map Link → Coordinates
======================
يستخرج خط الطول والعرض من رابط خرائط ملزوق.

**بلا أي نداء شبكة وبلا مفتاح API.** الإحداثيات مكتوبة داخل الرابط نفسه،
واستخراجها تقطيع نص لا أكثر. هذا ما يجعل الحل ممكنًا بلا Google Maps API:
نحن لا نطلب من جوجل شيئًا، نقرأ ما لصقه المستخدم.

الروابط المختصرة (maps.app.goo.gl) استثناء: لا تحمل إحداثيات، وفتحها
يحتاج نداء شبكة قد يفشل أو يبطئ الحفظ. نكشفها ونطلب من المستخدم الرابط
الكامل — أوضح من عملية تنجح أحيانًا وتفشل صامتة أحيانًا.
"""

from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation

#: حدود مصر تقريبًا، بهامش. إحداثيات خارجها في تطبيق محلي تعني غالبًا
#: أن الأرقام انقلبت (خط الطول مكان العرض) لا أن المحل في أوروبا.
EGYPT_BOUNDS = {
    'lat': (21.0, 32.5),
    'lng': (24.0, 37.5),
}

#: نطاق الأرض — الحد الأدنى للقبول.
WORLD_BOUNDS = {'lat': (-90.0, 90.0), 'lng': (-180.0, 180.0)}

#: أنماط روابط خرائط جوجل الشائعة، بالترتيب من الأدق إلى الأعم.
_PATTERNS = [
    # ‏!3d<lat>!4d<lng> — يظهر في روابط المشاركة الكاملة، وهو الأدق
    # لأنه يشير إلى المكان نفسه لا إلى مركز الشاشة.
    re.compile(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)'),
    # ‏?q=<lat>,<lng>  و  ?q=loc:<lat>,<lng>
    re.compile(r'[?&]q=(?:loc:)?(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)'),
    # ‏?ll= و ?daddr= و ?saddr= و ?center=
    re.compile(
        r'[?&](?:ll|daddr|saddr|center|destination)='
        r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)'
    ),
    # ‏@<lat>,<lng>,<zoom>z — مركز الشاشة، أقل دقة فيأتي بعد ما سبقه
    re.compile(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
    # ‏geo:<lat>,<lng>
    re.compile(r'geo:(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
    # آخر محاولة: زوج أرقام عشرية مفصولة بفاصلة في أي مكان
    re.compile(r'(-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})'),
]

#: نطاقات الروابط المختصرة — لا تحمل إحداثيات.
_SHORT_HOSTS = (
    'maps.app.goo.gl',
    'goo.gl/maps',
    'g.co/kgs',
    'bit.ly',
    'tinyurl.com',
)


class LinkResult:
    """نتيجة القراءة: إحداثيات، أو سبب واضح للفشل."""

    __slots__ = ('latitude', 'longitude', 'reason')

    def __init__(self, latitude=None, longitude=None, reason=''):
        self.latitude = latitude
        self.longitude = longitude
        self.reason = reason

    @property
    def ok(self) -> bool:
        return self.latitude is not None and self.longitude is not None

    def __bool__(self) -> bool:
        return self.ok

    def __repr__(self) -> str:
        return (
            f'LinkResult({self.latitude}, {self.longitude})'
            if self.ok
            else f'LinkResult(fail: {self.reason})'
        )


def is_short_link(url: str) -> bool:
    lowered = (url or '').lower()
    return any(host in lowered for host in _SHORT_HOSTS)


def extract_coordinates(url: str) -> LinkResult:
    """
    يقرأ الإحداثيات من رابط خرائط.

    يعيد [LinkResult]؛ عند الفشل يحمل `reason` بالعربية جاهزة للعرض.
    """
    if not url or not url.strip():
        return LinkResult(reason='الرابط فاضي.')

    text = url.strip()

    if is_short_link(text):
        return LinkResult(
            reason='الرابط ده مختصر ومفيهوش إحداثيات. افتحه في خرائط جوجل، '
            'وبعدين انسخ الرابط الكامل من شريط العنوان.'
        )

    for pattern in _PATTERNS:
        match = pattern.search(text)
        if not match:
            continue

        try:
            latitude = Decimal(match.group(1))
            longitude = Decimal(match.group(2))
        except (InvalidOperation, IndexError):
            continue

        lat_f, lng_f = float(latitude), float(longitude)

        if not (
            WORLD_BOUNDS['lat'][0] <= lat_f <= WORLD_BOUNDS['lat'][1]
            and WORLD_BOUNDS['lng'][0] <= lng_f <= WORLD_BOUNDS['lng'][1]
        ):
            continue

        # ‏!3d!4d يضع خط العرض أولًا دائمًا، لكن بعض الروابط المنسوخة
        # يدويًا تعكس الترتيب. لو القيم مقلوبة وتصير داخل مصر بالعكس،
        # نصحّحها بدل رفض رابط صحيح المحتوى.
        if not _within_egypt(lat_f, lng_f) and _within_egypt(lng_f, lat_f):
            latitude, longitude = longitude, latitude

        return LinkResult(latitude=latitude, longitude=longitude)

    return LinkResult(
        reason='مش لاقي إحداثيات في الرابط ده. افتح المكان في خرائط جوجل '
        'وانسخ الرابط من شريط العنوان.'
    )


def _within_egypt(latitude: float, longitude: float) -> bool:
    return (
        EGYPT_BOUNDS['lat'][0] <= latitude <= EGYPT_BOUNDS['lat'][1]
        and EGYPT_BOUNDS['lng'][0] <= longitude <= EGYPT_BOUNDS['lng'][1]
    )


def apply_link_to(business) -> LinkResult:
    """
    يملأ إحداثيات النشاط من رابطه المحفوظ.

    لا يكتب فوق إحداثيات موجودة: من ضبط موقعه بالـGPS واقفًا في محله
    أدق من أي رابط، ولا يصح أن يمحوه لصق رابط لاحق.
    """
    if business.latitude is not None and business.longitude is not None:
        return LinkResult(
            latitude=business.latitude,
            longitude=business.longitude,
        )

    result = extract_coordinates(getattr(business, 'location_url', '') or '')
    if result.ok:
        business.latitude = result.latitude
        business.longitude = result.longitude
    return result
