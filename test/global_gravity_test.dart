import 'package:bonfire/base/listener_game_widget.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the real game screen and returns its game once every asset has
/// loaded and the hero is in the world.
Future<BonfireGame> _pumpGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: GameScreen()));
  final game = tester
      .widget<ListenerGameWidget>(
        find.byWidgetPredicate((w) => w is ListenerGameWidget),
      )
      .game as BonfireGame;
  // Images and the map load with real async work, so give it real time
  // outside the test's fake clock.
  for (var i = 0; i < 50 && game.player?.isMounted != true; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(game.player?.isMounted, isTrue, reason: 'the game never loaded');
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 16));
  return game;
}

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('gravity is set once, for the whole game', (tester) async {
    final game = await _pumpGameScreen(tester);

    expect(game.globalForces.gravity, Vector2(0, GRAVITY));
  });

  testWidgets('no character adds gravity of its own', (tester) async {
    final game = await _pumpGameScreen(tester);
    final hero = game.query<Hero>().single;
    final companion = game.query<Companion>().single;
    final foe = game.query<Foe>().single;

    // A character's own gravity adds to the world's, so it would fall twice
    // as fast.
    for (final forces in [hero.forces, companion.forces, foe.forces]) {
      expect(forces.gravity, Vector2.zero());
    }
  });

  testWidgets('the hero falls from its spawn point and lands on the ground',
      (tester) async {
    final game = await _pumpGameScreen(tester);
    final hero = game.query<Hero>().single;

    // Give it a couple of seconds: plenty to fall from (100, 100) and land.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final landedY = hero.y;
    expect(landedY, greaterThan(100), reason: 'gravity pulled the hero down');

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(hero.y, closeTo(landedY, 1), reason: 'the ground stopped it');
  });
}
