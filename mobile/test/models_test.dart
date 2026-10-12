import 'package:flutter_test/flutter_test.dart';
import 'package:dilemin/core/models.dart';
import 'package:dilemin/features/radar/radar_canvas.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('online person exposes only public account data', () {
    final person = OnlinePerson.fromJson(const {
      'id': 57,
      'display_name': 'Alex',
    });
    expect(person.id, '57');
    expect(person.name, 'Alex');
  });

  test('schematic radar position is stable per user', () {
    final a = markerPosition('user-123', const Size(320, 320));
    final b = markerPosition('user-123', const Size(320, 320));
    expect(a, b);
    expect(a.dx, inInclusiveRange(0, 320));
    expect(a.dy, inInclusiveRange(0, 320));
  });
}
