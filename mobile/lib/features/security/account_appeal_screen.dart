import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';

class AccountAppealScreen extends StatefulWidget {
  const AccountAppealScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<AccountAppealScreen> createState() => _AccountAppealScreenState();
}

class _AccountAppealScreenState extends State<AccountAppealScreen> {
  final _statement = TextEditingController();
  AccountAppeal? _appeal;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final value = await widget.api.accountAppeal();
      if (mounted) setState(() {
        _appeal = value;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _appeal != null) return;
    final statement = _statement.text.trim();
    final t = AppLocalizations.of(context)!;
    if (statement.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.appealRequiredLength)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.submitAccountAppeal(statement);
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.appealSent)),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        // A concurrent submission from another signed-in device may have won.
        await _reload();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.connectionError)),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.connectionError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appealTitle),
        actions: [
          IconButton(
            tooltip: t.retry,
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(child: TextButton(onPressed: _reload, child: Text(t.retry)))
              : ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    const Icon(Icons.balance_outlined, size: 54, color: Palette.rose),
                    const SizedBox(height: 16),
                    Text(t.appealHint, textAlign: TextAlign.center,
                      style: const TextStyle(color: Palette.secondary, height: 1.5)),
                    const SizedBox(height: 22),
                    if (_appeal == null) ...[
                      TextField(
                        controller: _statement,
                        maxLines: 8,
                        minLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(labelText: t.appealStatement,
                          alignLabelWithHint: true),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(t.appealSubmit),
                      ),
                    ] else ...[
                      Card(child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(switch (_appeal!.status) {
                              'rejected' => t.appealStatusRejected,
                              'restored' => t.appealStatusRestored,
                              _ => t.appealStatusPending,
                            }, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Text(_appeal!.statement),
                            if (_appeal!.reviewNote?.isNotEmpty ?? false) ...[
                              const Divider(height: 30),
                              Text(t.appealDecisionNote,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(_appeal!.reviewNote!),
                            ],
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
    );
  }
}
