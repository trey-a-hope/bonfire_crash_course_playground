import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with just the [hero], and returns once every
/// asset has loaded and the game is running.
Future<void> _pumpGame(WidgetTester tester, Hero hero) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
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

/// How long the whole death animation takes, plus a little to spare.
const _deathSeconds = 4 * Hero.deathStepTime + 0.1;

/// A hero standing on the ground by the sign.
Future<Hero> _standingHero(WidgetTester tester) async {
  final hero = Hero(Vector2(2 * TILE_SIZE, 7 * TILE_SIZE));
  await _pumpGame(tester, hero);
  // Let it land first.
  await _run(tester, 0.5);
  return hero;
}

/// Hurts the hero for all its life, as the world (no knockback).
void _kill(Hero hero) =>
    hero.life.handleAttack(AttackOriginEnum.WORLD, hero.life.max, null);

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the death animation plays once, then the hero stays down', (
    tester,
  ) async {
    final hero = await _standingHero(tester);
    _kill(hero);
    expect(hero.isDead, isTrue);

    // Part way through, the death animation is still playing.
    await _run(tester, 2 * Hero.deathStepTime);
    expect(hero.deadAnimation, isNull);
    expect(hero.animation!.fastAnimationcurrentIndex, greaterThan(0));

    // Once it ends, the hero holds the last frame and doesn't get up.
    await _run(tester, _deathSeconds);
    expect(hero.deadAnimation, DEAD_RIGHT);
    expect(hero.animation!.currentType, SimpleAnimationEnum.custom);
    await _run(tester, 2);
    expect(hero.deadAnimation, DEAD_RIGHT);
    expect(hero.animation!.currentType, SimpleAnimationEnum.custom);
  });

  testWidgets('a hero facing left falls facing left', (tester) async {
    final hero = await _standingHero(tester);
    hero.hDirection = Direction.left;
    _kill(hero);

    await _run(tester, _deathSeconds);
    expect(hero.deadAnimation, DEAD_LEFT);
  });

  testWidgets('a dead hero ignores walking, jumping and attacking', (
    tester,
  ) async {
    final hero = await _standingHero(tester);
    // Walking right when it dies.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await _run(tester, 0.2);
    expect(hero.velocity.x, greaterThan(0));

    _kill(hero);
    await _run(tester, 0.1);
    final position = hero.position.clone();
    expect(hero.velocity.x, 0);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await _run(tester, 0.3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await _run(tester, 1);

    expect(hero.position.x, closeTo(position.x, 0.01));
    expect(hero.position.y, closeTo(position.y, 0.01));
    expect(hero.velocity.x, 0);
    // No melee hitbox and no magic bolt were made.
    expect(hero.gameRef.query<FlyingAttackGameObject>(), isEmpty);
    expect(hero.gameRef.query<DamageHitbox>(), isEmpty);
  });

  testWidgets('a hero who dies in the air falls to the ground', (
    tester,
  ) async {
    final hero = await _standingHero(tester);
    final groundY = hero.position.y;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _run(tester, 0.15);
    expect(hero.position.y, lessThan(groundY));

    _kill(hero);
    await _run(tester, 2);
    expect(hero.position.y, closeTo(groundY, 0.5));
  });
}
