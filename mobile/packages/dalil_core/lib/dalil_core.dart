/// Shared foundation for the Daliil Ay Khidma user and admin apps.
///
/// كل ما يستعمله التطبيقان معًا يعيش هنا: طبقة الشبكة، تخزين الرموز،
/// معالجة الأخطاء، وقيم التصميم. أي تعديل هنا يصل للتطبيقين معًا.
library dalil_core;

export 'src/network/api_client.dart';
export 'src/network/api_failure.dart';
export 'src/network/paginated.dart';
export 'src/auth/token_store.dart';
export 'src/auth/auth_repository.dart';
export 'src/models/admin_session.dart';
export 'src/theme/tokens.dart';
