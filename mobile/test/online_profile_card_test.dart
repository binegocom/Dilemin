import 'package:dilemin/core/api_client.dart';
import 'package:dilemin/core/models.dart';
import 'package:dilemin/features/directory/online_profile_card.dart';
import 'package:dilemin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  late ApiClient api;

  setUp(() {
    api = ApiClient(client: MockClient((_) async {
      throw StateError('No network requests are expected for an unphotographed profile.');
    }));
  });

  tearDown(() => api.close());

  Widget card({required double width, required double height, required VoidCallback onTap}) {
    return MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: OnlineProfileCard(
              api: api,
              person: const OnlinePerson(id: '7', name: 'Alex'),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('authorized online profile tile opens its profile', (tester) async {
    var taps = 0;
    await tester.pumpWidget(card(width: 160, height: 180, onTap: () => taps++));
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Jetzt online'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('online-profile-7')));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small tiles fit without overflow or requiring profile photos', (tester) async {
    await tester.pumpWidget(card(width: 110, height: 120, onTap: () {}));
    expect(find.text('Alex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
