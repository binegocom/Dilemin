import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  List<DeviceSession> _sessions = const [];
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final sessions = await widget.api.deviceSessions();
      if (mounted) setState(() {
        _sessions = sessions;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _revoke(DeviceSession session) async {
    if (_busy || session.current) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.revokeSession),
        content: Text(l10n.revokeSessionConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.revokeSession)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.revokeSession(session.id);
      await _refresh();
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _revokeOthers() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    String password = '';
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(l10n.revokeOtherSessions),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.revokeSessionConfirmation),
        const SizedBox(height: 16),
        TextField(
          obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: InputDecoration(labelText: l10n.password),
          onChanged: (value) => password = value,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.revokeOtherSessions)),
      ],
    ));
    if (confirmed != true || password.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.revokeOtherSessions(password);
      await _refresh();
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _error() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.connectionError),
    ));
  }

  String _date(DateTime? date) {
    if (date == null) return '–';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.activeSessions), actions: [
        IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh), tooltip: l10n.retry),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(child: TextButton(onPressed: _refresh, child: Text(l10n.retry)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text(l10n.sessionPrivacyNote),
                  const SizedBox(height: 16),
                  for (final session in _sessions) Card(child: ListTile(
                    leading: Icon(session.current ? Icons.phonelink_lock : Icons.devices),
                    title: Text(session.current ? l10n.currentSession : session.name),
                    subtitle: Text('${l10n.lastUsed}: ${_date(session.lastUsedAt)}\n'
                      '${l10n.sessionExpires}: ${_date(session.expiresAt)}'),
                    isThreeLine: true,
                    trailing: session.current ? const Icon(Icons.check_circle_outline) : IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: l10n.revokeSession,
                      onPressed: _busy ? null : () => _revoke(session),
                    ),
                  )),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: _busy || _sessions.every((session) => session.current)
                        ? null : _revokeOthers,
                    icon: const Icon(Icons.phonelink_erase),
                    label: Text(l10n.revokeOtherSessions),
                  ),
                ]),
    );
  }
}
