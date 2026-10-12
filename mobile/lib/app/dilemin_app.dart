import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/models.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/email_verification_screen.dart';
import '../features/shell/home_shell.dart';
import '../l10n/app_localizations.dart';

class DileminApp extends StatefulWidget {
  const DileminApp({super.key});

  @override
  State<DileminApp> createState() => _DileminAppState();
}

class _DileminAppState extends State<DileminApp> {
  static const _tokenKey = 'dilemin_api_token';
  final _store = const FlutterSecureStorage();
  late final ApiClient _api = ApiClient(client: http.Client());
  SessionUser? _user;
  bool _loading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _store.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _api.token = token;
        try {
          _user = await _api.me();
        } on ApiException catch (error) {
          if (error.statusCode != 401) rethrow;
          await _store.delete(key: _tokenKey);
          _api.token = null;
        }
      }
      if (mounted) setState(() { _loadError = false; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loadError = true; _loading = false; });
    }
  }

  Future<void> _signedIn(String token, SessionUser user) async {
    await _store.write(key: _tokenKey, value: token);
    _api.token = token;
    if (mounted) setState(() => _user = user);
  }

  Future<void> _signedOut() async {
    try {
      await _api.logout();
    } catch (_) {
      // A revoked/expired or unreachable token must still be cleared locally.
    } finally {
      _api.token = null;
      await _store.delete(key: _tokenKey);
      if (mounted) setState(() => _user = null);
    }
  }

  Future<void> _expired() async {
    _api.token = null;
    await _store.delete(key: _tokenKey);
    if (mounted) setState(() => _user = null);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dılêmın',
      debugShowCheckedModeBanner: false,
      localeResolutionCallback: (device, supported) {
        for (final locale in supported) {
          if (device?.languageCode == locale.languageCode) return locale;
        }
        return const Locale('en');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA4B86),
          brightness: Brightness.dark,
          surface: const Color(0xFF121426),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1D30),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loadError
              ? Builder(builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Scaffold(body: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.connectionError),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () {
                        setState(() => _loading = true);
                        _restoreSession();
                      }, child: Text(l10n.retry)),
                    ],
                  )));
                })
              : _user == null
                  ? AuthScreen(api: _api, onAuthenticated: _signedIn)
                  : !_user!.emailVerified
                    ? EmailVerificationScreen(api: _api,
                        onVerified: (user) => setState(() => _user = user),
                        onSignOut: _signedOut)
                    : HomeShell(
                      api: _api,
                      user: _user!,
                      onUserChanged: (user) => setState(() => _user = user),
                      onSignOut: _signedOut,
                      onSessionExpired: _expired,
                    ),
    );
  }
}
