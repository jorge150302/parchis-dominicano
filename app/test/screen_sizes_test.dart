// Every main screen laid out on Android phones and tablets, at normal and
// large text (accessibility 130%). Fails on any layout overflow, listing
// each screen, size and text scale where it happens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/screen_harness.dart';

/// Logical sizes (dp) of common Android devices.
const devices = {
  'small phone 320x568': Size(320, 568),
  'phone 360x800': Size(360, 800),
  'large phone 412x915': Size(412, 915),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

const textScales = [1.0, 1.3];

void main() {
  setUpAll(() async {
    await loadRoboto();
    muteAudioPlugins();
  });

  Future<List<String>> layoutProblems(
    WidgetTester tester,
    Screen screen,
    Size size,
    double textScale,
  ) async {
    final problems = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final what = details.exceptionAsString().split('\n').first;
      // "The relevant error-causing widget was: Row  lib/…dart:123:9"
      final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0);
      problems.add(where == null ? what : '$what ($where)');
    };
    try {
      await pumpScreen(tester, screen, size, textScale: textScale);
      // An empty screen would pass any layout check.
      if (screen.shows().evaluate().isEmpty) problems.add('expected content is not on screen');
    } finally {
      FlutterError.onError = previous;
    }
    await clearScreen(tester);
    return problems;
  }

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name lays out on every device and text size', (tester) async {
      final failures = <String>[];
      for (final MapEntry(key: device, value: size) in devices.entries) {
        for (final scale in textScales) {
          for (final p in await layoutProblems(tester, screen, size, scale)) {
            failures.add('$device, text ${(scale * 100).round()}%: $p');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.toSet().join('\n'));
    });
  }
}
