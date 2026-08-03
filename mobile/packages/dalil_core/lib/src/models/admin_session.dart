/// أكواد الصلاحيات — نسخة مطابقة لـ `apps/administration/constants.py`.
///
/// تُبقى متزامنة يدويًا. اختبار في `test/permissions_sync_test.dart`
/// يقارنها بالكتالوج من `GET /admin/permissions/` ويفشل عند أي انحراف.
abstract final class Perm {
  static const businessView = 'business.view';
  static const businessEdit = 'business.edit';
  static const businessCreate = 'business.create';
  static const businessVerify = 'business.verify';
  static const businessFeature = 'business.feature';
  static const businessSuspend = 'business.suspend';
  static const businessDelete = 'business.delete';

  static const productView = 'product.view';
  static const productEdit = 'product.edit';
  static const productDelete = 'product.delete';

  static const dealView = 'deal.view';
  static const dealEdit = 'deal.edit';
  static const dealDelete = 'deal.delete';

  static const reviewView = 'review.view';
  static const reviewModerate = 'review.moderate';
  static const reviewDelete = 'review.delete';

  static const userView = 'user.view';
  static const userEdit = 'user.edit';
  static const userSuspend = 'user.suspend';
  static const userDelete = 'user.delete';

  static const staffView = 'staff.view';
  static const staffManage = 'staff.manage';
  static const roleManage = 'role.manage';

  static const categoryManage = 'category.manage';
  static const locationManage = 'location.manage';

  static const subscriptionView = 'subscription.view';
  static const subscriptionManage = 'subscription.manage';

  static const notificationSend = 'notification.send';
  static const analyticsView = 'analytics.view';
  static const auditView = 'audit.view';
  static const settingsManage = 'settings.manage';
  static const appConfigManage = 'app_config.manage';
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.email = '',
    this.isSuperuser = false,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final bool isSuperuser;

  /// الحرفان الأولان للصورة الرمزية.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters2;
    return '${parts[0][0]}${parts[1][0]}';
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        fullName: json['full_name'] as String? ??
            json['username'] as String? ??
            'مستخدم',
        email: json['email'] as String? ?? '',
        isSuperuser: json['is_superuser'] as bool? ?? false,
      );
}

extension on String {
  String get characters2 => length >= 2 ? substring(0, 2) : this;
}

class AdminRole {
  const AdminRole({required this.slug, required this.name});

  final String slug;
  final String name;

  factory AdminRole.fromJson(Map<String, dynamic> json) => AdminRole(
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? 'بلا دور',
      );
}

class ScopedGovernorate {
  const ScopedGovernorate({required this.id, required this.name});

  final int id;
  final String name;

  factory ScopedGovernorate.fromJson(Map<String, dynamic> json) =>
      ScopedGovernorate(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );
}

/// نتيجة `GET /api/v2/admin/session/`.
///
/// هذا الكائن هو ما يحدد شكل التطبيق: القائمة الجانبية والأزرار تُبنى
/// من [permissions]، فلا يرى الموظف زرًا يفشل بـ403 عند الضغط عليه.
class AdminSession {
  const AdminSession({
    required this.user,
    required this.role,
    required this.permissions,
    required this.isGlobalScope,
    required this.governorates,
  });

  final AdminUser user;
  final AdminRole role;
  final Set<String> permissions;
  final bool isGlobalScope;
  final List<ScopedGovernorate> governorates;

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> codes) => codes.any(permissions.contains);

  bool canAll(Iterable<String> codes) => codes.every(permissions.contains);

  /// وصف النطاق للعرض في الترويسة.
  String get scopeLabel {
    if (isGlobalScope) return 'كل المحافظات';
    if (governorates.isEmpty) return 'بلا نطاق';
    if (governorates.length <= 2) {
      return governorates.map((g) => g.name).join(' · ');
    }
    return '${governorates.first.name} +${governorates.length - 1}';
  }

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'] as Map<String, dynamic>? ?? const {};
    final govs = scope['governorates'];

    return AdminSession(
      user: AdminUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
      role: AdminRole.fromJson(
        json['role'] as Map<String, dynamic>? ?? const {},
      ),
      permissions: {
        ...(json['permissions'] as List? ?? const []).whereType<String>(),
      },
      isGlobalScope: scope['is_global'] as bool? ?? true,
      governorates: (govs is List ? govs : const [])
          .whereType<Map<String, dynamic>>()
          .map(ScopedGovernorate.fromJson)
          .toList(growable: false),
    );
  }
}
