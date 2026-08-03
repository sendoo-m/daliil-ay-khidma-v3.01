import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// سجل نشاط كما تعرضه القائمة.
class BusinessRecord {
  const BusinessRecord({
    required this.id,
    required this.name,
    required this.owner,
    required this.category,
    required this.governorate,
    required this.isVerified,
    required this.isFeatured,
    required this.isActive,
    required this.views,
  });

  final int id;
  final String name;
  final String owner;
  final String category;
  final String governorate;
  final bool isVerified;
  final bool isFeatured;
  final bool isActive;
  final int views;

  RecordStamp get stamp {
    if (!isActive) return RecordStamp.suspended;
    if (isFeatured) return RecordStamp.featured;
    if (isVerified) return RecordStamp.verified;
    return RecordStamp.pending;
  }

  factory BusinessRecord.fromJson(Map<String, dynamic> json) => BusinessRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name_ar'] as String? ?? json['name_en'] as String? ?? '—',
        owner: json['owner_name'] as String? ?? '—',
        category: json['category_name'] as String? ?? '—',
        governorate: json['governorate_name'] as String? ?? '—',
        isVerified: json['is_verified'] as bool? ?? false,
        isFeatured: json['is_featured'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        views: (json['view_count'] as num?)?.toInt() ?? 0,
      );
}

/// معايير التصفية الحالية.
class BusinessFilter {
  const BusinessFilter({this.search = '', this.verified, this.page = 1});

  final String search;
  final bool? verified;
  final int page;

  BusinessFilter copyWith({
    String? search,
    bool? verified,
    bool clearVerified = false,
    int? page,
  }) =>
      BusinessFilter(
        search: search ?? this.search,
        verified: clearVerified ? null : (verified ?? this.verified),
        page: page ?? this.page,
      );

  Map<String, dynamic> toQuery() => {
        if (search.isNotEmpty) 'search': search,
        if (verified != null) 'is_verified': verified,
        'page': page,
      };
}

final businessFilterProvider =
    StateProvider.autoDispose<BusinessFilter>((ref) => const BusinessFilter());

final businessListProvider =
    FutureProvider.autoDispose<Paginated<BusinessRecord>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(businessFilterProvider);
  return api.getPage(
    'admin/businesses/',
    BusinessRecord.fromJson,
    query: filter.toQuery(),
  );
});

class BusinessesPage extends ConsumerStatefulWidget {
  const BusinessesPage({super.key});

  @override
  ConsumerState<BusinessesPage> createState() => _BusinessesPageState();
}

class _BusinessesPageState extends ConsumerState<BusinessesPage> {
  final _search = TextEditingController();
  final _selected = <int>{};
  bool _working = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(BusinessFilter Function(BusinessFilter) update) {
    _selected.clear();
    ref.read(businessFilterProvider.notifier).update(update);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _working = true);
    try {
      await action();
      ref.invalidate(businessListProvider);
      if (mounted) _toast(done);
    } on ApiFailure catch (failure) {
      if (mounted) _toast(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? DalilColors.stamp : DalilColors.ink,
      ),
    );
  }

  Future<void> _verify(BusinessRecord record) => _run(
        () => ref
            .read(apiClientProvider)
            .post('admin/businesses/${record.id}/verify/'),
        'تم توثيق ${record.name}',
      );

  Future<void> _toggleFeatured(BusinessRecord record) => _run(
        () => ref
            .read(apiClientProvider)
            .post('admin/businesses/${record.id}/toggle-featured/'),
        record.isFeatured ? 'أُلغي التمييز' : 'تم التمييز',
      );

  Future<void> _bulkVerify() async {
    final ids = _selected.toList();
    await _run(
      () => ref.read(apiClientProvider).post(
        'admin/businesses/bulk-update/',
        body: {'ids': ids, 'field': 'is_verified', 'value': true},
      ),
      'تم توثيق ${ids.length} نشاط',
    );
    _selected.clear();
  }

  Future<void> _suspend(BusinessRecord record) async {
    final reason = await _askReason(record.name);
    if (reason == null) return;
    await _run(
      () => ref.read(apiClientProvider).post(
        'admin/businesses/${record.id}/suspend/',
        body: {'reason': reason},
      ),
      'تم تعليق ${record.name}',
    );
  }

  /// التعليق يحتاج سببًا — الخادم يرفض بدونه، والسبب يُحفظ في السجل.
  Future<String?> _askReason(String name) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DalilColors.surface,
        title: Text('تعليق $name', style: Theme.of(context).textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السبب يُحفظ في سجل العمليات باسمك.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: DalilSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'سبب التعليق'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DalilColors.stamp),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('علّق النشاط'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final filter = ref.watch(businessFilterProvider);
    final list = ref.watch(businessListProvider);

    return Column(
      children: [
        _Toolbar(
          controller: _search,
          filter: filter,
          onSearch: (v) => _setFilter((f) => f.copyWith(search: v, page: 1)),
          onFilter: (v) => _setFilter(
            (f) => v == null
                ? f.copyWith(clearVerified: true, page: 1)
                : f.copyWith(verified: v, page: 1),
          ),
        ),

        if (_selected.isNotEmpty && session.can(Perm.businessVerify))
          _BulkBar(
            count: _selected.length,
            busy: _working,
            onVerify: _bulkVerify,
            onClear: () => setState(_selected.clear),
          ),

        Expanded(
          child: list.when(
            loading: () => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => ErrorState(
              failure: ApiFailure.from(e),
              onRetry: () => ref.invalidate(businessListProvider),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyState(
                  title: filter.search.isEmpty
                      ? 'لا توجد أنشطة في نطاقك'
                      : 'لا نتائج لـ"${filter.search}"',
                  hint: filter.search.isEmpty
                      ? null
                      : 'جرّب اسمًا آخر أو امسح البحث.',
                );
              }

              return ListView.builder(
                itemCount: page.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == page.items.length) {
                    return _Footer(
                      shown: page.items.length,
                      total: page.total,
                      hasMore: page.hasMore,
                      onMore: () =>
                          _setFilter((f) => f.copyWith(page: f.page + 1)),
                    );
                  }
                  return _row(page.items[index], session);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(BusinessRecord record, AdminSession session) {
    final selectable = session.can(Perm.businessVerify) && !record.isVerified;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectable)
          Padding(
            padding: const EdgeInsets.only(top: 14, right: 4),
            child: Checkbox(
              value: _selected.contains(record.id),
              onChanged: (checked) => setState(() {
                checked == true
                    ? _selected.add(record.id)
                    : _selected.remove(record.id);
              }),
            ),
          ),
        Expanded(
          child: RegistryEntry(
            serial: record.id.toString().padLeft(5, '0'),
            title: record.name,
            subtitle: '${record.category} · ${record.governorate}',
            stamp: record.stamp,
            meta: [
              ('المالك', record.owner),
              ('مشاهدات', '${record.views}'),
            ],
            actions: [
              if (!record.isVerified)
                Allowed(
                  session: session,
                  permission: Perm.businessVerify,
                  child: OutlinedButton(
                    onPressed: _working ? null : () => _verify(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DalilColors.seal,
                      side: const BorderSide(color: DalilColors.seal),
                    ),
                    child: const Text('وثّق'),
                  ),
                ),
              Allowed(
                session: session,
                permission: Perm.businessFeature,
                child: OutlinedButton(
                  onPressed: _working ? null : () => _toggleFeatured(record),
                  child: Text(record.isFeatured ? 'ألغِ التمييز' : 'ميّز'),
                ),
              ),
              if (record.isActive)
                Allowed(
                  session: session,
                  permission: Perm.businessSuspend,
                  child: OutlinedButton(
                    onPressed: _working ? null : () => _suspend(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DalilColors.stamp,
                      side: const BorderSide(color: DalilColors.rule),
                    ),
                    child: const Text('علّق'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController controller;
  final BusinessFilter filter;
  final void Function(String) onSearch;
  final void Function(bool?) onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DalilSpacing.md),
      decoration: const BoxDecoration(
        color: DalilColors.surface,
        border: Border(bottom: BorderSide(color: DalilColors.rule)),
      ),
      child: Wrap(
        spacing: DalilSpacing.sm,
        runSpacing: DalilSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller,
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: 'ابحث باسم النشاط أو المالك',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          controller.clear();
                          onSearch('');
                        },
                      ),
              ),
            ),
          ),
          _Chip(
            label: 'الكل',
            active: filter.verified == null,
            onTap: () => onFilter(null),
          ),
          _Chip(
            label: 'بانتظار التوثيق',
            active: filter.verified == false,
            tone: DalilColors.stamp,
            onTap: () => onFilter(false),
          ),
          _Chip(
            label: 'موثّق',
            active: filter.verified == true,
            tone: DalilColors.seal,
            onTap: () => onFilter(true),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.tone = DalilColors.ink,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DalilRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tone : Colors.transparent,
          border: Border.all(color: active ? tone : DalilColors.rule),
          borderRadius: BorderRadius.circular(DalilRadii.control),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.white : DalilColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.busy,
    required this.onVerify,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final VoidCallback onVerify;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DalilSpacing.md,
        vertical: DalilSpacing.sm,
      ),
      color: DalilColors.ink,
      child: Row(
        children: [
          Text(
            'محدَّد: $count',
            style: AdminTheme.mono(size: 13, color: Colors.white),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            child: const Text(
              'إلغاء التحديد',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: DalilSpacing.sm),
          FilledButton(
            onPressed: busy ? null : onVerify,
            style: FilledButton.styleFrom(
              backgroundColor: DalilColors.seal,
              minimumSize: const Size(0, 36),
            ),
            child: Text('وثّق الكل ($count)'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.onMore,
  });

  final int shown;
  final int total;
  final bool hasMore;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DalilSpacing.lg),
      child: Column(
        children: [
          Text('$shown من $total', style: AdminTheme.mono(size: 12)),
          if (hasMore) ...[
            const SizedBox(height: DalilSpacing.md),
            OutlinedButton(onPressed: onMore, child: const Text('حمّل المزيد')),
          ],
        ],
      ),
    );
  }
}
