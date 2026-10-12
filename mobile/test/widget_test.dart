import 'package:dilemin/features/radar/radar_canvas.dart';
import 'package:dilemin/core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty radar displays current account marker', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RadarCanvas(people: [], centerName: 'Robin')),
    ));
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('tapping radar marker opens a real person', (tester) async {
    OnlinePerson? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Center(child: SizedBox(width: 320, height: 320,
        child: RadarCanvas(people: const [OnlinePerson(id: '42', name: 'Alex')],
          centerName: 'Robin', onPersonTap: (person) => selected = person),
      )),
    )));
    await tester.tap(find.text('A'));
    expect(selected?.id, '42');
  });
}

