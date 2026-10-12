import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/push_device_registration.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/conversations_screen.dart';
import '../directory/directory_screen.dart';
import '../profiles/person_screen.dart';
import '../radar/radar_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.api,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
    required this.onSessionExpired,
    super.key,
  });

  final ApiClient api;
  final SessionUser user;
  final ValueChanged<SessionUser> onUserChanged;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onSessionExpired;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final PushDeviceRegistration _push;
  int _directoryRevision = 0;
  int _conversationsRevision = 0;

  @override
  void initState() {
    super.initState();
    _push = PushDeviceRegistration(
      api: widget.api,
      onOpenChat: _openPushConversation,
      onForegroundChat: () {
        if (mounted) setState(() => _conversationsRevision++);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (widget.user.pushMessagesEnabled) _push.start(deviceLocale);
    });
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.user.pushMessagesEnabled && widget.user.pushMessagesEnabled) {
      final locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _push.start(locale);
    } else if (oldWidget.user.pushMessagesEnabled && !widget.user.pushMessagesEnabled) {
      _push.unregister();
    }
  }

  Future<void> _openPushConversation(String conversationId) async {
    if (!mounted) return;
    try {
      final items = await widget.api.conversations();
      if (!mounted) return;
      for (final item in items) {
        if (item.id == conversationId) {
          await _openChat(item.id, item.person.name);
          return;
        }
      }
    } catch (_) {
      // Unknown/blocked conversations are never opened directly.
    }
    if (mounted) _selectTab(2);
  }

  Future<void> _signOut() async {
    await _push.unregister();
    await widget.onSignOut();
  }

  @override
  void dispose() {
    _push.dispose();
    super.dispose();
  }

  Future<void> _openChat(String conversationId, String name) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        api: widget.api, conversationId: conversationId, personName: name,
        sessionUserId: widget.user.id,
      ),
    ));
    if (mounted) setState(() => _conversationsRevision++);
  }

  Future<void> _openPerson(OnlinePerson person) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonScreen(
        api: widget.api, personId: person.id,
        onOpenConversation: (id, name) => _openChat(id, name),
      ),
    ));
    if (mounted) setState(() {
      _directoryRevision++;
      _conversationsRevision++;
    });
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 1) _directoryRevision++;
      if (index == 2) _conversationsRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        RadarScreen(
          api: widget.api, user: widget.user,
          onUserChanged: widget.onUserChanged,
          onSignOut: _signOut,
          onSessionExpired: widget.onSessionExpired,
          onPersonTap: _openPerson,
        ),
        DirectoryScreen(api: widget.api, revision: _directoryRevision, onPersonTap: _openPerson),
        ConversationsScreen(
          api: widget.api, revision: _conversationsRevision,
          sessionUserId: widget.user.id,
          onConversationTap: _openChat,
        ),
        AccountScreen(
          api: widget.api, user: widget.user,
          onUserChanged: widget.onUserChanged,
          onSignOut: _signOut,
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.radar), label: l10n.navRadar),
          NavigationDestination(icon: const Icon(Icons.people_alt_outlined), label: l10n.navOnline),
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), label: l10n.navChats),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: l10n.navAccount),
        ],
      ),
    );
  }
}
