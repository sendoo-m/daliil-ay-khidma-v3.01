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
  bool _rememberMe = false;

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 50,
                maxWidth: 560,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthBrand(),
                    const SizedBox(height: 28),
                    _AuthCard(
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('أهلاً بك 👋', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text('سجّل دخولك لاكتشاف أفضل الخدمات حولك.', style: TextStyle(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _username,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(labelText: 'البريد الإلكتروني أو اسم المستخدم', prefixIcon: Icon(Icons.person_outline_rounded)),
                                validator: (value) => value == null || value.trim().isEmpty ? 'اكتب البريد أو اسم المستخدم' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                    icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'اكتب كلمة المرور' : null,
                              ),
                              Row(
                                children: [
                                  Checkbox(value: _rememberMe, onChanged: auth.isLoading ? null : (value) => setState(() => _rememberMe = value ?? false)),
                                  const Text('تذكرني'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: auth.isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                                    child: const Text('نسيت كلمة المرور؟'),
                                  ),
                                ],
                              ),
                              if (auth.hasError) ...[
                                _ErrorBanner(message: ApiFailure.message(auth.error!)),
                                const SizedBox(height: 14),
                              ],
                              FilledButton(
                                onPressed: auth.isLoading ? null : _submit,
                                child: auth.isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('تسجيل الدخول'), SizedBox(width: 8), Icon(Icons.arrow_back_rounded)]),
                              ),
                              const SizedBox(height: 18),
                              Row(children: [Expanded(child: Divider(color: scheme.outlineVariant)), const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو')), Expanded(child: Divider(color: scheme.outlineVariant))]),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(onPressed: auth.isLoading ? null : () {}, icon: const Icon(Icons.g_mobiledata_rounded, size: 30), label: const Text('تسجيل الدخول باستخدام Google')),
                              const SizedBox(height: 10),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('مش عندك حساب؟'), TextButton(onPressed: auth.isLoading ? null : () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('سجّل دلوقتي'))]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('باستخدامك للتطبيق فأنت توافق على شروط الاستخدام وسياسة الخصوصية.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(_username.text.trim(), _password.text);
    if (ok && mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const DalilLogo(size: 92),
          const SizedBox(height: 14),
          Text('دليل أي خدمة', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('اكتشف أفضل الخدمات حولك', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7))),
        child: Padding(padding: const EdgeInsets.all(22), child: child),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer), const SizedBox(width: 10), Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer)))]),
    );
  }
}
