import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    required this.api,
    required this.revision,
    required this.onConversationTap,
    super.key,
  });

  final ApiClient api;
  final int revision;
  final Future<void> Function(String id, String name) onConversationTap;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with WidgetsBindingObserver {
  Timer? _timer;
  bool _active = true;
  List<ConversationPreview> _conversations = const [];
  bool _loading = true;
  bool _failed = false;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_active) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refresh();
  }

  @override
  void didUpdateWidget(covariant ConversationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _refresh();
  }

  Future<void> _refresh() async {
    final serial = ++_serial;
    try {
      final data = await widget.api.conversations();
      if (mounted && serial == _serial) setState(() {
        _conversations = data; _loading = false; _failed = false;
      });
    } catch (_) {
      if (mounted && serial == _serial) setState(() { _failed = true; _loading = false; });
    }
  }

  @override
  void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); _serial++; super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(child: RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.all(22), sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.navChats, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l10n.chatsSubtitle, style: const TextStyle(color: Palette.secondary)),
          ]),
        )),
        if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_failed) SliverFillRemaining(child: Center(child: TextButton(
          onPressed: _refresh, child: Text(l10n.retry))))
        else if (_conversations.isEmpty) SliverFillRemaining(child: Center(child: Text(l10n.noChats,
          style: const TextStyle(color: Palette.secondary))))
        else SliverList.builder(
          itemCount: _conversations.length,
          itemBuilder: (context, index) {
            final entry = _conversations[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
              leading: ProfileAvatar(name: entry.person.name),
              title: Text(entry.person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(l10n.openConversation),
              trailing: entry.unreadCount > 0
                ? Semantics(label: l10n.unreadMessages(entry.unreadCount), child: Badge(
                    label: Text(entry.unreadCount > 99 ? '99+' : '${entry.unreadCount}'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ))
                : const Icon(Icons.chevron_right),
              onTap: () async {
                await widget.onConversationTap(entry.id, entry.person.name);
                if (mounted) _refresh();
              },
            );
          },
        ),
      ]),
    ));
  }
}
