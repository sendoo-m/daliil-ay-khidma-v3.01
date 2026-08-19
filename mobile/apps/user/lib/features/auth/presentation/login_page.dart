import 'package:dalil_core/dalil_core.dart' hide ApiFailure;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          children: [
                            const _BrandHero(
                              title: 'أهلاً بك',
                              subtitle:
                                  'اكتشف الأماكن والخدمات والعروض القريبة منك.',
                            ),
                            const SizedBox(height: 24),
                            _AuthCard(
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'تسجيل الدخول',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'أدخل بيانات حسابك للمتابعة.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 22),
                                      TextFormField(
                                        controller: _username,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'اسم المستخدم',
                                          hintText: 'اكتب اسم المستخدم',
                                          prefixIcon:
                                              Icon(Icons.person_outline_rounded),
                                        ),
                                        validator: (value) =>
                                            value == null || value.trim().isEmpty
                                                ? 'اكتب اسم المستخدم'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _password,
                                        obscureText: _hidePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onFieldSubmitted: (_) => _submit(),
                                        decoration: InputDecoration(
                                          labelText: 'كلمة المرور',
                                          hintText: '••••••••',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: _hidePassword
                                                ? 'إظهار كلمة المرور'
                                                : 'إخفاء كلمة المرور',
                                            onPressed: () => setState(
                                              () => _hidePassword =
                                                  !_hidePassword,
                                            ),
                                            icon: Icon(
                                              _hidePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                            ),
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                                ? 'اكتب كلمة المرور'
                                                : null,
                                      ),
                                      const SizedBox(height: 2),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: TextButton(
                                          onPressed: auth.isLoading
                                              ? null
                                              : () => Navigator.of(context).push(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          const ForgotPasswordPage(),
                                                    ),
                                                  ),
                                          child: const Text(
                                            'نسيت كلمة المرور؟',
                                          ),
                                        ),
                                      ),
                                      if (auth.hasError) ...[
                                        _ErrorBanner(
                                          message: ApiFailure.message(
                                            auth.error!,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      FilledButton(
                                        onPressed:
                                            auth.isLoading ? null : _submit,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          child: auth.isLoading
                                              ? const Row(
                                                  key: ValueKey('loading'),
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    SizedBox.square(
                                                      dimension: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text('جارٍ الدخول...'),
                                                  ],
                                                )
                                              : const Row(
                                                  key: ValueKey('ready'),
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text('دخول'),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                      Icons.arrow_back_rounded,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: scheme.outlineVariant,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              'أو',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: scheme.outlineVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : () => Navigator.of(context)
                                                .pushReplacement(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        const RegisterPage(),
                                                  ),
                                                ),
                                        child: const Text('إنشاء حساب جديد'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'باستخدامك للتطبيق فأنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(_username.text, _password.text);
    if (ok && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primary.withValues(alpha: .14),
            scheme.secondary.withValues(alpha: .08),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0, .28, .52, 1],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'رجوع',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            const Spacer(),
            Text(
              'دليل أي خدمة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      );
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const DalilLogo(size: 92),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
