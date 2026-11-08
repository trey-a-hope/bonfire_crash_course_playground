import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a dusk game on map 01 with the [hero], and returns the game once
/// every asset has loaded and it is running.
Future<BonfireGameInterface> _pumpGame(WidgetTester tester, Hero hero) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  BonfireGameInterface? game;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        map: WorldMapBySpritefusion(WorldMapReader.fromAsset(MAP_ONE)),
        cameraConfig: GameScreen.cameraConfig(),
        lightingColorGame: GameScreen.duskColor,
        onReady: (g) => game = g,
      ),
    ),
  );
  // Images and the map load with real async work, so give it real time
  // outside the test's fake clock.
  for (var i = 0; i < 50 && game == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(game, isNotNull, reason: 'the game never became ready');
  // Let the hero land on the ground before acting.
  await _run(tester, 1);
  return game!;
}

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Presses and releases [key] on the hero, the way the keyboard does.
void _tap(Hero hero, LogicalKeyboardKey key, PhysicalKeyboardKey physical) {
  hero.onKeyboard(
    KeyDownEvent(
      physicalKey: physical,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
    {key},
  );
  hero.onKeyboard(
    KeyUpEvent(
      physicalKey: physical,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
    {},
  );
}

/// Waits for the hero's magic bolt to appear: it leaves the hand on the cast
/// sheet's release frame, and its sprite loads with real async work.
Future<FlyingAttackGameObject> _waitForBolt(
  WidgetTester tester,
  BonfireGameInterface game,
) async {
  for (var i = 0; i < 40 && _bolts(game).isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(_bolts(game), hasLength(1), reason: 'the bolt was never cast');
  return _bolts(game).single;
}

/// The hero's magic bolts in flight.
Iterable<FlyingAttackGameObject> _bolts(BonfireGameInterface game) =>
    game.query<FlyingAttackGameObject>();

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the magic bolt carries a small cyan light until it is gone',
      (tester) async {
    final hero = Hero(Vector2(3, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero);

    _tap(hero, LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW);
    final bolt = await _waitForBolt(tester, game);
    final light = bolt.lighting;
    expect(light.enabled, isTrue);
    expect(light.config, isNotNull);
    expect(light.config!.radius, TILE_SIZE);
    expect(light.config!.color, Hero.projectileLightColor);
    expect(light.config!.withPulse, isFalse);

    // It flies right, and its light goes with it.
    final start = bolt.center.x;
    await _run(tester, 0.1);
    expect(bolt.center.x, greaterThan(start));

    // Once it hits a wall or leaves the screen, it and its light are gone.
    await _run(tester, 4);
    expect(_bolts(game), isEmpty);
    expect(game.query<WithLighting>().where((c) => c is! Hero), isEmpty);
  });

  testWidgets('a bolt cast to the left carries the light too', (tester) async {
    final hero = Hero(Vector2(8, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero);

    // Turn left, then cast.
    hero.onKeyboard(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.keyA},
    );
    await _run(tester, 0.1);
    hero.onKeyboard(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
      {},
    );
    _tap(hero, LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW);
    final bolt = await _waitForBolt(tester, game);
    expect(bolt.lighting.config?.color, Hero.projectileLightColor);
    final start = bolt.center.x;
    await _run(tester, 0.1);
    expect(bolt.center.x, lessThan(start));
  });

  testWidgets('the melee attack makes no light', (tester) async {
    final hero = Hero(Vector2(3, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero);

    _tap(hero, LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS);
    await _run(tester, 0.2);

    expect(
      game
          .query<WithLighting>()
          .where((c) => c.lighting.config != null && c is! Hero),
      isEmpty,
    );
  });
}
