import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class BlockedPeopleScreen extends StatefulWidget {
  const BlockedPeopleScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<BlockedPeopleScreen> createState() => _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends State<BlockedPeopleScreen> {
  List<OnlinePerson>? _people;
  bool _failed = false;
  String? _workingId;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    try {
      final result = await widget.api.blockedPeople();
      if (mounted) setState(() { _people = result; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _unblock(OnlinePerson person) async {
    if (_workingId != null) return;
    setState(() => _workingId = person.id);
    try {
      await widget.api.unblock(person.id);
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.connectionError)));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.blockedPeople)),
      body: _failed ? Center(child: TextButton(onPressed: _refresh, child: Text(t.retry)))
        : _people == null ? const Center(child: CircularProgressIndicator())
        : _people!.isEmpty ? Center(child: Text(t.noBlockedPeople))
        : ListView.builder(itemCount: _people!.length,
          itemBuilder: (context, index) {
            final person = _people![index];
            return ListTile(title: Text(person.name),
              trailing: OutlinedButton(onPressed: _workingId == null ? () => _unblock(person) : null,
                child: Text(t.unblockPerson)));
          }),
    );
  }
}
