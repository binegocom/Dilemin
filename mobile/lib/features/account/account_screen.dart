import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';
import 'edit_profile_screen.dart';
import '../photos/private_avatar.dart';
import '../photos/profile_photo_screen.dart';
import '../moderation/moderation_screen.dart';
import '../moderation/report_review_screen.dart';
import '../moderation/suspended_accounts_screen.dart';
import '../safety/blocked_people_screen.dart';
import '../security/device_sessions_screen.dart';
import '../security/data_export_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.api,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
    super.key,
  });

  final ApiClient api;
  final SessionUser user;
  final ValueChanged<SessionUser> onUserChanged;
  final Future<void> Function() onSignOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _setVisible(bool visible) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.api.visibility(visible);
      widget.onUserChanged(updated);
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _setMessageNotifications(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      widget.onUserChanged(await widget.api.setMessageNotifications(enabled));
    } catch (_) {
      _error();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error() {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.connectionError),
    ));
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final key = GlobalKey<FormState>();
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteAccount),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.deleteAccountWarning),
        const SizedBox(height: 18),
        TextFormField(
          controller: password, obscureText: true, decoration: InputDecoration(labelText: l10n.password),
          validator: (value) => (value?.isNotEmpty ?? false) ? null : l10n.requiredFields,
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () { if (key.currentState!.validate()) Navigator.pop(dialogContext, true); },
          child: Text(l10n.deleteAccount),
        ),
      ],
    ));
    final suppliedPassword = password.text;
    password.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteAccount(suppliedPassword);
      await widget.onSignOut();
    } catch (_) { _error(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<SessionUser>(MaterialPageRoute(
      builder: (_) => EditProfileScreen(api: widget.api, user: widget.user),
    ));
    if (updated != null) widget.onUserChanged(updated);
  }

  Future<void> _editPhoto() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ProfilePhotoScreen(api: widget.api, user: widget.user),
    ));
    if (!mounted) return;
    try { widget.onUserChanged(await widget.api.me()); } catch (_) { _error(); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        Text(l10n.navAccount, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        Center(child: PrivateAvatar(api: widget.api, userId: widget.user.id,
          name: widget.user.name, photoId: widget.user.photoId, size: 96)),
        const SizedBox(height: 14),
        Text(widget.user.name, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (widget.user.bio?.isNotEmpty ?? false) Text(widget.user.bio!, textAlign: TextAlign.center,
          style: const TextStyle(color: Palette.secondary)),
        const SizedBox(height: 26),
        Card(color: Palette.surface, child: Column(children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.editProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _edit,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_camera_back_outlined),
            title: Text(l10n.profilePhoto),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _editPhoto,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: Text(l10n.blockedPeople),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BlockedPeopleScreen(api: widget.api))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.activeSessions),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DeviceSessionsScreen(api: widget.api))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.exportData),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DataExportScreen(api: widget.api))),
          ),
          if (widget.user.isModerator) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.photoModeration),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ModerationScreen(api: widget.api))),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.reportReview),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReportReviewScreen(api: widget.api))),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(l10n.suspendedAccounts),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SuspendedAccountsScreen(api: widget.api))),
            ),
          ],
          const Divider(height: 1),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.messageNotifications),
            subtitle: Text(l10n.messageNotificationsHint),
            value: widget.user.pushMessagesEnabled,
            onChanged: _busy ? null : _setMessageNotifications,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.visibility_outlined),
            title: Text(l10n.visibility),
            subtitle: Text(l10n.privacyNote),
            value: widget.user.onlineVisible,
            onChanged: _busy ? null : _setVisible,
          ),
        ])),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _busy ? null : widget.onSignOut,
          icon: const Icon(Icons.logout), label: Text(l10n.logOut),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _busy ? null : _deleteAccount,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.deleteAccount, style: const TextStyle(color: Color(0xFFFF859E))),
        ),
      ]),
    )));
  }
}
