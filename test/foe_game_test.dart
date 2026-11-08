import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with just the [hero] and the [foe], and returns
/// once every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Foe foe,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [foe],
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

/// Lets the game settle for a few frames, so the camera has worked out what
/// is on screen (attacks only hit what is on screen).
Future<void> _settle(WidgetTester tester) => _run(tester, 0.2);

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Presses [key] on the [hero], as the keyboard would.
void _press(Hero hero, LogicalKeyboardKey key) {
  hero.onKeyboard(
    KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyS,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
    {key},
  );
}

/// The ground under row 7 of map 01 starts at row 8.
const _groundY = 8 * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('falls onto the ground and stands there', (tester) async {
    // Two tiles above its spawn tile, so gravity has to bring it down.
    final foe = Foe(Vector2(28, 5) * TILE_SIZE);
    // The hero is nearby, so the foe is on screen (off screen it stays put).
    await _pumpGame(tester, hero: Hero(Vector2(24, 7) * TILE_SIZE), foe: foe);
    await _run(tester, 3);

    expect(foe.isMounted, isTrue);
    expect(foe.rectCollision.bottom, closeTo(_groundY, 1));
  });

  testWidgets('bites the hero once a second while next to them',
      (tester) async {
    // The hero's back is to the wall at columns 19-22, so the bite's
    // knockback can't move it away and the foe stays next to it.
    final hero = Hero(Vector2(23, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, foe: Foe(Vector2(24, 7) * TILE_SIZE));

    // The first bite lands right away...
    await _run(tester, 0.5);
    expect(hero.life.value, 90);
    // ...and the next one only after a second.
    await _run(tester, 0.7);
    expect(hero.life.value, 80);
  });

  testWidgets("the hero's melee attack hurts it", (tester) async {
    // Back to the wall, as above, so the foe's first bite can't knock the
    // hero out of reach before it swings.
    final hero = Hero(Vector2(23, 7) * TILE_SIZE);
    final foe = Foe(Vector2(24, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, foe: foe);

    // Wait out the first bite's knockback, after which the hero faces the
    // foe again.
    await _run(tester, 0.5);
    _press(hero, LogicalKeyboardKey.keyS);
    await _run(tester, 0.5);

    expect(foe.life.value, 80);
  });

  testWidgets("the hero's range attack hurts it", (tester) async {
    // Three tiles away, facing the foe.
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    final foe = Foe(Vector2(28, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, foe: foe);

    // The projectile's sheet loads only when it is fired. Load it now, on
    // real async time, or the projectile would wait forever in the test.
    await tester.runAsync(() => Flame.images.load(WIZARD_PROJECTILE_RIGHT));
    await _settle(tester);
    _press(hero, LogicalKeyboardKey.keyW);
    await _run(tester, 1.5);

    expect(foe.life.value, 85);
  });

  testWidgets('other enemies cannot hurt it', (tester) async {
    final foe = Foe(Vector2(28, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: Hero(Vector2(24, 7) * TILE_SIZE), foe: foe);

    foe.life.handleAttack(AttackOriginEnum.ENEMY, 50, null);

    expect(foe.life.value, 100);
  });

  testWidgets('plays its death animation, then is removed', (tester) async {
    final foe = Foe(Vector2(28, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: Hero(Vector2(24, 7) * TILE_SIZE), foe: foe);

    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 100, null);
    await _run(tester, 0.1);
    expect(foe.isDead, isTrue);
    expect(foe.isMounted, isTrue, reason: 'still playing the death animation');

    // 4 frames of 0.1 s.
    await _run(tester, 0.5);
    expect(foe.isMounted, isFalse);
  });

  group('behaviors', () {
    /// The foe paces between these, as it does on map 01.
    Foe patrollingFoe(Vector2 tile) => Foe(
          tile * TILE_SIZE,
          patrolMinX: 24 * TILE_SIZE,
          patrolMaxX: 29 * TILE_SIZE,
        );

    testWidgets('patrols left and right while it cannot see the hero',
        (tester) async {
      final foe = patrollingFoe(Vector2(28, 7));
      // Eight tiles away: on screen, but out of the foe's sight.
      final hero = Hero(Vector2(20, 7) * TILE_SIZE);
      await _pumpGame(tester, hero: hero, foe: foe);

      // Walks left to its left end: 4 tiles at 20 px/s takes about 6.4 s.
      await _run(tester, 6.8);
      expect(foe.x, closeTo(24 * TILE_SIZE, 2));
      expect(foe.rectCollision.bottom, closeTo(_groundY, 1));

      // Pauses there for a second, then turns around and heads back right.
      await _run(tester, 2);
      expect(foe.x, greaterThan(24 * TILE_SIZE + 10));
      expect(foe.rectCollision.bottom, closeTo(_groundY, 1));
      expect(hero.life.value, 100);
    });

    testWidgets('stops patrolling and chases the hero once it sees them',
        (tester) async {
      // The patrol heads left first; the hero is to the right.
      final foe = patrollingFoe(Vector2(25, 7));
      final hero = Hero(Vector2(29, 7) * TILE_SIZE);
      await _pumpGame(tester, hero: hero, foe: foe);

      await _run(tester, 4);
      expect(foe.x, greaterThan(25 * TILE_SIZE));
      expect(hero.life.value, lessThan(100));
    });

    testWidgets('falls at full speed while chasing', (tester) async {
      // Two tiles up in the open, with the hero in sight below.
      final foe = patrollingFoe(Vector2(23, 5));
      await _pumpGame(tester, hero: Hero(Vector2(25, 7) * TILE_SIZE), foe: foe);

      // Gravity (300 px/s²) brings it down 64 px in about 0.65 s. If the
      // chase cancelled the fall speed each tick, it would take over 10 s.
      await _run(tester, 1);
      expect(foe.rectCollision.bottom, closeTo(_groundY, 1));
    });

    testWidgets('stands still and does not bite while a scene runs',
        (tester) async {
      // Three tiles away: in sight, but well over a second's walk from a
      // bite, so nothing lands before the scene starts.
      final hero = Hero(Vector2(25, 7) * TILE_SIZE);
      final foe = patrollingFoe(Vector2(28, 7));
      await _pumpGame(tester, hero: hero, foe: foe);

      // A scene that never finishes, like a dialogue left open.
      foe.gameRef.startScene([
        AwaitSceneAction(wait: () => Completer<void>().future),
      ]);
      await _run(tester, 0.05);
      final startX = foe.x;
      await _run(tester, 3);

      expect(hero.life.value, 100);
      expect(foe.x, startX);
    });

    testWidgets('stops biting once the hero is dead', (tester) async {
      final hero = Hero(Vector2(27, 7) * TILE_SIZE);
      await _pumpGame(tester, hero: hero, foe: Foe(Vector2(28, 7) * TILE_SIZE));

      await _run(tester, 0.5);
      expect(hero.life.value, 90);
      hero.life.handleAttack(AttackOriginEnum.ENEMY, 90, null);
      expect(hero.isDead, isTrue);
      final lifeAtDeath = hero.life.value;

      await _run(tester, 3);
      expect(hero.life.value, lifeAtDeath);
    });

    testWidgets('pauses its behaviors when it dies', (tester) async {
      final foe = patrollingFoe(Vector2(28, 7));
      await _pumpGame(tester, hero: Hero(Vector2(20, 7) * TILE_SIZE), foe: foe);
      expect(foe.behaviorIsRunning, isTrue);

      foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 100, null);
      await _run(tester, 0.1);

      expect(foe.behaviorIsRunning, isFalse);
    });
  });
}
