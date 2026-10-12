import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../l10n/app_localizations.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({required this.api, this.initialEmail = '', super.key});
  final ApiClient api;
  final String initialEmail;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _requested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _email.dispose(); _code.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _request() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.requestPasswordRecovery(
        email: _email.text.trim(), locale: Localizations.localeOf(context).languageCode);
      if (mounted) setState(() => _requested = true);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.connectionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim()) || _password.text.length < 12) {
      setState(() => _error = l10n.requiredFields);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.confirmPasswordRecovery(
        email: _email.text.trim(), code: _code.text.trim(), password: _password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordResetSuccess)));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.passwordResetFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.forgotPassword)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.lock_reset_outlined, size: 72),
          const SizedBox(height: 22),
          Text(t.passwordRecoveryHint, textAlign: TextAlign.center),
          const SizedBox(height: 22),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress,
            enabled: !_requested && !_busy,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: t.email)),
          const SizedBox(height: 14),
          if (!_requested) FilledButton(onPressed: _busy ? null : _request,
            child: Text(t.sendRecoveryCode)),
          if (_requested) ...[
            Text(t.recoveryCodeSent, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(controller: _code, maxLength: 6, keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(labelText: t.verificationCode, counterText: '')),
            const SizedBox(height: 14),
            TextField(controller: _password, obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: t.newPassword, helperText: t.passwordHint)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _confirm, child: Text(t.resetPassword)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 15),
            Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF859E))),
          ],
        ])),
      ),
    );
  }
}
