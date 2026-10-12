import 'package:dilemin/features/radar/radar_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty radar displays current account marker', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RadarCanvas(people: [], centerName: 'Robin')),
    ));
    expect(find.text('R'), findsOneWidget);
  });
}
