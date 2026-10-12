import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../animations/lottie_online_pulse.dart';
import '../animations/rive_presence_indicator.dart';
import '../directory/online_profile_card.dart';
import '../../ui/palette.dart';
import 'radar_canvas.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({
    required this.api,
    required this.user,
    this.active = true,
    required this.onUserChanged,
    required this.onSignOut,
    required this.onSessionExpired,
    required this.onPersonTap,
    super.key,
  });

  final ApiClient api;
  final bool active;
  final SessionUser user;
  final ValueChanged<SessionUser> onUserChanged;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onSessionExpired;
  final ValueChanged<OnlinePerson> onPersonTap;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with WidgetsBindingObserver {
  Timer? _timer;
  List<OnlinePerson> _people = const [];
  bool _active = true;
  bool _loading = true;
  bool _updating = false;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!_active || _updating || !mounted) return;
    _updating = true;
    try {
      await widget.api.heartbeat();
      final people = await widget.api.onlinePeople();
      if (mounted) setState(() {
        _people = people;
        _failed = false;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _timer?.cancel();
        await widget.onSessionExpired();
      } else if (mounted) {
        setState(() { _failed = true; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _failed = true; _loading = false; });
    } finally {
      _updating = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _active = true;
        _tick();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_active) {
          _active = false;
          unawaited(widget.api.offline().catchError((Object _) {}));
        }
    }
  }

  Future<void> _setVisibility(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final user = await widget.api.visibility(value);
      widget.onUserChanged(user);
      if (user.onlineVisible) await _tick();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.connectionError),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              onRefresh: _tick,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                children: [
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Palette.rose, Color(0xFF803EAC)],
                        ),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -.8))),
                    IconButton(
                      tooltip: l10n.logOut,
                      onPressed: _saving ? null : () async {
                        try { await widget.api.offline(); } catch (_) { /* TTL fallback */ }
                        await widget.onSignOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: Text(l10n.radarTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800))),
                    if (!_loading && !_failed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: Palette.mint.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Palette.mint.withValues(alpha: .3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.circle, color: Palette.mint, size: 8),
                          const SizedBox(width: 7),
                          Text(l10n.onlineCount(_people.length),
                            style: const TextStyle(color: Palette.mint,
                              fontWeight: FontWeight.w600, fontSize: 11)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 7),
                  Text(l10n.radarSubtitle,
                    style: const TextStyle(color: Palette.secondary, height: 1.5)),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        center: Alignment.center,
                        radius: .9,
                        colors: [Color(0xFF242039), Color(0xFF111525)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Palette.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      child: Center(child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: RepaintBoundary(child: RadarCanvas(
                          api: widget.api,
                          active: widget.active,
                          people: _people,
                          centerName: widget.user.name,
                          centerUserId: widget.user.id,
                          centerPhotoId: widget.user.photoId,
                          onPersonTap: widget.onPersonTap,
                        )),
                      )),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Palette.border),
                    ),
                    child: SwitchListTile.adaptive(
                      secondary: Icon(Icons.visibility_outlined,
                        color: widget.user.onlineVisible ? Palette.mint : Palette.secondary),
                      title: Text(l10n.visibility,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.privacyNote,
                        style: const TextStyle(fontSize: 12, color: Palette.secondary)),
                      value: widget.user.onlineVisible,
                      onChanged: _saving ? null : _setVisibility,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(children: [
                    const SizedBox(width: 28, height: 28,
                      child: RepaintBoundary(child: LottieOnlinePulse())),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l10n.onlineNow, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold))),
                    if (!_loading && !_failed && _people.isNotEmpty)
                      const SizedBox(width: 26, height: 26,
                        child: RepaintBoundary(child: RivePresenceIndicator())),
                    if (!_loading && !_failed) Text(l10n.onlineCount(_people.length),
                      style: const TextStyle(color: Color(0xFFB7B7CA), fontSize: 12)),
                  ]),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator()))
                  else if (_failed)
                    Center(child: Column(children: [
                      Text(l10n.connectionError, textAlign: TextAlign.center),
                      TextButton(onPressed: _tick, child: Text(l10n.retry)),
                    ]))
                  else if (_people.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 34),
                      child: Text(l10n.emptyState, textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB7B7CA))))
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 500 ? 4 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: .82,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _people.length,
                        itemBuilder: (context, index) {
                          final person = _people[index];
                          return OnlineProfileCard(
                            key: ValueKey(person.id),
                            api: widget.api,
                            person: person,
                            onTap: () => widget.onPersonTap(person),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
