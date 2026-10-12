import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../animations/lottie_online_pulse.dart';
import '../animations/rive_presence_indicator.dart';
import 'radar_canvas.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({
    required this.api,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
    required this.onSessionExpired,
    required this.onPersonTap,
    super.key,
  });

  final ApiClient api;
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  Row(children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFA4B86), size: 27),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Dılêmın', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                  const SizedBox(height: 22),
                  Text(l10n.radarTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(l10n.radarSubtitle, style: const TextStyle(color: Color(0xFFAAA9BD), height: 1.4)),
                  const SizedBox(height: 16),
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: RadarCanvas(people: _people, centerName: widget.user.name, onPersonTap: widget.onPersonTap),
                  )),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF17192A),
                    child: SwitchListTile.adaptive(
                      title: Text(l10n.visibility),
                      subtitle: Text(l10n.privacyNote, style: const TextStyle(fontSize: 12)),
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
                          childAspectRatio: .83,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _people.length,
                        itemBuilder: (context, index) {
                          final person = _people[index];
                          return InkWell(
                            key: ValueKey(person.id),
                            onTap: () => widget.onPersonTap(person),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF17192A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF302940)),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Stack(clipBehavior: Clip.none, children: [
                                CircleAvatar(radius: 27, backgroundColor: const Color(0xFF793C6B),
                                  child: Text(person.name.trim().isEmpty ? '•' : person.name.trim().substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700))),
                                Positioned(right: -1, bottom: 0, child: Container(width: 13, height: 13,
                                  decoration: BoxDecoration(color: const Color(0xFF4CE0B6),
                                    shape: BoxShape.circle, border: Border.all(color: const Color(0xFF17192A), width: 2)))),
                              ]),
                              const SizedBox(height: 8),
                              Text(person.name, textAlign: TextAlign.center,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ));
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
