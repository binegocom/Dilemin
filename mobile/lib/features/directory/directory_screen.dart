import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';
import 'online_profile_card.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({
    required this.api,
    required this.revision,
    required this.onPersonTap,
    super.key,
  });

  final ApiClient api;
  final int revision;
  final ValueChanged<OnlinePerson> onPersonTap;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> with WidgetsBindingObserver {
  Timer? _timer;
  bool _active = true;
  final _search = TextEditingController();
  List<OnlinePerson> _people = const [];
  bool _busy = true;
  bool _failed = false;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_active) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refresh();
  }

  @override
  void didUpdateWidget(covariant DirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_requestSerial;
    try {
      final data = await widget.api.onlinePeople();
      if (mounted && request == _requestSerial) {
        setState(() { _people = data; _busy = false; _failed = false; });
      }
    } catch (_) {
      if (mounted && request == _requestSerial) {
        setState(() { _busy = false; _failed = true; });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _requestSerial++;
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = _search.text.trim().toLowerCase();
    final people = _people.where((person) =>
        filter.isEmpty || person.name.toLowerCase().contains(filter)).toList();
    return SafeArea(child: RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 16), sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.onlineNow, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(l10n.directoryHint, style: const TextStyle(color: Palette.secondary)),
            const SizedBox(height: 22),
            TextField(
              controller: _search, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchProfiles),
            ),
            const SizedBox(height: 16),
            if (!_busy && !_failed) Text(l10n.onlineCount(people.length),
              style: const TextStyle(color: Palette.mint)),
          ]),
        )),
        if (_busy) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_failed) SliverFillRemaining(child: Center(child: TextButton(
          onPressed: _refresh, child: Text(l10n.retry))))
        else if (people.isEmpty) SliverFillRemaining(child: Center(child: Text(
          l10n.emptyState, style: const TextStyle(color: Palette.secondary))))
        else SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverLayoutBuilder(builder: (context, constraints) {
            final cols = constraints.crossAxisExtent >= 650 ? 4 : constraints.crossAxisExtent >= 420 ? 3 : 2;
            return SliverGrid.builder(
              itemCount: people.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: .9,
              ),
              itemBuilder: (context, index) {
                final person = people[index];
                return OnlineProfileCard(
                  key: ValueKey(person.id),
                  api: widget.api,
                  person: person,
                  onTap: () => widget.onPersonTap(person),
                );
              },
            );
          }),
        ),
      ]),
    ));
  }
}
