import 'package:bonfire/base/listener_game_widget.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/campfire.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';
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
  // outside the test's fake clock. The background keeps loading a little
  // after the hero appears, so let it finish before the test ends.
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

  test('the dusk tint is a dark navy at 60% opacity', () {
    expect(GameScreen.duskColor, const Color(0x990B1026));
  });

  test('the campfire gives off a warm, flickering light 3 tiles wide', () {
    final light = Campfire(Vector2(12, 7) * TILE_SIZE).lighting;
    expect(light.enabled, isTrue);
    expect(light.config, isNotNull);
    expect(light.config!.radius, 3 * TILE_SIZE);
    expect(light.config!.color, Campfire.lightColor);
    expect(light.config!.withPulse, isTrue);
  });

  testWidgets('map 01 is tinted for dusk', (tester) async {
    final game = await _pumpGameScreen(tester);

    expect(game.lighting.isEnabled(), isTrue);
    expect(game.lighting.color, GameScreen.duskColor);
  });

  testWidgets('the campfire on map 01 flickers while the game runs',
      (tester) async {
    final game = await _pumpGameScreen(tester);
    final campfire = game.query<Campfire>().single;
    // Bonfire nudges decorations by under a pixel to hide tile seams.
    expect(
      campfire.position.distanceTo(Vector2(12, 7) * TILE_SIZE),
      lessThan(1),
    );

    // Sample the pulse over a second: it should rise and fall, not sit
    // still, and never shrink the light by more than about a tenth.
    final pulses = <double>[];
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      pulses.add(campfire.lighting.config!.valuePulse);
    }
    final lowest = pulses.reduce((a, b) => a < b ? a : b);
    final highest = pulses.reduce((a, b) => a > b ? a : b);
    expect(highest - lowest, greaterThan(0.05));
    expect(highest, lessThanOrEqualTo(0.1));
  });
}
