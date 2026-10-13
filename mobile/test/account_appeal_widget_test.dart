import 'package:dilemin/core/api_client.dart';
import 'package:dilemin/core/models.dart';
import 'package:dilemin/features/moderation/account_appeal_review_screen.dart';
import 'package:dilemin/features/security/account_appeal_screen.dart';
import 'package:dilemin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class AppealApiStub extends ApiClient {
  AppealApiStub({this.appeal, this.pending = const []}) : super(client: http.Client());

  AccountAppeal? appeal;
  List<PendingAppeal> pending;
  int submitted = 0;
  String? recordedDecision;

  @override
  Future<AccountAppeal?> accountAppeal() async => appeal;

  @override
  Future<void> submitAccountAppeal(String statement) async {
    submitted++;
    appeal = AccountAppeal(id: '9', status: 'pending', statement: statement);
  }

  @override
  Future<List<PendingAppeal>> pendingAppeals() async => pending;

  @override
  Future<void> reviewAccountAppeal(String appealId, String decision, String note) async {
    recordedDecision = decision;
    pending = [];
  }
}

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('suspended member can submit one appeal and see pending status', (tester) async {
    final api = AppealApiStub();
    await tester.pumpWidget(localized(AccountAppealScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Your appeal statement'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Please review the suspension in light of my additional evidence.');
    await tester.tap(find.text('Submit appeal'));
    await tester.pumpAndSettle();

    expect(api.submitted, 1);
    expect(find.text('Your appeal is under review.'), findsOneWidget);
    expect(find.text('Submit appeal'), findsNothing);
    api.close();
  });

  testWidgets('rejected appeal displays the review note without a second submission', (tester) async {
    final api = AppealApiStub(appeal: const AccountAppeal(
      id: '13', status: 'rejected',
      statement: 'I disagree with the suspension and provided context.',
      reviewNote: 'We reviewed the evidence and upheld the suspension.',
    ));
    await tester.pumpWidget(localized(AccountAppealScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Your appeal was declined.'), findsOneWidget);
    expect(find.text('We reviewed the evidence and upheld the suspension.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    api.close();
  });

  testWidgets('moderator must provide a documented decision before restoration', (tester) async {
    final api = AppealApiStub(pending: const [
      PendingAppeal(id: '18', userId: '42', name: 'Example Person',
        statement: 'Please review the account suspension, I have more context.'),
    ]);
    await tester.pumpWidget(localized(AccountAppealReviewScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Example Person'), findsOneWidget);
    await tester.tap(find.text('Restore access').first);
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Restore access').last;
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Reviewed evidence supports restoration.');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.recordedDecision, 'restored');
    expect(find.text('No pending appeals.'), findsOneWidget);
    api.close();
  });
}
