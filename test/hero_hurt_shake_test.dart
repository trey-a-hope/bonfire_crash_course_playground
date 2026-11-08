import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero], any [components] and the game's
/// real camera settings, and returns the game once every asset has loaded
/// and it is running.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  List<GameComponent> components = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  BonfireGameInterface? game;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: components,
        map: WorldMapBySpritefusion(WorldMapReader.fromAsset(MAP_ONE)),
        cameraConfig: GameScreen.cameraConfig(),
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
  return game!;
}

/// Advances the game by [seconds], one 16 ms frame at a time, and returns
/// the farthest the camera got from [from] on any of those frames. With a
/// [game], it also checks on every frame that the camera never shows
/// anything past the map's edges.
Future<double> _run(
  WidgetTester tester,
  double seconds, {
  BonfireGameInterface? game,
  Vector2? from,
}) async {
  var farthest = 0.0;
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (game == null) continue;
    _expectInsideMap(game);
    if (from != null) {
      final d = game.camera.position.distanceTo(from);
      if (d > farthest) farthest = d;
    }
  }
  return farthest;
}

/// Fails if the camera shows anything past the map's edges.
void _expectInsideMap(BonfireGameInterface game) {
  final visible = game.camera.visibleWorldRect;
  final map = game.map.size;
  expect(
    visible.left >= -0.01 &&
        visible.top >= -0.01 &&
        visible.right <= map.x + 0.01 &&
        visible.bottom <= map.y + 0.01,
    isTrue,
    reason: 'the camera showed past the map: $visible',
  );
}

/// Hurts the [hero] the same way the foe's bite does.
void _bite(Hero hero) =>
    hero.life.handleAttack(AttackOriginEnum.ENEMY, 10, null);

/// A shake lasts [Hero.shakeDuration]; this is comfortably past its end.
const _afterShake = 0.5;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('getting hurt shakes the camera, then it settles back',
      (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero);
    await _run(tester, 1.5);
    final still = game.camera.position.clone();

    _bite(hero);
    final shook = await _run(
      tester,
      Hero.shakeDuration.inMilliseconds / 1000,
      game: game,
      from: still,
    );
    expect(shook, greaterThan(0.5), reason: 'the camera did not shake');
    // Light: a few pixels, not a screen-sized jolt.
    expect(shook, lessThan(TILE_SIZE));

    // Over: back exactly where it was, and it stays there.
    await _run(tester, _afterShake, game: game);
    expect(game.camera.position.distanceTo(still), lessThan(0.01));
    final drift = await _run(tester, 0.5, game: game, from: still);
    expect(drift, lessThan(0.01));
  });

  testWidgets("the foe's bite shakes the camera", (tester) async {
    // On the map's last tile, so the bite's knockback can't move the hero
    // away from the foe and the second bite lands a second after the first.
    final hero = Hero(Vector2(29, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      components: [Foe(Vector2(28, 7) * TILE_SIZE)],
    );
    // The first bite lands right away. Let its shake end and the camera
    // come to rest before the next bite, a second after the first.
    await _run(tester, 0.8);
    expect(hero.life.value, 90);
    final still = game.camera.position.clone();
    final zoom = game.camera.zoom;

    final shook = await _run(tester, 0.5, game: game, from: still);
    expect(hero.life.value, 80, reason: 'the second bite did not land');
    expect(shook, greaterThan(0.5), reason: 'the bite did not shake it');

    // The camera is next to the map's right edge here, and it still never
    // showed past it (checked on every frame above). Afterwards it is back
    // to its normal zoom.
    await _run(tester, _afterShake, game: game);
    expect(game.camera.zoom, closeTo(zoom, 0.0001));
  });

  testWidgets('hurting the foe does not shake the camera', (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    // Across the wall from the hero, so it can't reach them to bite.
    final foe = Foe(Vector2(28, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero, components: [foe]);
    await _run(tester, 1.5);
    final still = game.camera.position.clone();

    // The same damage the hero's attacks deal to the foe.
    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 20, null);
    final moved = await _run(tester, 0.5, game: game, from: still);

    expect(foe.life.value, 80);
    expect(moved, lessThan(0.01));
  });

  testWidgets('quick hits do not stack into a longer shake', (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero);
    await _run(tester, 1.5);
    final still = game.camera.position.clone();

    // A second hit halfway through the first shake.
    _bite(hero);
    await _run(tester, Hero.shakeDuration.inMilliseconds / 2000);
    _bite(hero);

    // Still over on time: back at rest right after the first shake ends.
    await _run(tester, Hero.shakeDuration.inMilliseconds / 2000 + 0.05);
    expect(game.camera.position.distanceTo(still), lessThan(0.01));
    final drift = await _run(tester, _afterShake, game: game, from: still);
    expect(drift, lessThan(0.01));
  });
}
