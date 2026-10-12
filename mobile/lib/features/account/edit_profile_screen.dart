import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.api, required this.user, super.key});
  final ApiClient api;
  final SessionUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _bio = TextEditingController(text: widget.user.bio ?? '');
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); _bio.dispose(); super.dispose(); }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_key.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateProfile(_name.text.trim(), _bio.text.trim());
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.connectionError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(key: _key, child: ListView(padding: const EdgeInsets.all(24), children: [
          TextFormField(
            controller: _name, maxLength: 80,
            decoration: InputDecoration(labelText: l10n.displayName),
            validator: (value) => (value?.trim().length ?? 0) >= 2 ? null : l10n.requiredFields,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bio, maxLength: 500, maxLines: 5,
            decoration: InputDecoration(labelText: l10n.aboutMe, alignLabelWithHint: true),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.saveChanges),
          ),
        ])),
      )),
    );
  }
}
