import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({required this.uid, required this.token, super.key});
  final String uid;
  final String token;
  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('كلمة مرور جديدة')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _field(_password, 'كلمة المرور الجديدة'),
            _field(_confirm, 'تأكيد كلمة المرور'),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'جارٍ الحفظ…' : 'حفظ كلمة المرور'),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        obscureText: _hidden,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
          ),
        ),
      );

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'كلمة المرور يجب ألا تقل عن 8 أحرف');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(passwordResetRepositoryProvider).confirm(
            uid: widget.uid,
            token: widget.token,
            password: _password.text,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) setState(() => _error = ApiFailure.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
