import 'package:dilemin/ui/premium_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom tabs keep all four labels and update selected state',
      (tester) async {
    var selected = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PremiumNavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) => selected = index,
          labels: const ['Radar', 'Online', 'Chats', 'Account'],
        ),
      ),
    ));
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('premium-nav-2')));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('respects reduced motion and compact iPhone width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          bottomNavigationBar: PremiumNavigationBar(
            selectedIndex: 3,
            onDestinationSelected: (_) {},
            labels: const ['Radar', 'Online', 'Chats', 'Account'],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('premium-nav-3')), findsOneWidget);
  });
}
