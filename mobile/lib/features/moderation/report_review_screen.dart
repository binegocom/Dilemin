import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  List<PendingReport>? _reports;
  String? _busyId;
  bool _failed = false;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    try {
      final data = await widget.api.pendingReports();
      if (mounted) setState(() { _reports = data; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _review(PendingReport report, bool dismissed) async {
    if (_busyId != null) return;
    setState(() => _busyId = report.id);
    try {
      await widget.api.reviewReport(report.id, dismissed);
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.reviewFailed)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.reportReview),
      actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: t.retry, onPressed: _refresh)]),
      body: _failed ? Center(child: TextButton(onPressed: _refresh, child: Text(t.retry)))
        : _reports == null ? const Center(child: CircularProgressIndicator())
        : _reports!.isEmpty ? Center(child: Text(t.noPendingReports))
        : ListView.builder(itemCount: _reports!.length, padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final report = _reports![index];
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.reportReason}: ${report.reason}',
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${t.reportedPerson}: ${report.reportedName ?? t.deletedAccount}'),
                Text('${t.reportingPerson}: ${report.reporterName}'),
                if (report.details?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10), Text(report.details!),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _busyId == null
                    ? () => _review(report, true) : null, child: Text(t.dismissReport))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _busyId == null
                    ? () => _review(report, false) : null, child: Text(t.markReviewed))),
                ]),
              ])));
          }),
    );
  }
}
