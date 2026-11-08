import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/spikes.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero], the [spikes] and any [others],
/// with the game's real camera settings, and returns the game once every
/// asset has loaded and it is running.
Future<BonfireGameInterface> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Spikes spikes,
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
        components: [spikes, ...others],
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

/// Where the game puts the spikes: the first tile of the dip between the
/// low block at columns 5-6 and the raised block at columns 9-11.
final _spikesTile = Vector2(7, 7) * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('touching the spikes hurts the hero, with the shake and flash',
      (tester) async {
    // In the dip, right of the spikes, against the raised block.
    final hero = Hero(Vector2(8, 7) * TILE_SIZE);
    final spikes = Spikes(_spikesTile);
    final game = await _pumpGame(tester, hero: hero, spikes: spikes);
    await _run(tester, 1);
    expect(hero.life.value, 100);

    // Walk left, back towards the low block, onto the spikes.
    hero.moveLeft();
    for (var i = 0; i < 120 && hero.life.value == 100; i++) {
      await _run(tester, 0.016);
    }
    hero.stop();
    expect(hero.life.value, 100 - Spikes.damage);
    // The same hit as the foe's bite: the camera zooms in to shake and the
    // screen flashes red.
    var flashed = false;
    for (var i = 0; i < 5; i++) {
      await _run(tester, 0.016);
      if ((game.colorFilter!.config.color?.a ?? 0) > 0) flashed = true;
    }
    expect(flashed, isTrue, reason: 'the screen did not flash red');
    expect(game.camera.zoom, greaterThan(1));
  });

  testWidgets('standing on the spikes hurts at most once a second',
      (tester) async {
    // Dropped straight onto the spikes.
    final hero = Hero(_spikesTile.clone());
    final spikes = Spikes(_spikesTile);
    await _pumpGame(tester, hero: hero, spikes: spikes);

    // Wait for the first hit, then stand still for 3.5 more seconds.
    for (var i = 0; i < 100 && hero.life.value == 100; i++) {
      await _run(tester, 0.016);
    }
    expect(hero.life.value, 90);
    await _run(tester, 3.5);

    // One hit a second: 3 more, not one every 100 ms.
    expect(hero.life.value, 60);
    expect(hero.toAbsoluteRect().overlaps(spikes.toAbsoluteRect()), isTrue);
  });

  testWidgets('jumping off the low block clears the spikes', (tester) async {
    // On the low block, right at its edge.
    final hero = Hero(Vector2(6, 6) * TILE_SIZE);
    final spikes = Spikes(_spikesTile);
    await _pumpGame(tester, hero: hero, spikes: spikes);
    await _run(tester, 1);

    // One jump to the right, from the block's edge.
    hero.moveRight();
    hero.jumper.jump();
    await _run(tester, 1.5);
    hero.stop();
    await _run(tester, 0.5);

    // Landed past the spikes, in the dip by the raised block, unhurt.
    expect(hero.x, closeTo(8 * TILE_SIZE, 2));
    expect(hero.toAbsoluteRect().bottom, closeTo(8 * TILE_SIZE, 2));
    expect(hero.life.value, 100);
  });

  testWidgets('the spikes never block the hero', (tester) async {
    // In the dip, right of the spikes, against the raised block.
    final hero = Hero(Vector2(8, 7) * TILE_SIZE);
    final spikes = Spikes(_spikesTile);
    await _pumpGame(tester, hero: hero, spikes: spikes);
    await _run(tester, 0.5);

    // Walk left, onto the spikes, to the low block's wall.
    hero.moveLeft();
    await _run(tester, 1);
    hero.stop();

    // Stopped by the low block at column 6, on top of the spikes, not
    // before them.
    expect(hero.x, closeTo(7 * TILE_SIZE, 2));
  });

  testWidgets('the companion and the foe are not hurt by the spikes',
      (tester) async {
    final companion = Companion(_spikesTile.clone());
    final foe = Foe(_spikesTile.clone());
    await _pumpGame(
      tester,
      // Far away, out of the way.
      hero: Hero(Vector2(26, 7) * TILE_SIZE),
      spikes: Spikes(_spikesTile),
      others: [companion, foe],
    );
    await _run(tester, 2);

    // The foe starts with 100 life (README).
    expect(foe.life.value, 100);
    expect(foe.isMounted, isTrue);
    expect(companion.isMounted, isTrue);
  });
}
