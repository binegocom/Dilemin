import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('online status animation is a finite local Lottie composition', () async {
    final source = await rootBundle.loadString('assets/lottie/online_pulse.json');
    final parsed = jsonDecode(source) as Map<String, dynamic>;
    expect(parsed['fr'], greaterThan(0));
    expect(parsed['op'], greaterThan(parsed['ip'] as num));
    expect(parsed['layers'], isNotEmpty);
    expect(source, isNot(contains('http')));
  });

  test('Rive icon is packaged locally without runtime network dependency', () async {
    final bytes = await rootBundle.load('assets/rive/web_icons_pack.riv');
    expect(bytes.lengthInBytes, greaterThan(100));
  });
}
