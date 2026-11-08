import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 at dusk with the [hero], the [companion] and the
/// game's real camera settings, and returns the game once every asset has
/// loaded and it is running.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Companion companion,
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
        components: [companion],
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
  return game!;
}

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The hero far enough from the companion that it never starts talking, so
/// no cutscene gets in the way.
Future<(BonfireGameInterface, Hero, Companion)> _game(
  WidgetTester tester,
) async {
  final hero = Hero(Vector2(16, 7) * TILE_SIZE);
  final companion = Companion(Vector2(24, 7) * TILE_SIZE);
  final game = await _pumpGame(tester, hero: hero, companion: companion);
  // Let both land.
  await _run(tester, 1);
  return (game, hero, companion);
}

/// Bites the companion the way the shark does: an ENEMY attack from [foe].
void _bite(Companion companion, Foe foe, {double damage = 10}) =>
    companion.life.handleAttack(AttackOriginEnum.ENEMY, damage, foe);

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets("the shark's bite can hurt the companion", (tester) async {
    final (_, _, companion) = await _game(tester);
    // The foe's bite is an ENEMY attack, and Bonfire lets allies take those.
    expect(
        companion.life.checkCanReceiveDamage(AttackOriginEnum.ENEMY), isTrue);
    // The hero's own attacks don't hurt it.
    expect(
      companion.life.checkCanReceiveDamage(AttackOriginEnum.PLAYER_OR_ALLY),
      isFalse,
    );

    _bite(companion, Foe(Vector2.zero()));
    expect(companion.life.value, 90);
  });

  testWidgets('a hit plays the hurt animation once', (tester) async {
    final (_, _, companion) = await _game(tester);
    final animation = companion.animation!;

    _bite(companion, Foe(Vector2.zero()));
    // Two frames in (0.08 s each), the flinch is playing.
    await _run(tester, 0.2);
    expect(animation.fastAnimationcurrentIndex, greaterThan(0));

    // Five frames take 0.4 s; then it goes back to idle and stays there.
    await _run(tester, 0.4);
    expect(animation.fastAnimationcurrentIndex, 0);
    expect(animation.currentType, SimpleAnimationEnum.idleRight);
    await _run(tester, 0.5);
    expect(animation.fastAnimationcurrentIndex, 0);
  });

  testWidgets("hurting the companion doesn't shake or flash the screen", (
    tester,
  ) async {
    final (game, hero, companion) = await _game(tester);
    final zoom = game.camera.zoom;

    for (var i = 0; i < 25; i++) {
      _bite(companion, Foe(Vector2.zero()), damage: 1);
      await tester.pump(const Duration(milliseconds: 16));
      // A shake zooms in a little and a flash tints the color filter.
      expect(game.camera.zoom, zoom);
      expect(game.colorFilter!.config.color, isNull);
    }
    expect(companion.life.value, 75);
    expect(hero.life.value, hero.life.max);
  });

  testWidgets('at 0 life it plays its death animation, then is removed', (
    tester,
  ) async {
    final (_, _, companion) = await _game(tester);

    _bite(companion, Foe(Vector2.zero()), damage: 100);
    expect(companion.isDead, isTrue);

    // Still there while it falls over (4 frames of 0.15 s)...
    await _run(tester, 0.3);
    expect(companion.isMounted, isTrue);
    expect(companion.animation!.fastAnimationcurrentIndex, greaterThan(0));

    // ...then gone.
    await _run(tester, 0.5);
    expect(companion.isMounted, isFalse);
  });

  testWidgets('a dead companion stops following and takes no more hits', (
    tester,
  ) async {
    final (_, _, companion) = await _game(tester);

    _bite(companion, Foe(Vector2.zero()), damage: 100);
    await tester.pump(const Duration(milliseconds: 16));
    expect(companion.velocity.x, 0);
    expect(
        companion.life.checkCanReceiveDamage(AttackOriginEnum.ENEMY), isFalse);
  });
}
