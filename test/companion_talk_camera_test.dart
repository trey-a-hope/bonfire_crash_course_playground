import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero], the [companion] and the game's
/// real camera settings on a small phone held upright, and returns the game
/// once every asset has loaded and it is running.
///
/// A narrow screen, so the camera has room to centre on the companion: on a
/// wide one it stops at the map's right edge first.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Companion companion,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  BonfireGameInterface? game;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [companion],
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

/// Advances the game by [seconds], one 16 ms frame at a time, stopping
/// early once [until] is true.
Future<void> _run(
  WidgetTester tester,
  double seconds, {
  bool Function()? until,
}) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames && !(until?.call() ?? false); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

final _dialogue = find.byType(TalkDialog);

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the camera pans to the companion, then back to the hero',
      (tester) async {
    // Two tiles right of the companion, on the flat ground at columns 23-29.
    final hero = Hero(Vector2(26, 7) * TILE_SIZE);
    final companion = Companion(Vector2(24, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero, companion: companion);
    await _run(tester, 1);
    final zoom = game.camera.zoom;

    // Walk left until the companion notices the hero and the scene starts.
    hero.moveLeft();
    for (var i = 0; i < 200 && !game.sceneBuilderStatus.isRunning; i++) {
      await _run(tester, 0.016);
    }
    expect(game.sceneBuilderStatus.isRunning, isTrue);
    final heroX = hero.x;

    // Mid-pan: no dialogue yet, and the hero ignores input.
    hero.moveRight();
    await _run(tester, 0.5);
    expect(_dialogue, findsNothing);
    expect(hero.x, heroX);
    // Let go of the key, so the hero doesn't walk off once the scene ends.
    hero.stop();

    // The pan ends on the companion, zoomed in, and the dialogue opens.
    // Pump frame by frame until the dialogue is up, not pumpAndSettle: the
    // companion's face in it is a looping SpriteAnimationWidget, and once its
    // image has loaded (real async work, racing the fake clock) the tree
    // never settles. Then a few more frames for the dialogue's open
    // transition.
    await _run(tester, 3, until: () => _dialogue.evaluate().isNotEmpty);
    expect(_dialogue, findsOneWidget);
    await _run(tester, 0.3);
    expect(game.camera.position.x, closeTo(companion.center.x, 1));
    expect(game.camera.zoom, closeTo(zoom * 1.25, 0.01));

    // Tap through the dialogue until it closes.
    // The last tap starts the closing animation, so a tap can land while
    // the dialogue is fading out; that one does nothing, which is fine.
    // (No pumpAndSettle here: once the game resumes it never settles.)
    for (var i = 0; i < 30 && _dialogue.evaluate().isNotEmpty; i++) {
      await tester.tap(_dialogue, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(_dialogue, findsNothing);

    // Mid-way back: the hero still waits for the camera.
    await _run(tester, 0.5);
    expect(game.sceneBuilderStatus.isRunning, isTrue);
    expect(hero.x, heroX);

    // Back on the hero at the original zoom.
    await _run(tester, 0.7);
    expect(game.sceneBuilderStatus.isRunning, isFalse);
    expect(game.camera.zoom, closeTo(zoom, 0.01));
    expect(
      (game.camera.position.x - hero.center.x).abs(),
      lessThanOrEqualTo(TILE_SIZE + 1),
    );

    // The camera follows the hero again: walk left past the movement window
    // (towards the open ground, away from the map's right edge) and the
    // camera comes along.
    final cameraX = game.camera.position.x;
    hero.moveLeft();
    await _run(tester, 1);
    hero.stop();
    expect(hero.x, lessThan(heroX - TILE_SIZE));
    expect(game.camera.position.x, lessThan(cameraX - TILE_SIZE));
  });
}
