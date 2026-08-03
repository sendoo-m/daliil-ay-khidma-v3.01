import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import 'search_page.dart';

class DirectoryHubPage extends StatelessWidget {
  const DirectoryHubPage({
    required this.categories,
    required this.governorates,
    super.key,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> governorates;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('استكشف الدليل'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.grid_view_rounded), text: 'الأقسام'),
                Tab(icon: Icon(Icons.location_city_rounded), text: 'المحافظات'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _DirectoryGrid(items: categories, type: _DirectoryType.category),
              _DirectoryGrid(
                items: governorates,
                type: _DirectoryType.governorate,
              ),
            ],
          ),
        ),
      );
}

enum _DirectoryType { category, governorate }

class _DirectoryGrid extends StatelessWidget {
  const _DirectoryGrid({required this.items, required this.type});

  final List<Map<String, dynamic>> items;
  final _DirectoryType type;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد بيانات متاحة حاليًا'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 150,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final name = '${item['name_ar'] ?? item['name'] ?? ''}';
        final id = item['id'] as int?;
        final iconUrl = '${item['icon'] ?? ''}';
        final isCategory = type == _DirectoryType.category;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  initialQuery: name,
                  initialCategoryId: isCategory ? id : null,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: index.isEven
                      ? const [AppColors.primarySoft, Colors.white]
                      : const [AppColors.secondarySoft, Colors.white],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .14),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: isCategory && iconUrl.startsWith('http')
                        ? Image.network(
                            iconUrl,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.grid_view_rounded,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            isCategory
                                ? Icons.grid_view_rounded
                                : Icons.location_city_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
