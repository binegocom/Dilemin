import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class AccountAppealReviewScreen extends StatefulWidget {
  const AccountAppealReviewScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<AccountAppealReviewScreen> createState() =>
      _AccountAppealReviewScreenState();
}

class _AccountAppealReviewScreenState extends State<AccountAppealReviewScreen> {
  List<PendingAppeal>? _appeals;
  bool _failed = false;
  String? _processing;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final entries = await widget.api.pendingAppeals();
      if (mounted) setState(() {
        _appeals = entries;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _review(PendingAppeal appeal, String decision) async {
    if (_processing != null) return;
    final t = AppLocalizations.of(context)!;
    var reason = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text(decision == 'restored'
              ? t.restoreFromAppeal : t.rejectAppeal),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(appeal.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(appeal.statement),
            const SizedBox(height: 18),
            TextField(
                            maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: t.appealDecisionReason),
              onChanged: (value) { reason = value; rebuild(() {}); },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: reason.trim().length < 5
                  ? null : () => Navigator.pop(dialogContext, true),
              child: Text(decision == 'restored'
                  ? t.restoreFromAppeal : t.rejectAppeal),
            ),
          ],
        ),
      ),
    );
    final submittedReason = reason.trim();
    if (confirm != true || !mounted || submittedReason.length < 5) return;

    setState(() => _processing = appeal.id);
    try {
      await widget.api.reviewAccountAppeal(appeal.id, decision, submittedReason);
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
        title: Text(t.appealReview),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: t.retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _failed
          ? Center(child: TextButton(onPressed: _refresh, child: Text(t.retry)))
          : _appeals == null
              ? const Center(child: CircularProgressIndicator())
              : _appeals!.isEmpty
                  ? Center(child: Text(t.noPendingAppeals))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _appeals!.length,
                      itemBuilder: (context, index) {
                        final appeal = _appeals![index];
                        return Card(child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appeal.name,
                                style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              Text(appeal.statement),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(child: OutlinedButton(
                                  onPressed: _processing == null
                                      ? () => _review(appeal, 'rejected') : null,
                                  child: Text(t.rejectAppeal),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: FilledButton(
                                  onPressed: _processing == null
                                      ? () => _review(appeal, 'restored') : null,
                                  child: Text(t.restoreFromAppeal),
                                )),
                              ]),
                            ],
                          ),
                        ));
                      },
                    ),
    );
  }
}
