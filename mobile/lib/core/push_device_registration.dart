import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Registration is opt-in at build time: native Firebase config must be
/// provisioned before compiling with ENABLE_PUSH=true.
class PushDeviceRegistration {
  PushDeviceRegistration({
    required this.api,
    required this.onOpenChat,
    required this.onForegroundChat,
  });

  final ApiClient api;
  final void Function(String conversationId) onOpenChat;
  final VoidCallback onForegroundChat;

  static const enabled = bool.fromEnvironment('ENABLE_PUSH');
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<RemoteMessage>? _foreground;
  bool _closed = false;
  bool _ready = false;

  Future<void> start(String locale) async {
    if (!enabled || _closed || _ready || (!Platform.isAndroid && !Platform.isIOS)) return;
    _ready = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) return;

      final language = ['de', 'fr', 'it', 'en'].contains(locale) ? locale : 'en';
      // iOS requires APNs setup before issuing an FCM token.
      if (Platform.isIOS && await messaging.getAPNSToken() == null) {
        // The token refresh listener still handles later registrations.
      } else {
        final token = await messaging.getToken();
        if (token != null && !_closed) await _register(token, language);
      }
      _tokens = messaging.onTokenRefresh.listen((token) {
        if (!_closed) unawaited(_register(token, language));
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
      _foreground = FirebaseMessaging.onMessage.listen((msg) {
        if (msg.data['type'] == 'chat') onForegroundChat();
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null && !_closed) _handleOpen(initial);
    } catch (error) {
      // Do not block account access if Firebase is unconfigured or temporarily offline.
      debugPrint('Push registration unavailable: $error');
    }
  }

  Future<void> _register(String token, String language) async {
    if (_closed || token.isEmpty) return;
    try {
      await api.registerPushDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        locale: language,
      );
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  void _handleOpen(RemoteMessage message) {
    if (_closed || message.data['type'] != 'chat') return;
    final id = message.data['conversation_id'];
    if (id is String && RegExp(r'^[0-9]+$').hasMatch(id)) {
      onOpenChat(id);
    }
  }

  Future<void> unregister() async {
    if (!_ready || !enabled) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await api.unregisterPushDevice(token);
    } catch (error) {
      debugPrint('Push deregistration not confirmed: $error');
    }
  }

  void dispose() {
    _closed = true;
    _tokens?.cancel();
    _opened?.cancel();
    _foreground?.cancel();
  }
}
