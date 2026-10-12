import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class SuspendedAccountsScreen extends StatefulWidget {
  const SuspendedAccountsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<SuspendedAccountsScreen> createState() => _SuspendedAccountsScreenState();
}

class _SuspendedAccountsScreenState extends State<SuspendedAccountsScreen> {
  List<SuspendedProfile>? _profiles;
  String? _processing;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final profiles = await widget.api.suspendedProfiles();
      if (mounted) setState(() {
        _profiles = profiles;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _restore(SuspendedProfile profile) async {
    if (_processing != null) return;
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text(t.restoreAccount),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.restoreAccountConfirmation),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: t.restoreReason),
              onChanged: (_) => rebuild(() {}),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: controller.text.trim().length < 3
                ? null : () => Navigator.pop(dialogContext, true),
              child: Text(t.restoreAccount),
            ),
          ],
        ),
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted || reason.length < 3) return;
    setState(() => _processing = profile.id);
    try {
      await widget.api.restoreSuspendedProfile(profile.id, reason);
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.reviewFailed)),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.suspendedAccounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.retry,
            onPressed: _refresh,
          ),
        ],
      ),
      body: _failed
          ? Center(child: TextButton(onPressed: _refresh, child: Text(t.retry)))
          : _profiles == null
              ? const Center(child: CircularProgressIndicator())
              : _profiles!.isEmpty
                  ? Center(child: Text(t.noSuspendedAccounts))
                  : ListView.builder(
                      itemCount: _profiles!.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles![index];
                        return ListTile(
                          leading: const Icon(Icons.person_off_outlined),
                          title: Text(profile.name),
                          subtitle: Text(profile.id),
                          trailing: TextButton(
                            onPressed: _processing == null
                              ? () => _restore(profile)
                              : null,
                            child: Text(t.restoreAccount),
                          ),
                        );
                      },
                    ),
    );
  }
}
