import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and the game's real camera
/// settings, on a screen of [screen] logical pixels, and returns the game
/// once every asset has loaded and it is running.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Size screen,
}) async {
  tester.view.physicalSize = screen;
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

/// Advances the game by [seconds], one 16 ms frame at a time, calling
/// [eachFrame] after every frame.
Future<void> _run(
  WidgetTester tester,
  double seconds, {
  void Function()? eachFrame,
}) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    eachFrame?.call();
  }
}

/// How far the camera's centre is to the right of the hero's centre.
double _lead(BonfireGameInterface game, Hero hero) =>
    game.camera.position.x - hero.center.x;

/// Fails if any part of the hero is outside what the camera shows.
void _expectOnScreen(BonfireGameInterface game, Hero hero) {
  final visible = game.camera.visibleWorldRect;
  final body = hero.toAbsoluteRect();
  // Compare edges directly: Rect.contains leaves out the right and bottom
  // edges, and the hero can stand flush against the map's right edge.
  expect(
    body.left >= visible.left - 0.5 &&
        body.right <= visible.right + 0.5 &&
        body.top >= visible.top - 0.5 &&
        body.bottom <= visible.bottom + 0.5,
    isTrue,
    reason: 'hero $body went outside the visible area $visible',
  );
}

/// Phone portrait, phone landscape and desktop, the sizes QA checks.
const _screens = {
  'small phone portrait': Size(360, 640),
  'small phone landscape': Size(640, 360),
  'desktop': Size(1280, 720),
};

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  // Columns 23-29 of map 01 are flat open ground, so the hero can walk the
  // whole stretch. On a narrow screen the camera is clear of the map's right
  // edge there, so it is free to follow.

  testWidgets('the camera eases after the walking hero instead of snapping',
      (tester) async {
    final hero = Hero(Vector2(29, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      screen: _screens['small phone portrait']!,
    );
    await _run(tester, 1);

    hero.moveLeft();
    await _run(tester, 2.2);

    // The hero is past the movement window and the camera is still catching
    // up, so it trails by more than the window alone.
    expect(_lead(game, hero), greaterThan(TILE_SIZE + 8));
    _expectOnScreen(game, hero);
  });

  testWidgets('the camera settles back on the hero once they stop',
      (tester) async {
    final hero = Hero(Vector2(29, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      screen: _screens['small phone portrait']!,
    );
    await _run(tester, 1);

    hero.moveLeft();
    await _run(tester, 2.2);
    hero.stop();
    await _run(tester, 2);

    // It stops at the edge of the movement window, not on top of the hero.
    expect(_lead(game, hero).abs(), lessThanOrEqualTo(TILE_SIZE + 1));
  });

  testWidgets('small hops inside the movement window do not move the camera',
      (tester) async {
    final hero = Hero(Vector2(26, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      screen: _screens['small phone portrait']!,
    );
    await _run(tester, 1.5);
    final before = game.camera.position.clone();

    // A few steps right then back: less than a tile from where it started.
    // Check every frame, so a camera that moves and comes back still fails.
    void cameraStill() =>
        expect(game.camera.position.x, closeTo(before.x, 0.5));
    hero.moveRight();
    await _run(tester, 0.2, eachFrame: cameraStill);
    hero.moveLeft();
    await _run(tester, 0.2, eachFrame: cameraStill);
    hero.stop();
    await _run(tester, 0.5, eachFrame: cameraStill);
  });

  testWidgets('the hero stops flush with the right edge of the map',
      (tester) async {
    final hero = Hero(Vector2(28, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      screen: _screens['desktop']!,
    );
    await _run(tester, 1);

    // Keep pushing right well after reaching the edge.
    hero.moveRight();
    await _run(tester, 2, eachFrame: () => _expectOnScreen(game, hero));

    expect(hero.toAbsoluteRect().right, closeTo(game.map.size.x, 0.5));
  });

  for (final entry in _screens.entries) {
    testWidgets('the hero never leaves the screen (${entry.key})',
        (tester) async {
      final hero = Hero(Vector2(28, 7) * TILE_SIZE);
      final game = await _pumpGame(tester, hero: hero, screen: entry.value);
      await _run(tester, 1);
      _expectOnScreen(game, hero);

      // Walk the flat stretch to the wall and back, checking every frame.
      hero.moveLeft();
      await _run(tester, 2.5, eachFrame: () => _expectOnScreen(game, hero));
      hero.moveRight();
      await _run(tester, 2, eachFrame: () => _expectOnScreen(game, hero));
      hero.stop();
      await _run(tester, 1, eachFrame: () => _expectOnScreen(game, hero));
    });
  }
}
