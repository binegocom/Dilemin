import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

typedef Authenticated = Future<void> Function(String token, SessionUser user);

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.api, required this.onAuthenticated, super.key});
  final ApiClient api;
  final Authenticated onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _birthday;
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _adult(DateTime birthday) {
    final today = DateTime.now();
    final cutoff = DateTime(today.year - 18, today.month, today.day);
    return !birthday.isAfter(cutoff);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_register && _birthday == null) {
      setState(() => _message = l10n.birthdateRequired);
      return;
    }
    if (_register && !_adult(_birthday!)) {
      setState(() => _message = l10n.underage);
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final (token, user) = _register
          ? await widget.api.register(
              email: _email.text.trim(),
              password: _password.text,
              name: _name.text.trim(),
              birthday: '${_birthday!.year.toString().padLeft(4, '0')}-'
                  '${_birthday!.month.toString().padLeft(2, '0')}-'
                  '${_birthday!.day.toString().padLeft(2, '0')}',
            )
          : await widget.api.login(_email.text.trim(), _password.text);
      await widget.onAuthenticated(token, user);
    } on ApiException catch (_) {
      if (mounted) setState(() => _message = _register ? l10n.signUpError : l10n.invalidCredentials);
    } catch (_) {
      if (mounted) setState(() => _message = l10n.connectionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.favorite_rounded, color: color, size: 56),
                      const SizedBox(height: 12),
                      Text('Dılêmın', textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(l10n.welcomeTitle, textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(l10n.welcomeSubtitle, textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: .65))),
                      const SizedBox(height: 32),
                      if (_register) ...[
                        TextFormField(controller: _name, decoration: InputDecoration(labelText: l10n.displayName),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) => value != null && value.trim().length >= 2 ? null : l10n.requiredFields),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: l10n.email),
                        validator: (value) => value != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
                            ? null : l10n.requiredFields,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: [if (_register) AutofillHints.newPassword else AutofillHints.password],
                        decoration: InputDecoration(labelText: l10n.password,
                          helperText: _register ? l10n.passwordHint : null),
                        validator: (value) => value != null && value.length >= (_register ? 12 : 1)
                            ? null : l10n.requiredFields,
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () async {
                            final now = DateTime.now();
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: DateTime(now.year - 20, now.month, now.day),
                              firstDate: DateTime(1900), lastDate: now,
                            );
                            if (selected != null && mounted) setState(() => _birthday = selected);
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_birthday == null ? l10n.birthday :
                            '${_birthday!.day.toString().padLeft(2, '0')}.${_birthday!.month.toString().padLeft(2, '0')}.${_birthday!.year}'),
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!, style: const TextStyle(color: Color(0xFFFF859E)), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        child: _busy ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_register ? l10n.register : l10n.logIn),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() {
                          _register = !_register;
                          _message = null;
                        }),
                        child: Text(_register ? l10n.haveAccount : l10n.noAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
