import 'package:bonfire/base/listener_game_widget.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/presentation/debug/collision_boxes.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the real [screen] and returns its game once every asset has loaded
/// and the hero is in the world.
Future<BonfireGame> _pumpGameScreen(
  WidgetTester tester,
  GameScreen screen,
) async {
  await tester.pumpWidget(MaterialApp(home: screen));
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

/// Whether the hero's hitbox is being drawn.
bool _heroBoxShown(BonfireGame game) =>
    game.player!.children.whereType<ShapeHitbox>().single.renderShape;

final _toggle = find.text('Collision boxes');

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('the toggle turns the collision boxes on and off',
      (tester) async {
    final game = await _pumpGameScreen(tester, const GameScreen());

    // They start hidden.
    expect(_toggle, findsOneWidget);
    expect(_heroBoxShown(game), isFalse);

    // Tapping the toggle shows them, without taking keyboard focus from
    // the game (or the arrow keys would stop moving the hero).
    final focusBefore = FocusManager.instance.primaryFocus;
    await tester.tap(_toggle);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_heroBoxShown(game), isTrue);
    expect(FocusManager.instance.primaryFocus, focusBefore);
    // The solid ground tiles are outlined too, not just the characters.
    expect(
      game.world
          .descendants()
          .whereType<ShapeHitbox>()
          .where((h) => h.renderShape)
          .length,
      greaterThan(1),
    );

    // Tapping it again hides them.
    await tester.tap(_toggle);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_heroBoxShown(game), isFalse);
  });

  testWidgets('the boxes can start shown', (tester) async {
    final game = await _pumpGameScreen(
      tester,
      const GameScreen(showCollisionArea: true),
    );

    expect(_heroBoxShown(game), isTrue);
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isTrue,
    );
  });

  testWidgets('release builds leave the toggle out', (tester) async {
    final game = await _pumpGameScreen(
      tester,
      const GameScreen(showCollisionToggle: false),
    );

    expect(_toggle, findsNothing);
    expect(game.query<CollisionBoxes>().single.visible.value, isFalse);
  });
}
