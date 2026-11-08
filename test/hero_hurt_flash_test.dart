import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 at dusk with the [hero], any [components] and the
/// game's real camera settings, and returns the game once every asset has
/// loaded and it is running.
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

/// What the flash looked like over a stretch of frames.
class _Flash {
  /// The strongest red seen, as an alpha from 0 to 255.
  int peak = 0;

  /// Seconds from the start of the stretch to the last frame with any tint.
  double lastTinted = 0;
}

/// Advances the game by [seconds], one 16 ms frame at a time, and records
/// the game color filter on every frame.
Future<_Flash> _run(
  WidgetTester tester,
  BonfireGameInterface game,
  double seconds,
) async {
  final flash = _Flash();
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 1; i <= frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final config = game.colorFilter!.config;
    final color = config.color;
    if (color == null) continue;
    final alpha = (color.a * 255).round();
    if (alpha == 0) continue;
    // Laid over the picture on every visible frame, not Bonfire's default
    // BlendMode.color, which turns the whole scene a flat red.
    expect(config.blendMode, BlendMode.srcOver);
    expect(color.r, closeTo(Hero.hurtFlashColor.r, 0.001));
    expect(color.g, closeTo(Hero.hurtFlashColor.g, 0.001));
    expect(color.b, closeTo(Hero.hurtFlashColor.b, 0.001));
    if (alpha > flash.peak) flash.peak = alpha;
    flash.lastTinted = i * 16 / 1000;
  }
  return flash;
}

/// Hurts the [hero] the same way the foe's bite does.
void _bite(Hero hero) =>
    hero.life.handleAttack(AttackOriginEnum.ENEMY, 10, null);

/// The flash's full strength, as an alpha from 0 to 255.
final _fullAlpha = (Hero.hurtFlashColor.a * 255).round();

/// A flash lasts as long as the shake.
final _flashSeconds = Hero.shakeDuration.inMilliseconds / 1000;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('getting hurt flashes red, then leaves no tint', (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero);
    await _run(tester, game, 1.5);
    expect(game.colorFilter!.config.color, isNull);

    _bite(hero);
    final flash = await _run(tester, game, 0.6);

    expect(flash.peak, greaterThan(_fullAlpha * 0.8),
        reason: 'the screen did not flash red');
    expect(flash.peak, lessThanOrEqualTo(_fullAlpha));
    // Gone in well under half a second.
    expect(flash.lastTinted, lessThan(_flashSeconds + 0.05));
    expect(game.colorFilter!.config.color, isNull);
    // The dusk is untouched.
    expect(game.lighting!.color, GameScreen.duskColor);
  });

  testWidgets("the foe's bite flashes red", (tester) async {
    final hero = Hero(Vector2(27, 7) * TILE_SIZE);
    final game = await _pumpGame(
      tester,
      hero: hero,
      components: [Foe(Vector2(28, 7) * TILE_SIZE)],
    );
    // The first bite lands right away; the next comes a second later.
    final flash = await _run(tester, game, 0.4);
    expect(hero.life.value, 90);
    expect(flash.peak, greaterThan(_fullAlpha * 0.8));
    expect(game.colorFilter!.config.color, isNull);
  });

  testWidgets('quick hits do not stack into a longer or stronger flash',
      (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero);
    await _run(tester, game, 1.5);

    // A second hit halfway through the first flash.
    _bite(hero);
    final first = await _run(tester, game, _flashSeconds / 2);
    _bite(hero);
    final second = await _run(tester, game, 0.5);

    expect(hero.life.value, 80, reason: 'both hits landed');
    expect(first.peak, lessThanOrEqualTo(_fullAlpha));
    expect(second.peak, lessThanOrEqualTo(first.peak));
    // Still over on time, counted from the first hit.
    expect(
        _flashSeconds / 2 + second.lastTinted, lessThan(_flashSeconds + 0.05));
    expect(game.colorFilter!.config.color, isNull);
  });

  testWidgets('hurting the foe does not flash', (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    // Across the wall from the hero, so it can't reach them to bite.
    final foe = Foe(Vector2(28, 7) * TILE_SIZE);
    final game = await _pumpGame(tester, hero: hero, components: [foe]);
    await _run(tester, game, 1.5);

    // The same damage the hero's attacks deal to the foe.
    foe.life.handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, 20, null);
    final flash = await _run(tester, game, 0.5);

    expect(foe.life.value, 80);
    expect(flash.peak, 0);
    expect(game.colorFilter!.config.color, isNull);
  });
}
