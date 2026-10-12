import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';

class PersonScreen extends StatefulWidget {
  const PersonScreen({
    required this.api,
    required this.personId,
    required this.onOpenConversation,
    super.key,
  });

  final ApiClient api;
  final String personId;
  final Future<void> Function(String id, String name) onOpenConversation;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  OnlinePerson? _person;
  bool _busy = true;
  bool _actionBusy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final person = await widget.api.person(widget.personId);
      if (mounted) setState(() { _person = person; _busy = false; _failed = false; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _failed = true; });
    }
  }

  void _error() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.connectionError)),
    );
  }

  Future<void> _message() async {
    final person = _person;
    if (person == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final conversationId = await widget.api.startConversation(person.id);
      if (!mounted) return;
      await widget.onOpenConversation(conversationId, person.name);
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _actionBusy = false); }
  }

  Future<void> _block() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(l10n.blockUser),
      content: Text(l10n.blockExplanation),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.blockUser)),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await widget.api.block(widget.personId);
      if (mounted) Navigator.pop(context);
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _actionBusy = false); }
  }

  Future<void> _report() async {
    final l10n = AppLocalizations.of(context)!;
    const reasons = ['spam', 'harassment', 'impersonation', 'underage', 'other'];
    String reason = reasons.first;
    final details = TextEditingController();
    final send = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.reportUser),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: reason,
            items: [
              DropdownMenuItem(value: 'spam', child: Text(l10n.reasonSpam)),
              DropdownMenuItem(value: 'harassment', child: Text(l10n.reasonHarassment)),
              DropdownMenuItem(value: 'impersonation', child: Text(l10n.reasonImpersonation)),
              DropdownMenuItem(value: 'underage', child: Text(l10n.reasonUnderage)),
              DropdownMenuItem(value: 'other', child: Text(l10n.reasonOther)),
            ],
            onChanged: (value) { if (value != null) setDialogState(() => reason = value); },
          ),
          const SizedBox(height: 12),
          TextField(controller: details, maxLength: 1000, maxLines: 3,
            decoration: InputDecoration(labelText: l10n.reportDetails)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.submitReport)),
        ],
      ),
    ));
    final message = details.text;
    details.dispose();
    if (send != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await widget.api.report(widget.personId, reason, details: message);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.reportReceived)));
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _actionBusy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final person = _person;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: _busy ? const Center(child: CircularProgressIndicator())
          : _failed || person == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.profileUnavailable),
                TextButton(onPressed: _load, child: Text(l10n.retry)),
              ]))
              : Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const SizedBox(height: 30),
                    Center(child: ProfileAvatar(name: person.name, size: 132, isOnline: true)),
                    const SizedBox(height: 20),
                    Text(person.name, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Center(child: Text(l10n.onlineStatus, style: const TextStyle(color: Palette.mint))),
                    const SizedBox(height: 32),
                    Text(l10n.aboutMe, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text((person.bio?.trim().isNotEmpty ?? false) ? person.bio! : l10n.noBio,
                      style: const TextStyle(color: Palette.secondary, height: 1.5)),
                    const SizedBox(height: 40),
                    FilledButton.icon(
                      onPressed: _actionBusy ? null : _message,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(l10n.sendMessage),
                    ),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton.icon(onPressed: _actionBusy ? null : _report,
                        icon: const Icon(Icons.flag_outlined), label: Text(l10n.reportUser)),
                      TextButton.icon(onPressed: _actionBusy ? null : _block,
                        icon: const Icon(Icons.block), label: Text(l10n.blockUser)),
                    ]),
                  ]),
                )),
    );
  }
}
