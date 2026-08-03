import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/shell.dart';
import 'src/app/theme.dart';
import 'src/features/auth/login_page.dart';
import 'src/features/businesses/businesses_page.dart';
import 'src/features/dashboard/dashboard_page.dart';
import 'src/shared/providers.dart';

void main() {
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دليل أي خدمة — الإدارة',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.build(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _Gate(),
    );
  }
}

/// بوابة الجلسة: تقرر بين شاشة الدخول واللوحة.
class _Gate extends ConsumerStatefulWidget {
  const _Gate();

  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> {
  String _route = '/';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);

    return switch (state) {
      SessionLoading() => const Scaffold(
          body: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      SessionSignedOut() => const LoginPage(),
      SessionActive() => AdminShell(
          currentRoute: _route,
          onNavigate: (r) => setState(() => _route = r),
          child: _pageFor(_route),
        ),
    };
  }

  Widget _pageFor(String route) => switch (route) {
        '/' => const DashboardPage(),
        '/businesses' => const BusinessesPage(),
        _ => _Placeholder(route: route),
      };
}

/// شاشة قيد الإنشاء — تقول بوضوح ما الذي سيأتي، لا "قريبًا".
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final label = kDestinations
        .firstWhere(
          (d) => d.route == route,
          orElse: () => kDestinations.first,
        )
        .label;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'الشاشة قيد البناء. الـAPI جاهز.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
