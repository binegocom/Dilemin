import 'package:dilemin/ui/premium_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('animated empty state is accessible and does not invent people',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: PremiumStatePanel(
        message: 'No verified online people yet',
        icon: Icons.radar_rounded,
      ),
    )));
    expect(find.text('No verified online people yet'), findsOneWidget);
    expect(find.byType(PremiumStatePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry state supports reduced motion and triggers refresh',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: PremiumStatePanel(
          message: 'Unable to connect',
          icon: Icons.wifi_off_rounded,
          retryLabel: 'Retry',
          onRetry: () => attempts++,
        )),
      ),
    ));
    await tester.tap(find.text('Retry'));
    expect(attempts, 1);
    expect(tester.takeException(), isNull);
  });
}
