import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../features/auth/presentation/reset_password_page.dart';
import 'app_theme.dart';
import 'main_shell.dart';
import 'providers.dart';

class DalilApp extends ConsumerStatefulWidget {
  const DalilApp({super.key});

  @override
  ConsumerState<DalilApp> createState() => _DalilAppState();
}

class _DalilAppState extends ConsumerState<DalilApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _links = AppLinks().uriLinkStream.listen(_openResetLink);
  }

  void _openResetLink(Uri uri) {
    if (uri.scheme != 'daliil' || uri.host != 'reset-password') return;
    final uid = uri.queryParameters['uid'];
    final token = uri.queryParameters['token'];
    if (uid == null || token == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordPage(uid: uid, token: token),
      ),
    );
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (next.valueOrNull == true) {
        ref.read(pushServiceProvider).initialize().catchError((_) {});
      }
    });
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: auth.when(
        loading: () => const _SplashScreen(),
        error: (_, __) => const MainShell(),
        data: (_) => const MainShell(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'دليل أي خدمة',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 20),
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
}
