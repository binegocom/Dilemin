import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';
import 'private_avatar.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({required this.api, required this.user, super.key});
  final ApiClient api;
  final SessionUser user;

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  late SessionUser _user = widget.user;
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery,
        imageQuality: 84, maxWidth: 2048, maxHeight: 2048, requestFullMetadata: false);
      if (picked == null || !mounted) return;
      final user = await widget.api.uploadPhoto(picked);
      if (mounted) setState(() => _user = user);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.photoUploadFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = await widget.api.deletePhoto();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.connectionError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.profilePhoto)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Center(child: PrivateAvatar(api: widget.api, userId: _user.id,
            name: _user.name, photoId: _user.photoId, size: 180)),
          const SizedBox(height: 25),
          Text(t.photoPrivacyNote, textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.secondary)),
          const SizedBox(height: 14),
          if (_user.photoStatus == 'pending') Text(t.photoPending,
            textAlign: TextAlign.center, style: const TextStyle(color: Palette.rose)),
          if (_user.photoStatus == 'rejected') Text(t.photoRejected,
            textAlign: TextAlign.center, style: const TextStyle(color: Palette.rose)),
          const SizedBox(height: 25),
          FilledButton.icon(onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.photo_library_outlined), label: Text(t.choosePhoto)),
          if (_user.photoStatus != null && _user.photoStatus != 'none') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline), label: Text(t.removePhoto)),
          ],
        ])),
      ),
    );
  }
}
