// Golden screenshots of the key screens on a phone and a tablet. A visual
// change fails CI with the old image, the new one and their difference
// (uploaded as the "golden-failures" artifact). When the change is
// intended, add the `actualizar-capturas` label to the pull request:
// CI regenerates these images on Linux and commits them.
//
// Compared on Linux only: fonts rasterize differently on Windows and
// macOS, so goldens made there would never match CI. Set GOLDENS_ANY_OS=1
// to render them elsewhere for a look (don't commit those).
@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/screen_harness.dart';

const goldenScreens = ['main menu', 'player selection', 'online lobby', 'offline game (4 players)'];
const goldenDevices = {'phone': Size(360, 800), 'tablet': Size(800, 1280)};

final compareHere = Platform.isLinux || Platform.environment['GOLDENS_ANY_OS'] == '1';

/// Decodes every image asset for real before a screen is built: in fake
/// time images would stay blank. Done first because real time would also
/// let the game's audio players reach for a platform that tests lack.
Future<void> precacheAssetImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    imageCache.maximumSizeBytes = 512 << 20;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final images = manifest.listAssets().where((a) => RegExp(r'\.(png|jpe?g|webp)$').hasMatch(a));
    for (final asset in images) {
      final done = Completer<void>();
      final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) => done.complete(),
        onError: (e, _) => done.completeError(e),
      );
      stream.addListener(listener);
      await done.future.whenComplete(() => stream.removeListener(listener));
    }
  });
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    muteAudioPlugins();
  });

  for (final name in goldenScreens) {
    for (final MapEntry(key: device, value: size) in goldenDevices.entries) {
      final file = '${name.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_$device.png';
      testWidgets('$name on a $device looks as approved', (tester) async {
        await precacheAssetImages(tester);
        // 1:1 pixels keep the committed images small.
        await pumpScreen(tester, screens[name]!, size, devicePixelRatio: 1);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$file'));
        await clearScreen(tester);
      }, skip: !compareHere);
    }
  }
}
