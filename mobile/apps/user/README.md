# تطبيق المستخدم

انسخ محتوى `mobile/dalil_app/` من v2 هنا، ثم أضف الحزمة المشتركة إلى `pubspec.yaml`:

```yaml
dependencies:
  dalil_core:
    path: ../../packages/dalil_core
```

بعدها احذف من `lib/core/` الملفات التي صار لها بديل في `dalil_core`:
`network/api_client.dart` · `network/api_failure.dart` · `network/paginated_result.dart` · `auth/token_store.dart`

واستبدل استيرادها بـ`import 'package:dalil_core/dalil_core.dart';`

## تنظيف مطلوب قبل النقل

في v2 توجد نسخ متعددة من نفس الشاشة. اختر واحدة واحذف الباقي:

- `home_page.dart` · `home_page_v3.dart` · `home_page_v4.dart`
- `product_detail_page.dart` · `product_detail_page_v2.dart`
- `business_detail_page.dart` · `business_detail_page_v2.dart`
- `favorites/presentation/favorites_page.dart` · `directory/presentation/favorites_page.dart`

## إضافة مطلوبة

`cached_network_image` — التطبيق حاليًا يعيد تحميل كل صورة عند كل تمرير. أكبر مكسب أداء متاح بأقل جهد.
