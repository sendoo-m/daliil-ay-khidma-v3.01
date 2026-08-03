import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('استعادة كلمة المرور')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('أدخل بريدك وسنرسل لك رابطًا آمنًا لإعادة التعيين.'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'جارٍ الإرسال…' : 'إرسال الرابط'),
            ),
          ],
        ),
      );

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'البريد الإلكتروني مطلوب');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(passwordResetRepositoryProvider).request(_email.text);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('تم إرسال الطلب'),
            content: Text('إذا كان البريد مسجلًا فسيصلك رابط الاستعادة.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = ApiFailure.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
