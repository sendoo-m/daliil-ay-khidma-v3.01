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
      // الموجّه ينقل تلقائيًا عند تغيّر الحالة.
    } catch (error) {
      if (mounted) setState(() => _failure = ApiFailure.from(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: _RegistryPanel()),
                Expanded(
                  flex: 4,
                  child: Container(
                    color: DalilColors.surface,
                    child: Center(child: _form(context)),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(child: Center(child: _form(context))),
    );
  }

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reason = switch (ref.watch(sessionProvider)) {
      SessionSignedOut(:final reason?) => reason,
      _ => null,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DalilSpacing.lg,
          vertical: DalilSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لوحة الإدارة', style: AdminTheme.eyebrow),
              const SizedBox(height: DalilSpacing.sm),
              Text('دخول الموظفين', style: text.displaySmall),
              const SizedBox(height: DalilSpacing.xs),
              Text(
                'ادخل ببيانات حسابك في المنصة.',
                style: text.bodySmall,
              ),
              const SizedBox(height: DalilSpacing.xl),

              if (reason != null) ...[
                _Notice(reason, tone: DalilColors.inkSoft),
                const SizedBox(height: DalilSpacing.md),
              ],
              if (_failure != null) ...[
                _Notice(_failure!.message, tone: DalilColors.stamp),
                const SizedBox(height: DalilSpacing.md),
              ],

              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'اكتب اسم المستخدم'
                    : null,
              ),
              const SizedBox(height: DalilSpacing.md),

              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: DalilColors.inkFaint,
                    ),
                    tooltip: _obscure ? 'إظهار' : 'إخفاء',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'اكتب كلمة المرور' : null,
              ),
              const SizedBox(height: DalilSpacing.lg),

              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('دخول'),
              ),

              const SizedBox(height: DalilSpacing.lg),
              const Divider(),
              const SizedBox(height: DalilSpacing.md),
              Text(
                'الدخول محصور بالموظفين المعيَّنين. لو حسابك عادي، '
                'استعمل تطبيق المستخدم.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// اللوحة اليمنى: هوية المنصة بلغة دفتر القيد.
class _RegistryPanel extends StatelessWidget {
  const _RegistryPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DalilColors.ink,
      padding: const EdgeInsets.all(DalilSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DALIIL AY KHIDMA',
            style: AdminTheme.mono(
              size: 11,
              color: Colors.white.withValues(alpha: 0.45),
              spacing: 3,
            ),
          ),
          const SizedBox(height: DalilSpacing.lg),
          Text(
            'دليل\nأي خدمة',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 44,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: DalilSpacing.lg),
          Container(
            width: 56,
            height: 2,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: DalilSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'سجل المحلات ومقدمي الخدمات. كل قيد هنا يمر على موظف '
              'قبل أن يظهر للناس.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                height: 1.9,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: DalilSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        border: Border(right: BorderSide(color: tone, width: 3)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: tone, height: 1.6),
      ),
    );
  }
}
