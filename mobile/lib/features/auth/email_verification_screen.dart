import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    required this.api, required this.onVerified, required this.onSignOut, super.key,
  });

  final ApiClient api;
  final ValueChanged<SessionUser> onVerified;
  final Future<void> Function() onSignOut;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  bool _error = false;

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _sendCode() async {
    if (_busy) return;
    setState(() { _busy = true; _error = false; });
    try {
      final locale = Localizations.localeOf(context).languageCode;
      await widget.api.requestEmailVerificationCode(locale);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_busy || !RegExp(r'^\d{6}$').hasMatch(code)) return;
    setState(() { _busy = true; _error = false; });
    try {
      final user = await widget.api.verifyEmailCode(code);
      if (mounted) widget.onVerified(user);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.emailVerificationTitle), actions: [
        IconButton(onPressed: _busy ? null : widget.onSignOut,
          icon: const Icon(Icons.logout_rounded), tooltip: t.logOut),
      ]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Center(child: Icon(Icons.mark_email_unread_outlined, size: 76)),
          const SizedBox(height: 24),
          Text(t.emailVerificationTitle, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(t.emailVerificationHint, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: _busy ? null : _sendCode,
            icon: const Icon(Icons.mail_outline_rounded), label: Text(t.sendVerificationCode)),
          if (_sent) ...[
            const SizedBox(height: 12),
            Text(t.verificationCodeSent, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          TextField(controller: _code, keyboardType: TextInputType.number,
            maxLength: 6, textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: t.verificationCode, counterText: ''),
            onSubmitted: (_) => _verify()),
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _verify, child: Text(t.verifyEmail)),
          if (_error) ...[
            const SizedBox(height: 12),
            Text(t.verificationFailed, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF869F))),
          ],
        ])),
      ),
    );
  }
}
