import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
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
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'أنشئ حسابك',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'احفظ الأماكن المفضلة واحجز العروض وشارك تقييمك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Row(
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
                    ),
                    _field(
                      _username,
                      'اسم المستخدم',
                      icon: Icons.person_outline,
                      required: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final username = value?.trim() ?? '';
                        if (username.isEmpty) return 'اسم المستخدم مطلوب';
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
                        if (email.isEmpty) return 'البريد الإلكتروني مطلوب';
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
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acceptedTerms,
                      onChanged: auth.isLoading
                          ? null
                          : (value) =>
                              setState(() => _acceptedTerms = value ?? false),
                      title: const Text(
                        'أوافق على شروط الاستخدام وسياسة الخصوصية',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    if (auth.hasError) ...[
                      _RegisterError(message: ApiFailure.message(auth.error!)),
                      const SizedBox(height: 14),
                    ],
                    FilledButton.icon(
                      onPressed: auth.isLoading ? null : _submit,
                      icon: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        auth.isLoading ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('لديك حساب بالفعل؟'),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginPage(),
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
        ),
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
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );
}
