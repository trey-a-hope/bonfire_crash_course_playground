import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/spikes.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and any other [components], and
/// returns once every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  List<GameComponent> components = const [],
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: components,
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

/// Advances the game by [seconds] and returns the highest point (smallest y)
/// the [hero] reached on the way.
Future<double> _runTrackingTop(
  WidgetTester tester,
  Hero hero,
  double seconds,
) async {
  var top = hero.y;
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (hero.y < top) top = hero.y;
  }
  return top;
}

/// Presses or releases [key] on the [hero], as the keyboard would.
void _key(Hero hero, LogicalKeyboardKey key, {bool down = true}) {
  final event = down
      ? KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: key,
          timeStamp: Duration.zero,
        )
      : KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: key,
          timeStamp: Duration.zero,
        ) as KeyEvent;
  hero.onKeyboard(event, down ? {key} : {});
}

/// Bites the [hero] as the foe's bite does: an ENEMY attack whose id is the
/// foe that bit. [biter] is never added to the game, so it can't bite back.
void _biteFrom(Hero hero, Foe biter) =>
    hero.life.handleAttack(AttackOriginEnum.ENEMY, 10, biter);

/// The ground under row 7 of map 01 starts at row 8.
const _groundY = 8 * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets(
      'a bite from the right knocks the hero left and up, then it '
      'lands', (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);
    final start = hero.position.clone();

    _biteFrom(hero, Foe(Vector2(26, 7) * TILE_SIZE));
    expect(hero.isKnockedBack, isTrue);
    final top = await _runTrackingTop(tester, hero, 1.5);

    expect(hero.x, lessThan(start.x - TILE_SIZE / 2), reason: 'pushed left');
    expect(top, lessThan(start.y - 8), reason: 'pushed up');
    expect(top, greaterThan(start.y - TILE_SIZE), reason: 'but not far up');
    expect(hero.isKnockedBack, isFalse);
    expect(hero.rectCollision.bottom, closeTo(_groundY, 1), reason: 'landed');
  });

  testWidgets('a bite from the left knocks the hero right and up',
      (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);
    final start = hero.position.clone();

    _biteFrom(hero, Foe(Vector2(24, 7) * TILE_SIZE));
    final top = await _runTrackingTop(tester, hero, 1.5);

    expect(hero.x, greaterThan(start.x + TILE_SIZE / 2),
        reason: 'pushed right');
    expect(top, lessThan(start.y - 8), reason: 'pushed up');
    expect(hero.rectCollision.bottom, closeTo(_groundY, 1), reason: 'landed');
  });

  testWidgets('the real bite knocks the hero away from the foe',
      (tester) async {
    final hero = Hero(Vector2(27, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: hero,
      components: [Foe(Vector2(28, 7) * TILE_SIZE)],
    );
    final startX = hero.x;

    // The first bite lands right away.
    await _run(tester, 0.4);

    expect(hero.life.value, 90);
    expect(hero.x, lessThan(startX - TILE_SIZE / 2));
  });

  testWidgets('the force is gone afterwards, so the hero does not drift',
      (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);

    _biteFrom(hero, Foe(Vector2(26, 7) * TILE_SIZE));
    await _run(tester, 1.5);
    final landed = hero.position.clone();
    await _run(tester, 1);

    expect(hero.velocity, Vector2.zero());
    expect(hero.position.x, closeTo(landed.x, 0.5));
    expect(hero.position.y, closeTo(landed.y, 0.5));
  });

  testWidgets('a bite next to a wall does not push the hero through it',
      (tester) async {
    // The wall at columns 19-22 is just to the left of tile 23.
    final hero = Hero(Vector2(23, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);

    _biteFrom(hero, Foe(Vector2(24, 7) * TILE_SIZE));
    await _run(tester, 1.5);

    expect(hero.x, greaterThanOrEqualTo(23 * TILE_SIZE - 1));
    expect(hero.rectCollision.bottom, closeTo(_groundY, 1));
  });

  testWidgets('a bite at the map edge does not push the hero off the map',
      (tester) async {
    // Map 01 is 30 tiles wide, so tile 29 is the last one.
    final hero = Hero(Vector2(29, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);

    _biteFrom(hero, Foe(Vector2(28, 7) * TILE_SIZE));
    await _run(tester, 1.5);

    expect(hero.x, lessThanOrEqualTo(29 * TILE_SIZE));
    expect(hero.rectCollision.bottom, closeTo(_groundY, 1));
  });

  testWidgets('pausing mid-knockback pauses it, and it ends after resuming',
      (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);

    _biteFrom(hero, Foe(Vector2(26, 7) * TILE_SIZE));
    await _run(tester, 0.1);
    hero.gameRef.pauseEngine();
    final pausedAt = hero.position.clone();
    await _run(tester, 2);

    expect(hero.position, pausedAt, reason: 'nothing moves while paused');
    expect(hero.isKnockedBack, isTrue, reason: 'paused, not finished');

    hero.gameRef.resumeEngine();
    await _run(tester, 1.5);
    expect(hero.isKnockedBack, isFalse);
    final landed = hero.position.clone();
    await _run(tester, 1);
    expect(hero.position.x, closeTo(landed.x, 0.5), reason: 'force removed');
  });

  testWidgets('the keyboard cannot move the hero until the knockback ends',
      (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);
    final startX = hero.x;

    // Knocked left, while holding right.
    _biteFrom(hero, Foe(Vector2(26, 7) * TILE_SIZE));
    _key(hero, LogicalKeyboardKey.keyD);
    await _run(tester, 0.2);
    expect(hero.x, lessThan(startX), reason: 'still going left');

    // Once it's over, holding right walks the hero right again.
    await _run(tester, 0.3);
    final afterX = hero.x;
    await _run(tester, 0.5);
    expect(hero.x, greaterThan(afterX));
    _key(hero, LogicalKeyboardKey.keyD, down: false);
  });

  testWidgets('the hero faces the foe again once the knockback ends',
      (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);

    // Bitten from the right: knocked left, then turns back to the right.
    _biteFrom(hero, Foe(Vector2(26, 7) * TILE_SIZE));
    await _run(tester, 0.5);
    expect(hero.hDirection, Direction.right);

    // Bitten from the left: knocked right, then turns back to the left.
    _biteFrom(hero, Foe(Vector2(23, 7) * TILE_SIZE));
    await _run(tester, 0.5);
    expect(hero.hDirection, Direction.left);
  });

  testWidgets('spikes hurt the hero without a knockback', (tester) async {
    final hero = Hero(Vector2(25, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero);
    await _run(tester, 0.5);
    final startX = hero.x;

    hero.life.handleAttack(
      AttackOriginEnum.WORLD,
      10,
      Spikes(Vector2(26, 7) * TILE_SIZE),
    );
    await _run(tester, 1);

    expect(hero.life.value, 90);
    expect(hero.isKnockedBack, isFalse);
    expect(hero.x, closeTo(startX, 0.5));
  });
}
