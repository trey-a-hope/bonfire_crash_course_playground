import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/brass_key.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and the [key], and returns once
/// every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required BrassKey key,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [key],
        map: WorldMapBySpritefusion(WorldMapReader.fromAsset(MAP_ONE)),
        onReady: (_) => ready = true,
      ),
    ),
  );
  // Images and the map load with real async work, so give it real time
  // outside the test's fake clock.
  for (var i = 0; i < 50 && !ready; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready, isTrue, reason: 'the game never became ready');
}

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Walks the [hero] right into the [key] and returns on the frame it is
/// picked up.
Future<void> _walkIntoKey(WidgetTester tester, Hero hero, BrassKey key) async {
  hero.moveRight();
  for (var i = 0; i < 200 && !key.isPickedUp; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  hero.stop();
  expect(key.isPickedUp, isTrue, reason: 'the hero never reached the key');
}

/// The key's resting top edge on flat ground at row 7.
final _restY = 8 * TILE_SIZE - BrassKey.keySize.y;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the key bobs 3 px up and back, smoothly and forever', (
    tester,
  ) async {
    // Flat ground at columns 16-18, with the hero far away.
    final key = BrassKey(Vector2(17, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: Hero(Vector2(3, 7) * TILE_SIZE), key: key);

    final startX = key.x;

    // Watch two full loops (2 x 1.2 s), then two more much later.
    for (final wait in [0.0, 10.0]) {
      await _run(tester, wait);
      var top = key.y;
      var bottom = key.y;
      var biggestStep = 0.0;
      var last = key.y;
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (key.y < top) top = key.y;
        if (key.y > bottom) bottom = key.y;
        final step = (key.y - last).abs();
        if (step > biggestStep) biggestStep = step;
        last = key.y;
      }
      // From resting on the ground to 3 px above it.
      // (Frames don't land exactly on the turns, so allow half a pixel.)
      expect(bottom, closeTo(_restY, 0.5));
      expect(top, closeTo(_restY - BrassKey.bobHeight, 0.5));
      // Smooth: never more than a fraction of a pixel in one frame.
      expect(biggestStep, lessThan(0.3));
    }
    // It only moves up and down.
    expect(key.x, startX);
  });

  testWidgets('picking up the key marks it straight away, then it pops', (
    tester,
  ) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final key = BrassKey(Vector2(17, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, key: key);
    await _run(tester, 0.5);

    await _walkIntoKey(tester, hero, key);
    // Picked up and switched off at once, but still in the world to pop.
    expect(key.sensor.enabled, isFalse);
    expect(key.isMounted, isTrue);
    final startY = key.y;
    // By the next frame the endless bob is gone, so only the pop moves it.
    await tester.pump(const Duration(milliseconds: 16));
    expect(key.children.whereType<MoveByEffect>(), isEmpty);
    final startCenterX = key.toAbsoluteRect().center.dx;

    // Halfway through the pop it has risen, grown and faded, and stays
    // centred where it was.
    await _run(tester, BrassKey.popDuration / 2);
    expect(key.y, lessThan(startY - 4));
    expect(key.scale.x, greaterThan(1.1));
    expect(key.opacity, lessThan(0.9));
    expect(key.toAbsoluteRect().center.dx, closeTo(startCenterX, 0.5));

    // Then it is gone from the game.
    await _run(tester, BrassKey.popDuration);
    expect(key.isMounted, isFalse);
  });

  testWidgets('the pop ends half a tile up at 1.5x, faded out', (
    tester,
  ) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final key = BrassKey(Vector2(17, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, key: key);
    await _run(tester, 0.5);
    await _walkIntoKey(tester, hero, key);
    final startCenter = key.toAbsoluteRect().center;

    // Just before the end: the last frame the key is still in the world.
    await _run(tester, BrassKey.popDuration - 0.02);
    expect(key.isMounted, isTrue);
    expect(key.scale.x, closeTo(BrassKey.popScale, 0.05));
    expect(key.opacity, lessThan(0.1));
    final center = key.toAbsoluteRect().center;
    expect(startCenter.dy - center.dy, closeTo(BrassKey.popRise, 1));
    expect(center.dx, closeTo(startCenter.dx, 0.5));
  });

  testWidgets('the key cannot be picked up twice during the pop', (
    tester,
  ) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final key = BrassKey(Vector2(17, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, key: key);
    await _run(tester, 0.5);
    await _walkIntoKey(tester, hero, key);

    // The hero keeps walking back and forth through the key while it pops.
    var mostPops = 0;
    for (var i = 0; i < 25; i++) {
      i.isEven ? hero.moveLeft() : hero.moveRight();
      await tester.pump(const Duration(milliseconds: 16));
      if (!key.isMounted) break;
      final pops = key.children.whereType<SequenceEffect>().length;
      if (pops > mostPops) mostPops = pops;
    }
    hero.stop();

    // Only ever one pop, and the sensor stayed off.
    expect(mostPops, 1);
    expect(key.sensor.enabled, isFalse);
    await _run(tester, 0.5);
    expect(key.isMounted, isFalse);
  });
}
