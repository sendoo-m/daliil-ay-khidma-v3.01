import 'package:dalil_core/dalil_core.dart' hide ApiFailure;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import 'login_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _hidePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _username, _email, _phone, _password, _passwordConfirm]) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const _AuthBrand(),
                  const SizedBox(height: 26),
                  _AuthCard(
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('أنشئ حسابك', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text('احفظ مفضلاتك وتابع العروض والخدمات التي تهمك.', style: TextStyle(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 24),
                            LayoutBuilder(builder: (context, constraints) {
                              final fields = [
                                _field(_firstName, 'الاسم الأول', Icons.badge_outlined, required: true, action: TextInputAction.next),
                                _field(_lastName, 'اسم العائلة', null, required: true, action: TextInputAction.next),
                              ];
                              return constraints.maxWidth < 430 ? Column(children: fields) : Row(children: [Expanded(child: fields[0]), const SizedBox(width: 12), Expanded(child: fields[1])]);
                            }),
                            _field(_username, 'اسم المستخدم', Icons.person_outline_rounded, required: true, action: TextInputAction.next, validator: (value) { final v = value?.trim() ?? ''; if (v.isEmpty) return 'اسم المستخدم مطلوب'; if (v.length < 3) return 'اسم المستخدم 3 أحرف على الأقل'; return null; }, autofill: const [AutofillHints.newUsername]),
                            _field(_email, 'البريد الإلكتروني', Icons.email_outlined, required: true, action: TextInputAction.next, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], validator: (value) { final v = value?.trim() ?? ''; if (v.isEmpty) return 'البريد الإلكتروني مطلوب'; if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'اكتب بريدًا إلكترونيًا صحيحًا'; return null; }),
                            _field(_phone, 'رقم الهاتف (اختياري)', Icons.phone_outlined, action: TextInputAction.next, keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
                            _passwordField(_password, 'كلمة المرور', TextInputAction.next, (value) { if (value == null || value.isEmpty) return 'كلمة المرور مطلوبة'; if (value.length < 8) return 'استخدم 8 أحرف على الأقل'; return null; }),
                            _passwordField(_passwordConfirm, 'تأكيد كلمة المرور', TextInputAction.done, (value) => value != _password.text ? 'كلمتا المرور غير متطابقتين' : null, onSubmitted: (_) => _submit()),
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(16)),
                              child: CheckboxListTile(
                                value: _acceptedTerms,
                                onChanged: auth.isLoading ? null : (value) => setState(() => _acceptedTerms = value ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                                title: const Text('أوافق على شروط الاستخدام وسياسة الخصوصية', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                            if (auth.hasError) ...[_ErrorBanner(message: ApiFailure.message(auth.error!)), const SizedBox(height: 14)],
                            FilledButton(
                              onPressed: auth.isLoading ? null : _submit,
                              child: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('إنشاء الحساب'), SizedBox(width: 8), Icon(Icons.arrow_back_rounded)]),
                            ),
                            const SizedBox(height: 12),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('لديك حساب بالفعل؟'), TextButton(onPressed: auth.isLoading ? null : () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())), child: const Text('سجّل الدخول'))]),
                          ],
                        ),
                      ),
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

  Widget _field(TextEditingController controller, String label, IconData? icon, {bool required = false, TextInputAction? action, TextInputType? keyboard, Iterable<String>? autofill, String? Function(String?)? validator}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          textInputAction: action,
          keyboardType: keyboard,
          autofillHints: autofill,
          decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
          validator: validator ?? (required ? (value) => value == null || value.trim().isEmpty ? '$label مطلوب' : null : null),
        ),
      );

  Widget _passwordField(TextEditingController controller, String label, TextInputAction action, String? Function(String?) validator, {ValueChanged<String>? onSubmitted}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          obscureText: _hidePassword,
          textInputAction: action,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: _hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور', onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
          validator: validator,
        ),
      );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وافق على الشروط وسياسة الخصوصية أولًا')));
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).register(username: _username.text.trim(), email: _email.text.trim(), password: _password.text, firstName: _firstName.text.trim(), lastName: _lastName.text.trim(), phone: _phone.text.trim());
    if (ok && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) => Column(children: [const DalilLogo(size: 86), const SizedBox(height: 14), Text('دليل أي خدمة', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('اكتشف أفضل الخدمات حولك', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]);
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7))), child: Padding(padding: const EdgeInsets.all(22), child: child));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer), const SizedBox(width: 10), Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer)))]));
  }
}
