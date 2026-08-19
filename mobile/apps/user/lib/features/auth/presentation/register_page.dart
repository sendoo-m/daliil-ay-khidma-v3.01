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
    for (final controller in [
      _firstName,
      _lastName,
      _username,
      _email,
      _phone,
      _password,
      _passwordConfirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
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
                  stops: const [0, .25, .48, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).maybePop(),
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
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [scheme.primary, scheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(alpha: .2),
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_add_alt_1_rounded,
                                color: scheme.onPrimary,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'أنشئ حسابك',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'احفظ مفضلاتك وتابع العروض والخدمات التي تهمك.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.6,
                                  ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(alpha: .7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .06),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'بيانات الحساب',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'أكمل البيانات التالية، ويمكنك تعديل ملفك لاحقًا.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 22),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (constraints.maxWidth < 420) {
                                            return Column(
                                              children: [
                                                _field(
                                                  _firstName,
                                                  'الاسم الأول',
                                                  icon: Icons.badge_outlined,
                                                  textInputAction: TextInputAction.next,
                                                ),
                                                _field(
                                                  _lastName,
                                                  'اسم العائلة',
                                                  textInputAction: TextInputAction.next,
                                                ),
                                              ],
                                            );
                                          }
                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _field(
                                                  _firstName,
                                                  'الاسم الأول',
                                                  icon: Icons.badge_outlined,
                                                  textInputAction: TextInputAction.next,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _field(
                                                  _lastName,
                                                  'اسم العائلة',
                                                  textInputAction: TextInputAction.next,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      _field(
                                        _username,
                                        'اسم المستخدم',
                                        icon: Icons.person_outline_rounded,
                                        required: true,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [AutofillHints.newUsername],
                                        validator: (value) {
                                          final username = value?.trim() ?? '';
                                          if (username.isEmpty) {
                                            return 'اسم المستخدم مطلوب';
                                          }
                                          if (username.length < 3) {
                                            return 'اسم المستخدم 3 أحرف على الأقل';
                                          }
                                          return null;
                                        },
                                      ),
                                      _field(
                                        _email,
                                        'البريد الإلكتروني',
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [AutofillHints.email],
                                        validator: (value) {
                                          final email = value?.trim() ?? '';
                                          if (email.isEmpty) {
                                            return 'البريد الإلكتروني مطلوب';
                                          }
                                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                              .hasMatch(email)) {
                                            return 'اكتب بريدًا إلكترونيًا صحيحًا';
                                          }
                                          return null;
                                        },
                                      ),
                                      _field(
                                        _phone,
                                        'رقم الهاتف (اختياري)',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.telephoneNumber,
                                        ],
                                      ),
                                      _passwordField(
                                        controller: _password,
                                        label: 'كلمة المرور',
                                        action: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'كلمة المرور مطلوبة';
                                          }
                                          if (value.length < 8) {
                                            return 'استخدم 8 أحرف على الأقل';
                                          }
                                          return null;
                                        },
                                      ),
                                      _passwordField(
                                        controller: _passwordConfirm,
                                        label: 'تأكيد كلمة المرور',
                                        action: TextInputAction.done,
                                        onSubmitted: (_) => _submit(),
                                        validator: (value) => value != _password.text
                                            ? 'كلمتا المرور غير متطابقتين'
                                            : null,
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer
                                              .withValues(alpha: .35),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: CheckboxListTile(
                                          contentPadding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                            8,
                                            0,
                                            10,
                                            0,
                                          ),
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          value: _acceptedTerms,
                                          onChanged: auth.isLoading
                                              ? null
                                              : (value) => setState(
                                                    () => _acceptedTerms =
                                                        value ?? false,
                                                  ),
                                          title: const Text(
                                            'أوافق على شروط الاستخدام وسياسة الخصوصية',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      if (auth.hasError) ...[
                                        _RegisterError(
                                          message: ApiFailure.message(auth.error!),
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      FilledButton(
                                        onPressed: auth.isLoading ? null : _submit,
                                        child: auth.isLoading
                                            ? const Row(
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
                                                  Text('جارٍ إنشاء الحساب...'),
                                                ],
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text('إنشاء الحساب'),
                                                  SizedBox(width: 8),
                                                  Icon(Icons.arrow_back_rounded),
                                                ],
                                              ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('لديك حساب بالفعل؟'),
                                          TextButton(
                                            onPressed: auth.isLoading
                                                ? null
                                                : () => Navigator.of(context)
                                                    .pushReplacement(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            const LoginPage(),
                                                      ),
                                                    ),
                                            child: const Text('سجّل الدخول'),
                                          ),
                                        ],
                                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
          validator: validator ??
              (required
                  ? (value) => value == null || value.trim().isEmpty
                      ? '$label مطلوب'
                      : null
                  : null),
        ),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required TextInputAction action,
    required String? Function(String?) validator,
    ValueChanged<String>? onSubmitted,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          obscureText: _hidePassword,
          textInputAction: action,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
              onPressed: () =>
                  setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: validator,
        ),
      );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وافق على الشروط وسياسة الخصوصية أولًا')),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).register(
          username: _username.text,
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
        );
    if (ok && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _RegisterError extends StatelessWidget {
  const _RegisterError({required this.message});
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
