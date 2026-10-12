import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.api,
    required this.conversationId,
    required this.personName,
    required this.sessionUserId,
    super.key,
  });

  final ApiClient api;
  final String conversationId;
  final String personName;
  final String sessionUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _compose = TextEditingController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _failed = false;
  String? _pendingClientId;
  String? _pendingBody;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    try {
      final data = await widget.api.messages(widget.conversationId);
      if (mounted) setState(() { _messages = data; _loading = false; _failed = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _send() async {
    final body = _compose.text.trim();
    if (body.isEmpty || body.length > 2000 || _sending) return;
    setState(() => _sending = true);
    try {
      if (_pendingBody != body) {
        _pendingBody = body;
        _pendingClientId = const Uuid().v4();
      }
      await widget.api.sendMessage(widget.conversationId, body, clientId: _pendingClientId);
      _pendingBody = null;
      _pendingClientId = null;
      _compose.clear();
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.messageFailed)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() { _compose.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.personName), actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: l10n.retry),
      ]),
      body: SafeArea(child: Column(children: [
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _failed ? Center(child: TextButton(onPressed: _refresh, child: Text(l10n.retry)))
          : _messages.isEmpty ? Center(child: Text(l10n.noMessages,
              style: const TextStyle(color: Palette.secondary)))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final mine = message.senderId == widget.sessionUserId;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .76),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                      decoration: BoxDecoration(
                        color: mine ? Palette.rose : Palette.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(message.body, style: const TextStyle(height: 1.4)),
                        const SizedBox(height: 4),
                        Text('${message.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
                          '${message.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ),
                  );
                },
              ),
            )),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(color: Palette.surface),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _compose,
              maxLines: 4, minLines: 1, maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.writeMessage,
                counterText: '', isDense: true),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              tooltip: l10n.sendMessage,
              icon: _sending ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      ])),
    );
  }
}
