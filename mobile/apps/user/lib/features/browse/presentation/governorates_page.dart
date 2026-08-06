import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../data/browse_repository.dart';
import 'browse_results_page.dart';
import 'directories_page.dart';

final governoratesProvider =
    FutureProvider.autoDispose<List<BrowsePlace>>((ref) async {
  return ref.watch(browseRepositoryProvider).governorates();
});

final governorateProvider = FutureProvider.autoDispose
    .family<GovernorateOverview, int>((ref, id) async {
  return ref.watch(browseRepositoryProvider).governorate(id);
});

/// قائمة المحافظات — مرتّبة بالأكثر امتلاءً لا أبجديًا.
///
/// المستخدم بيدوّر على حاجة يلاقيها. محافظة فاضية في أول القائمة
/// بتعلّمه إن التطبيق فاضي، وده انطباع بيفضل.
class GovernoratesPage extends ConsumerWidget {
  const GovernoratesPage({super.key, this.showAppBar = true});

  /// يُخفى داخل تبويب.
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final governorates = ref.watch(governoratesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              title: const Text('المحافظات'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: governorates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(governoratesProvider),
            child: const Text('حاول تاني'),
          ),
        ),
        data: (items) {
          final live = items.where((g) => g.count > 0).toList();
          final empty = items.where((g) => g.count == 0).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(governoratesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                for (final g in live) _GovernorateTile(place: g),
                if (empty.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(6, 18, 6, 10),
                    child: Text(
                      'محافظات لسه من غير بيانات',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  for (final g in empty) _GovernorateTile(place: g),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GovernorateTile extends StatelessWidget {
  const _GovernorateTile({required this.place});

  final BrowsePlace place;

  @override
  Widget build(BuildContext context) {
    final empty = place.count == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: empty ? 0.5 : 1,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: empty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GovernoratePage(id: place.id),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    empty ? 'لسه فاضية' : '${place.count}',
                    style: TextStyle(
                      fontSize: empty ? 12 : 14,
                      fontWeight: FontWeight.w900,
                      color: empty
                          ? const Color(0xFF94A3B8)
                          : AppColors.primary,
                    ),
                  ),
                  if (!empty)
                    const Icon(
                      Icons.chevron_left,
                      color: Color(0xFFCBD5E1),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شاشة محافظة واحدة: أدلتها ومدنها وأحياؤها.
class GovernoratePage extends ConsumerWidget {
  const GovernoratePage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(governorateProvider(id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(overview.valueOrNull?.name ?? 'المحافظة'),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(governorateProvider(id)),
            child: const Text('حاول تاني'),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(governorateProvider(id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SearchEverything(data: data),
              const SizedBox(height: 24),

              const _Heading('تصفّح حسب الدليل'),
              for (final d in data.directories)
                _DirectoryRow(directory: d, governorateId: data.id),

              if (data.cities.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _Heading('المدن'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in data.cities)
                      _PlaceChip(
                        label: c.name,
                        count: c.count,
                        onTap: () => _open(
                          context,
                          title: c.name,
                          subtitle: data.name,
                          governorateId: data.id,
                          cityId: c.id,
                          districts: data.districtsIn(c.id),
                        ),
                      ),
                  ],
                ),
              ],

              if (data.districts.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _Heading('الأحياء الأكثر امتلاءً'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in data.districts.take(20))
                      _PlaceChip(
                        label: d.name,
                        count: d.count,
                        onTap: () => _open(
                          context,
                          title: d.name,
                          subtitle: data.name,
                          governorateId: data.id,
                          districtId: d.id,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _open(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int governorateId,
    int? cityId,
    int? districtId,
    List<BrowsePlace> districts = const [],
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowseResultsPage(
          title: title,
          subtitle: subtitle,
          governorateId: governorateId,
          cityId: cityId,
          districtId: districtId,
          districts: [
            for (final d in districts)
              (id: d.id, name: d.name, count: d.count, cityId: d.cityId),
          ],
        ),
      ),
    );
  }
}

/// بحث في المحافظة كلها — أعلى الشاشة لأنه أسرع طريق لمن يعرف ما يريد.
class _SearchEverything extends StatelessWidget {
  const _SearchEverything({required this.data});

  final GovernorateOverview data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BrowseResultsPage(
              title: data.name,
              subtitle: '${data.total} نشاط',
              governorateId: data.id,
              cities: [
                for (final c in data.cities)
                  (id: c.id, name: c.name, count: c.count),
              ],
              districts: [
                for (final d in data.districts)
                  (id: d.id, name: d.name, count: d.count, cityId: d.cityId),
              ],
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ابحث في ${data.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      '${data.total} نشاط · فلتر بالمدينة والحي',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({required this.directory, required this.governorateId});

  final Directory directory;
  final int governorateId;

  static const _icons = {
    'shop': Icons.storefront_rounded,
    'craft': Icons.handyman_rounded,
    'public': Icons.local_hospital_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final empty = directory.count == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: empty ? 0.5 : 1,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: empty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BrowseResultsPage(
                          title: directory.name,
                          governorateId: governorateId,
                          businessType: directory.key,
                        ),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Icon(
                    _icons[directory.key] ?? Icons.grid_view_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      directory.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    '${directory.count}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: empty
                          ? const Color(0xFF94A3B8)
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
      );
}
