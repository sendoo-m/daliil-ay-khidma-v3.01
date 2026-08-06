import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import 'directories_page.dart';
import 'governorates_page.dart';

/// الدليل الكامل — تبويبان: الأقسام والمحافظات.
///
/// يستبدل `DirectoryHubPage` القديمة التي كانت تمرّر اسم المحافظة
/// كنص بحث بدل أن تفلتر بها: الضغط على "القاهرة" كان يبحث عن الكلمة
/// في أسماء المحلات، فتخرج نتائج عشوائية أو لا شيء.
class BrowseHubPage extends StatelessWidget {
  const BrowseHubPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('الدليل الكامل'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'الأقسام'),
              Tab(text: 'المحافظات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _Bare(child: DirectoriesPage(showAppBar: false)),
            _Bare(child: GovernoratesPage(showAppBar: false)),
          ],
        ),
      ),
    );
  }
}

/// الشاشتان تحملان AppBar خاصًا بهما عند فتحهما مستقلتين. داخل التبويب
/// نُخفيه حتى لا يظهر شريطان فوق بعضهما.
class _Bare extends StatelessWidget {
  const _Bare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Theme(
        data: Theme.of(context),
        child: Builder(builder: (_) => child),
      ),
    );
  }
}
