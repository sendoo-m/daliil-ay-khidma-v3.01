# دمج طبقة الإدارة والصلاحيات

المرحلة الأولى من الأساس المعماري. الملفات جاهزة للنسخ فوق المشروع مع الحفاظ على مساراته.

---

## 1. نسخ الملفات

```
apps/administration/            ← جديد بالكامل
apps/api/serializers/admin.py   ← يستبدل الموجود
apps/api/views/admin.py         ← يستبدل الموجود
```

احتفظ بنسخة من الملفين القديمين قبل الاستبدال (`git branch feature/rbac` قبل أي شيء).

---

## 2. تسجيل التطبيق

في `config/settings/base.py`:

```python
INSTALLED_APPS = [
    ...
    'apps.core',
    'apps.accounts',
    'apps.administration',   # ← أضف هنا، قبل apps.api
    'apps.api',
    ...
]
```

---

## 3. الترحيلات

```bash
python manage.py makemigrations administration
python manage.py migrate
python manage.py seed_roles
```

`seed_roles` ينشئ ستة أدوار: مدير عام، مدير تشغيل، مراجع أنشطة، مشرف محتوى، دعم فني، محلل بيانات. الأمر آمن للتكرار.

---

## 4. المسارات

في `apps/api/urls_v2.py` أضف:

```python
from apps.administration.views import (
    AdminSessionView, PermissionCatalogView,
    RoleViewSet, StaffProfileViewSet, AuditLogViewSet,
)

router.register(r'admin/roles', RoleViewSet,         basename='admin-roles')
router.register(r'admin/staff', StaffProfileViewSet, basename='admin-staff')
router.register(r'admin/audit', AuditLogViewSet,     basename='admin-audit')

urlpatterns = [
    ...
    path('admin/session/',     AdminSessionView.as_view(),     name='admin_session'),
    path('admin/permissions/', PermissionCatalogView.as_view(), name='admin_permissions'),
]
```

---

## 5. أول موظف

الـ`superuser` الحالي يعمل فورًا بلا إعداد — هو مسار الطوارئ. لإضافة موظف عادي:

```python
from apps.accounts.models import User
from apps.administration.models import Role, StaffProfile
from apps.directory.models import Governorate

user = User.objects.get(username='ahmed')
role = Role.objects.get(slug='business_reviewer')

profile = StaffProfile.objects.create(user=user, role=role, job_title='مراجع أنشطة')
profile.governorates.set(Governorate.objects.filter(name_ar__in=['أسيوط', 'سوهاج']))
```

هذا الموظف يرى ويوثّق أنشطة أسيوط وسوهاج فقط. أي محاولة للوصول لنشاط خارج نطاقه ترجع `404` من القائمة و`403` من العملية المباشرة.

---

## 6. تحقّق من الدمج

```bash
python manage.py shell -c "
from apps.administration.constants import all_permissions
from apps.administration.models import Role
print(f'صلاحيات مسجّلة: {len(all_permissions())}')
for r in Role.objects.all():
    print(f'  {r.name_ar:20} {len(r.permissions):2} صلاحية')
"
```

---

## القواعد المعمارية المطبَّقة

**الافتراضي هو المنع.** أي `action` غير مذكور في `required_permissions` يُرفض بـ403. إضافة endpoint ونسيان تسجيل صلاحيته تُنتج خطأ ظاهرًا وقت الاختبار، لا ثغرة صامتة في الإنتاج.

**الكود يفحص صلاحية، لا دورًا.** `user_can(user, Perm.BUSINESS_VERIFY)` وليس `role == 'reviewer'`. إضافة دور جديد من التطبيق لا تتطلب نشر كود.

**التسجيل تلقائي.** `AdminModelViewSet` يكتب في `AuditLog` عند كل create/update/delete مع الفروق (`{"is_verified": {"from": false, "to": true}}`). لا يمكن نسيانه لأنه ليس خطوة يدوية.

**السجل غير قابل للتعديل.** `AuditLog.save()` يرفض أي تعديل بعد الإنشاء، و`delete()` يرفض دائمًا.

**لا تصعيد صلاحيات.** موظف لا يستطيع منح دور يحوي صلاحية لا يملكها هو — وإلا لاستطاع أي موظف عنده `staff.manage` أن يرقّي نفسه بإنشاء حساب أقوى.

**لا يعطّل أحد نفسه**، ولا يمس أحدٌ حساب `superuser` إلا `superuser` آخر.

**التعليق بديل الحذف.** حذف المستخدمين معطّل — قرار قابل للتراجع أفضل من قرار نهائي بضغطة زر.

---

## الأخطاء التي أُصلحت في الـAPI القديم

| المشكلة | التأثير قبل الإصلاح |
|---|---|
| `ordering_fields = ['views_count']` والحقل `view_count` | خطأ 500 عند الفرز بالمشاهدات |
| `StringRelatedField` على `owner` و`category` | استحالة إنشاء أو تعديل نشاط من التطبيق |
| `fields = '__all__'` | تسريب أي حقل جديد + كسر عند أي migration |
| `analytics` بحلقة 12 شهر × 4 موديلات | 48 استعلامًا في الطلب الواحد → صار 4 |
| `stats` بـ18 عدّادًا منفصلًا بلا كاش | صار مجمّعًا ومخزّنًا 60 ثانية |
| `get_businesses_count` بـ`.count()` لكل صف | N+1 → صار `annotate` |
| `IsAdminUser` = `is_staff` فقط | موظف دعم يستطيع حذف مستخدمين |
| `make_staff` بلا نظير يسحب الصلاحية | لا سبيل لإنزال موظف |
| لا سجل عمليات | لا إجابة على "من فعل هذا؟" |
| لا عمليات جماعية | اعتماد 30 تقييمًا = 30 طلبًا |

---

## endpoints الجاهزة الآن

```
GET    /api/v2/admin/session/              هوية الموظف وصلاحياته ونطاقه
GET    /api/v2/admin/permissions/          كتالوج الصلاحيات لبناء شاشة الأدوار

GET    /api/v2/admin/dashboard/stats/      مؤشرات اللوحة (مقيّدة بالنطاق)
GET    /api/v2/admin/dashboard/analytics/?year=2026
GET    /api/v2/admin/dashboard/pending-queue/   ما ينتظر تدخّلًا

CRUD   /api/v2/admin/roles/
CRUD   /api/v2/admin/staff/
POST   /api/v2/admin/staff/{id}/change-role/
GET    /api/v2/admin/audit/                سجل العمليات

CRUD   /api/v2/admin/businesses/
POST   /api/v2/admin/businesses/{id}/verify/
POST   /api/v2/admin/businesses/{id}/unverify/
POST   /api/v2/admin/businesses/{id}/toggle-featured/
POST   /api/v2/admin/businesses/{id}/suspend/        (السبب إلزامي)
POST   /api/v2/admin/businesses/bulk-update/

CRUD   /api/v2/admin/reviews/
POST   /api/v2/admin/reviews/{id}/approve/
POST   /api/v2/admin/reviews/{id}/reject/
POST   /api/v2/admin/reviews/bulk-update/

CRUD   /api/v2/admin/users/  · /categories/ (+reorder) · /products/ · /deals/
POST   /api/v2/admin/users/{id}/suspend/ · /activate/
```

---

## الخطوة التالية

`GET /admin/session/` مصمَّم ليكون أول نداء بعد الدخول: يعيد قائمة الصلاحيات فيبني تطبيق Flutter قائمته وأزراره منها، فلا يرى الموظف زرًا يفشل بـ403 عند الضغط.

الجاهز للبناء عليه بعد ذلك:

1. `dalil_core` — package مشترك يستخرج `ApiClient` و`TokenStore` من تطبيق المستخدم ليستعمله التطبيقان.
2. `dalil_admin` — تطبيق الإدارة، شاشة الدخول ثم `pending-queue` كشاشة رئيسية.
3. اختبارات الصلاحيات — لكل دور، تأكيد أنه يصل لما له ويُمنع عما ليس له.
