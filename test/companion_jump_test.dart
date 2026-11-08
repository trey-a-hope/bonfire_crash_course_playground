import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and the [companion], and returns
/// once every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Companion companion,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [companion],
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

/// What happened while the game ran.
class _Watch {
  /// True if the companion was ever in the air.
  bool jumped = false;

  /// True if, on every frame in the air, the jump animation was playing.
  bool jumpAnimationInAir = true;

  /// The companion's facing (flipped means facing left) on its frames in
  /// the air.
  final flips = <bool>{};
}

/// Advances the game by [seconds], one 16 ms frame at a time, watching the
/// [companion]'s jump.
Future<_Watch> _run(
  WidgetTester tester,
  double seconds,
  Companion companion,
) async {
  final watch = _Watch();
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    // Ignore the very first frames of a jump, while the take-off crouch
    // plays on top.
    if (companion.jumper.isJumping && companion.velocity.y.abs() > 20) {
      watch.jumped = true;
      final animation = companion.animation!;
      if (animation.currentType != SimpleAnimationEnum.custom) {
        watch.jumpAnimationInAir = false;
      }
      watch.flips.add(animation.isFlipHorizontally);
    }
  }
  return watch;
}

/// The y of a character standing on the ground (row 8) or on a one-tile
/// block (row 7), at its top-left.
const _groundY = 7 * TILE_SIZE;
const _stepY = 6 * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('jumps up a one-tile step after the hero, facing right', (
    tester,
  ) async {
    // The hero stands on the low block (columns 5-6), the companion on the
    // ground to its left.
    final hero = Hero(Vector2(6 * TILE_SIZE, _stepY));
    final companion = Companion(Vector2(2.5 * TILE_SIZE, _groundY));
    await _pumpGame(tester, hero: hero, companion: companion);
    await _run(tester, 0.5, companion);
    companion.startFollowing();

    final watch = await _run(tester, 3, companion);
    expect(watch.jumped, isTrue);
    expect(watch.jumpAnimationInAir, isTrue);
    expect(watch.flips, {false});
    // Up on the block, beside the hero, and standing still.
    expect(companion.y, closeTo(_stepY, 1));
    expect(companion.jumper.isJumping, isFalse);
    expect(companion.velocity.x, 0);
    // It never pushed the hero.
    expect(hero.x, 6 * TILE_SIZE);
  });

  testWidgets('jumps up from the right facing left', (tester) async {
    final hero = Hero(Vector2(5 * TILE_SIZE, _stepY));
    final companion = Companion(Vector2(8 * TILE_SIZE, _groundY));
    await _pumpGame(tester, hero: hero, companion: companion);
    await _run(tester, 0.5, companion);
    companion.startFollowing();

    final watch = await _run(tester, 3, companion);
    expect(watch.jumped, isTrue);
    expect(watch.flips, {true});
    expect(companion.y, closeTo(_stepY, 1));
    expect(hero.x, 5 * TILE_SIZE);
  });

  testWidgets('waits below a ledge too high to jump', (tester) async {
    // Column 14 is three tiles tall.
    final hero = Hero(Vector2(14 * TILE_SIZE, 4 * TILE_SIZE));
    final companion = Companion(Vector2(11.5 * TILE_SIZE, _groundY));
    await _pumpGame(tester, hero: hero, companion: companion);
    await _run(tester, 0.5, companion);
    companion.startFollowing();

    final watch = await _run(tester, 3, companion);
    expect(watch.jumped, isFalse);
    expect(companion.y, closeTo(_groundY, 1));
    expect(companion.velocity.x, 0);
  });

  testWidgets("doesn't jump while waiting for its first talk", (tester) async {
    final hero = Hero(Vector2(6 * TILE_SIZE, _stepY));
    // Out of talking range, so it never starts following.
    final companion = Companion(Vector2(2 * TILE_SIZE, _groundY));
    await _pumpGame(tester, hero: hero, companion: companion);

    final watch = await _run(tester, 2, companion);
    expect(companion.isFollowing, isFalse);
    expect(watch.jumped, isFalse);
  });
}
