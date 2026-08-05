import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  ApiFailure? _failure;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(
            username: _username.text.trim(),
            password: _password.text,
          );
    } catch (error) {
      if (mounted) setState(() => _failure = ApiFailure.from(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reason = switch (ref.watch(sessionProvider)) {
      SessionSignedOut(:final reason?) => reason,
      _ => null,
    };

    return Scaffold(
      backgroundColor: Shop.sign,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نشاطي',
                      style: text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    const Text(
                      'دليل أي خدمة — إدارة محلك أو خدمتك',
                      style: TextStyle(
                        color: Color(0xFF9DB5AB),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Shop.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('ادخل على حسابك', style: text.headlineSmall),
                          const SizedBox(height: Gap.lg),
                          if (reason != null) ...[
                            _Notice(reason, tone: Shop.inkSoft),
                            const SizedBox(height: Gap.md),
                          ],
                          if (_failure != null) ...[
                            _Notice(_failure!.message, tone: Shop.clay),
                            const SizedBox(height: Gap.md),
                          ],
                          TextFormField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'اكتب اسم المستخدم'
                                : null,
                          ),
                          const SizedBox(height: Gap.md),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'إظهار' : 'إخفاء',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: Shop.inkFaint,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'اكتب كلمة المرور'
                                : null,
                          ),
                          const SizedBox(height: Gap.lg),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('دخول'),
                          ),
                          const SizedBox(height: Gap.lg),
                          const Divider(),
                          const SizedBox(height: Gap.md),
                          Text(
                            'التطبيق ده لأصحاب المحلات ومقدّمي الخدمات. '
                            'لو بتدوّر على محل أو خدمة، استعمل تطبيق الدليل.',
                            style: text.bodySmall,
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
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: tone, height: 1.7),
      ),
    );
  }
}
