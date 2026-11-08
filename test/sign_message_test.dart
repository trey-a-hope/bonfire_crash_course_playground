import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/sign.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero], the [sign] and any [others],
/// with the game's real camera settings, and returns the game once every
/// asset has loaded and it is running.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Sign sign,
  List<GameComponent> others = const [],
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
        components: [sign, ...others],
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

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Where the game puts the sign: tile (1, 7), left of the low block at
/// column 2.
final _signTile = Vector2(1, 7) * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the message shows while the hero is at the sign, every visit',
      (tester) async {
    // On the low block at column 2, just right of the sign.
    final hero = Hero(Vector2(2, 6) * TILE_SIZE);
    final sign = Sign(_signTile);
    await _pumpGame(tester, hero: hero, sign: sign);
    await _run(tester, 0.5);
    expect(sign.isShowingMessage, isFalse);

    for (var visit = 1; visit <= 2; visit++) {
      // Walk left, off the block and up to the sign.
      hero.moveLeft();
      await _run(tester, 0.6);
      hero.stop();
      await _run(tester, 0.2);
      expect(hero.toAbsoluteRect().overlaps(sign.toAbsoluteRect()), isTrue);
      expect(sign.isShowingMessage, isTrue, reason: 'visit $visit');

      // Jump back right onto the block, away from the sign.
      hero.moveRight();
      hero.jumper.jump();
      await _run(tester, 0.8);
      hero.stop();
      await _run(tester, 0.2);
      expect(hero.toAbsoluteRect().overlaps(sign.toAbsoluteRect()), isFalse);
      expect(sign.isShowingMessage, isFalse, reason: 'after visit $visit');
    }
  });

  testWidgets('the game keeps running while the message shows', (tester) async {
    final hero = Hero(_signTile.clone());
    final sign = Sign(_signTile);
    final game = await _pumpGame(tester, hero: hero, sign: sign);
    await _run(tester, 0.5);
    expect(sign.isShowingMessage, isTrue);

    // Not paused, no dialogue, and the hero still moves on command.
    expect(game.paused, isFalse);
    expect(find.byType(Dialog), findsNothing);
    final x = hero.x;
    hero.moveLeft();
    await _run(tester, 0.2);
    hero.stop();
    expect(hero.x, lessThan(x));
  });

  testWidgets('the message is drawn over the hero, not behind them',
      (tester) async {
    final hero = Hero(_signTile.clone());
    final sign = Sign(_signTile);
    await _pumpGame(tester, hero: hero, sign: sign);
    await _run(tester, 0.5);

    // Beside the sign in the world, so it isn't held behind the characters
    // with the sign, and drawn after the hero.
    expect(sign.bubble.parent, isNot(sign));
    expect(sign.bubble.priority, greaterThan(hero.priority));
  });

  testWidgets('the companion and the foe do not show the message',
      (tester) async {
    await _pumpGame(
      tester,
      // Far away, out of the way.
      hero: Hero(Vector2(16, 7) * TILE_SIZE),
      sign: Sign(_signTile),
      others: [
        Companion(_signTile.clone()),
        Foe(_signTile.clone()),
      ],
    ).then((game) async {
      await _run(tester, 1);
      final sign = game.query<Sign>().single;
      expect(sign.isShowingMessage, isFalse);
    });
  });

  test('the bubble is hidden until the hero walks up', () {
    expect(Sign(_signTile).isShowingMessage, isFalse);
  });
}
