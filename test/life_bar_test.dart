import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/life_bar_utils.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and the [foe], and returns once
/// every asset has loaded and the game is running.
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

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A hero by the sign and a foe that stands still at the far end of the
/// map, out of sight, so neither hurts the other unless a test says so.
(Hero, Foe) _fighters() => (
      Hero(Vector2(2 * TILE_SIZE, 7 * TILE_SIZE)),
      Foe(Vector2(28 * TILE_SIZE, 7 * TILE_SIZE)),
    );

/// Checks the bar's look, shared by the hero and the foe: 24 x 4, dark
/// outline and empty part, 1 px border, above the head, no number.
void _expectBarStyle(BarLifeComponent bar, Color fill) {
  expect(bar.colors, [fill]);
  expect(bar.size, Vector2(24, 4));
  expect(bar.backgroundColor, LifeBarStyle.outlineColor);
  expect(bar.borderColor, LifeBarStyle.outlineColor);
  expect(bar.borderWidth, 1);
  expect(bar.drawPosition, BarLifeDrawPosition.top);
  expect(bar.position, Vector2(0, -2));
  expect(bar.showLifeText, isFalse);
}

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the hero has a green life bar over its head', (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    final bar = hero.lifeBar.barLife!;
    expect(bar.isMounted, isTrue);
    expect(bar.parent, hero);
    _expectBarStyle(bar, Hero.lifeBarColor);
    expect(Hero.lifeBarColor, const Color(0xFF69F0AE));
  });

  testWidgets('the shark has a red life bar over its head', (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    final bar = foe.lifeBar.barLife!;
    expect(bar.isMounted, isTrue);
    expect(bar.parent, foe);
    _expectBarStyle(bar, Foe.lifeBarColor);
    expect(Foe.lifeBarColor, const Color(0xFFFF5252));
  });

  testWidgets('both bars start full', (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    expect(hero.lifeBar.barLife!.life, hero.life.max);
    expect(foe.lifeBar.barLife!.life, foe.life.max);
  });

  testWidgets("the hero's bar shrinks as it loses life", (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    hero.life.handleAttack(AttackOriginEnum.WORLD, 30, null);
    await _run(tester, 0.1);

    expect(hero.life.value, 70);
    expect(hero.lifeBar.barLife!.life, 70);
  });

  testWidgets("the shark's bar shrinks as it loses life", (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 20, null);
    await _run(tester, 0.5);
    expect(foe.life.value, 80);
    expect(foe.lifeBar.barLife!.life, 80);

    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 15, null);
    await _run(tester, 0.5);
    expect(foe.lifeBar.barLife!.life, 65);
  });

  testWidgets("the shark's bar disappears the moment it dies", (
    tester,
  ) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);
    final bar = foe.lifeBar.barLife!;

    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 100, null);
    await tester.pump(const Duration(milliseconds: 16));

    expect(foe.isDead, isTrue);
    // The foe is still playing its death animation, but its bar is gone.
    expect(foe.isMounted, isTrue);
    expect(bar.isMounted, isFalse);
    expect(foe.children.whereType<BarLifeComponent>(), isEmpty);

    // And it doesn't come back once the foe is removed.
    await _run(tester, 2);
    expect(foe.isMounted, isFalse);
    expect(bar.isMounted, isFalse);
  });

  testWidgets("the hero's bar stays, empty, when it dies", (tester) async {
    final (hero, foe) = _fighters();
    await _pumpGame(tester, hero: hero, foe: foe);

    hero.life.handleAttack(AttackOriginEnum.WORLD, 100, null);
    await _run(tester, 0.5);

    expect(hero.isDead, isTrue);
    expect(hero.lifeBar.barLife!.isMounted, isTrue);
    expect(hero.lifeBar.barLife!.life, 0);
  });
}
