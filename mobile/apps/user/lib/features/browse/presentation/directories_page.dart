import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../data/browse_repository.dart';
import 'browse_results_page.dart';

final browseRepositoryProvider = Provider(
  (ref) => BrowseRepository(ref.watch(apiClientProvider).dio),
);

final directoriesProvider =
    FutureProvider.autoDispose<List<Directory>>((ref) async {
  return ref.watch(browseRepositoryProvider).categoriesGrouped();
});

/// شاشة الأقسام.
///
/// الأدلة التلاتة، وكل واحد بأقسامه. الأعداد ظاهرة جنب كل اسم — من
/// غيرها المستخدم بيفتح قسم فاضي ويرجع، وتاني فاضي، وبعدين بيقفل.
///
/// والقسم الفاضي بيظهر باهت ومش قابل للضغط بدل ما يتشال: وجوده بيقول
/// "القسم ده موجود بس لسه فاضي"، وغيابه بيخلّي المستخدم يفتكر إن
/// التطبيق مش بيغطّي النوع ده أصلًا.
class DirectoriesPage extends ConsumerWidget {
  const DirectoriesPage({
    super.key,
    this.showAppBar = true,
    this.initialType,
  });

  /// لو مبعوت، الشاشة بتفتح على دليل واحد.
  final String? initialType;

  /// يُخفى داخل تبويب — وإلا ظهر شريطان فوق بعضهما.
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directories = ref.watch(directoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              title: const Text('الأقسام'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: directories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(directoriesProvider),
        ),
        data: (items) {
          final shown = initialType == null
              ? items
              : items.where((d) => d.key == initialType).toList();

          if (shown.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(directoriesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: shown.length,
              itemBuilder: (context, i) => _DirectoryBlock(directory: shown[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DirectoryBlock extends StatelessWidget {
  const _DirectoryBlock({required this.directory});

  final Directory directory;

  static const _icons = {
    'shop': Icons.storefront_rounded,
    'craft': Icons.handyman_rounded,
    'public': Icons.local_hospital_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final live = directory.categories.where((c) => c.count > 0).toList();
    final empty = directory.categories.where((c) => c.count == 0).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icons[directory.key] ?? Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      directory.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      directory.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _CountPill(count: directory.count),
            ],
          ),
          const SizedBox(height: 14),
          if (live.isEmpty && empty.isEmpty)
            const _NoCategories()
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in live) _CategoryChip(category: c),
                for (final c in empty) _CategoryChip(category: c),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final BrowseCategory category;

  @override
  Widget build(BuildContext context) {
    final empty = category.count == 0;

    return Opacity(
      opacity: empty ? 0.45 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // القسم الفاضي مش قابل للضغط — فتحه بيوصّل لشاشة فاضية.
          onTap: empty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BrowseResultsPage(
                        title: category.name,
                        categoryId: category.id,
                      ),
                    ),
                  ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: empty
                        ? const Color(0xFFF1F5F9)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${category.count}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: empty
                          ? const Color(0xFF94A3B8)
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: count == 0 ? const Color(0xFFF1F5F9) : AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: count == 0 ? const Color(0xFF94A3B8) : AppColors.secondary,
        ),
      ),
    );
  }
}

class _NoCategories extends StatelessWidget {
  const _NoCategories();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'لسه مفيش أقسام في الدليل ده.',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'لسه مفيش أقسام.',
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تعذّر تحميل الأقسام.',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('حاول تاني')),
          ],
        ),
      ),
    );
  }
}
