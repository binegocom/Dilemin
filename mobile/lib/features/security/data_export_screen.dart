import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/api_client.dart';
import '../../l10n/app_localizations.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    File? file;
    try {
      final directory = await getTemporaryDirectory();
      file = File('${directory.path}/dilemin-export-${DateTime.now().microsecondsSinceEpoch}.json');
      await widget.api.exportAccount(_password.text, file);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: const ['dilemin-account-export.json'],
        sharePositionOrigin: box == null
            ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.exportFailed),
      ));
    } finally {
      _password.clear();
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportData)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 580),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.lock_outline, size: 50),
          const SizedBox(height: 22),
          Text(l10n.exportPrivacyNote),
          const SizedBox(height: 28),
          Form(key: _form, child: TextFormField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l10n.password),
            validator: (value) => (value == null || value.isEmpty) ? l10n.requiredFields : null,
          )),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy ? const SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
            label: Text(l10n.exportData),
          ),
        ]),
      )),
    );
  }
}
