import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  List<PendingPhoto>? _photos;
  String? _busyId;
  bool _failed = false;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    try {
      final data = await widget.api.pendingPhotos();
      if (mounted) setState(() { _photos = data; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _review(PendingPhoto photo, bool approved) async {
    if (_busyId != null) return;
    setState(() => _busyId = photo.id);
    try {
      await widget.api.reviewPhoto(photo, approved);
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.reviewFailed)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.photoModeration), actions: [
      IconButton(onPressed: _refresh, tooltip: t.retry, icon: const Icon(Icons.refresh)),
    ]), body: _failed ? Center(child: TextButton(onPressed: _refresh, child: Text(t.retry)))
      : _photos == null ? const Center(child: CircularProgressIndicator())
      : _photos!.isEmpty ? Center(child: Text(t.noPendingPhotos))
      : ListView.builder(itemCount: _photos!.length, padding: const EdgeInsets.all(18),
        itemBuilder: (context, i) {
          final photo = _photos![i];
          return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            Text(photo.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<Uint8List>(
              future: widget.api.moderationPhotoBytes(photo.id),
              builder: (context, snap) => snap.hasData
                ? Image.memory(snap.data!, width: 260, height: 260, fit: BoxFit.cover)
                : const SizedBox(height: 120, child: Center(child: Icon(Icons.image_not_supported_outlined))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busyId == null ? () => _review(photo, false) : null,
                child: Text(t.rejectPhoto))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _busyId == null ? () => _review(photo, true) : null,
                child: Text(t.approvePhoto))),
            ]),
          ])));
        }),
    );
  }
}
