import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';
import 'data_export_screen.dart';
import 'account_appeal_screen.dart';

/// Suspended members retain access to export, account deletion and sign-out.
class SuspendedAccountScreen extends StatefulWidget {
  const SuspendedAccountScreen({
    required this.api,
    required this.onSignOut,
    required this.onCheckAccount,
    super.key,
  });

  final ApiClient api;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onCheckAccount;

  @override
  State<SuspendedAccountScreen> createState() => _SuspendedAccountScreenState();
}

class _SuspendedAccountScreenState extends State<SuspendedAccountScreen> {
  bool _busy = false;

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    var password = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.deleteAccountWarning),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => password = value,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    final supplied = password;
    if (approved != true || !mounted || supplied.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteAccount(supplied);
      await widget.onSignOut();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.connectionError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                const Icon(Icons.shield_outlined, size: 70, color: Palette.rose),
                const SizedBox(height: 24),
                Text(t.accountSuspendedTitle, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
                const SizedBox(height: 14),
                Text(t.accountSuspendedHint, textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.secondary, height: 1.55)),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: _busy ? null : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountAppealScreen(api: widget.api),
                    ),
                  ),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: Text(t.appealTitle),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onCheckAccount();
                    } catch (_) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.connectionError)),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(t.checkAccountStatus),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DataExportScreen(api: widget.api),
                    ),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(t.exportData),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : widget.onSignOut,
                  icon: const Icon(Icons.logout),
                  label: Text(t.logOut),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _busy ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(t.deleteAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
