import 'dart:io';

import 'package:bonfire/base/listener_game_widget.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/backgrounds/parallax_background.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests for BCC-34: the cave background behind both maps. The first group
// checks the image files, the second the parallax in the running game.
// (map_navigation_test.dart checks that map 02 has the same background.)

/// Reads a PNG's width and height from its header.
(int, int) _pngSize(String path) {
  final bytes = File('assets/images/$path').readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

/// Pumps the real game screen and returns its game once map 01 and its
/// background have loaded.
Future<BonfireGame> _pumpGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: GameScreen()));
  final game = tester
      .widget<ListenerGameWidget>(
        find.byWidgetPredicate((w) => w is ListenerGameWidget),
      )
      .game as BonfireGame;
  // Images and the map load with real async work, so give it real time
  // outside the test's fake clock.
  for (var i = 0; i < 50 && game.player?.isMounted != true; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(game.player?.isMounted, isTrue, reason: 'the game never loaded');
  // The background keeps loading a little after the hero appears.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 16));
  return game;
}

/// The cave's parallax, once the background has added it.
ParallaxComponent _cave(BonfireGame game) =>
    game.background!.children.whereType<ParallaxComponent>().single;

void main() {
  group('cave images', () {
    test('there are four layers, back to front', () {
      expect(
        ParallaxBackground.layers,
        [CAVE_BACK, CAVE_FAR, CAVE_MID, CAVE_NEAR],
      );
    });

    for (final layer in ParallaxBackground.layers) {
      test('$layer is a 960x320 image', () {
        expect(File('assets/images/$layer').existsSync(), isTrue,
            reason: '$layer is missing');
        expect(_pngSize(layer), (960, 320));
      });
    }

    test('the old sky background is gone', () {
      for (final name in ['sky', 'clouds', 'mountains', 'hills']) {
        expect(
          File('assets/images/background/$name.png').existsSync(),
          isFalse,
          reason: '$name.png is no longer used',
        );
      }
    });
  });

  group('cave parallax in the game', () {
    // Each test runs in its own fake-async zone. A cached asset load from an
    // earlier test never completes in a later one, so start every test cold.
    setUp(() {
      rootBundle.clear();
      Flame.assets.clearCache();
    });

    testWidgets('map 01 shows all four cave layers', (tester) async {
      final game = await _pumpGameScreen(tester);

      expect(game.background, isA<ParallaxBackground>());
      final cave = _cave(game);
      expect(cave, isA<CameraParallaxComponent>());
      expect(cave.parallax!.layers, hasLength(4));
    });

    testWidgets('each layer slides faster than the one behind it',
        (tester) async {
      final game = await _pumpGameScreen(tester);

      final speeds = [
        for (final layer in _cave(game).parallax!.layers)
          layer.velocityMultiplier.x * ParallaxBackground.baseVelocity.x,
      ];
      // About 15, 24, 39 and 62 (see ParallaxBackground).
      expect(speeds[0], closeTo(15, 1));
      expect(speeds[3], closeTo(62, 1));
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], greaterThan(speeds[i - 1]));
      }
      // Nothing moves up or down.
      expect(ParallaxBackground.baseVelocity.y, 0);
    });

    testWidgets('quick resizes leave exactly one cave parallax',
        (tester) async {
      final game = await _pumpGameScreen(tester);
      final size = game.size.clone();

      // Several resizes in a row, each starting a reload before the last
      // one has finished (as when a window is dragged bigger).
      for (var i = 1; i <= 4; i++) {
        game.onGameResize(size + Vector2.all(i * 10));
      }
      game.onGameResize(size);
      // Let every reload finish, then a frame to mount what they added.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Only the newest reload's parallax is left, with all four layers.
      final caves = game.background!.children.whereType<ParallaxComponent>();
      expect(caves, hasLength(1));
      expect(caves.single.parallax!.layers, hasLength(4));
    });

    testWidgets('the cave stands still while the camera does', (tester) async {
      final game = await _pumpGameScreen(tester);
      // Let the camera settle on the hero first.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final layers = _cave(game).parallax!.layers;
      final before = [for (final l in layers) l.currentOffset().clone()];
      final camera = game.camera.position.clone();

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Unlike the old clouds, no layer scrolls on its own.
      expect(game.camera.position, camera);
      for (var i = 0; i < layers.length; i++) {
        expect(layers[i].currentOffset(), before[i]);
      }
    });
  });
}
