import 'package:bonfire/base/listener_game_widget.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/backgrounds/parallax_background.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/debug/collision_boxes.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/campfire.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/map_exit.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/sign.dart';
import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests for BCC-33: GameScreen's MapNavigator, the exits between map 01 and
// map 02, where the hero arrives, and that an exit fires once per visit.

/// The game currently on screen. MapNavigator only shows the current map,
/// so there is exactly one.
BonfireGame _currentGame(WidgetTester tester) => tester
    .widget<ListenerGameWidget>(
      find.byWidgetPredicate((w) => w is ListenerGameWidget),
    )
    .game as BonfireGame;

/// Waits, with real time for the assets, until the game on screen is not
/// [previous] and its hero is in the world, then returns it.
Future<BonfireGame> _waitForGame(
  WidgetTester tester, {
  BonfireGame? previous,
}) async {
  BonfireGame? game;
  bool loaded() {
    final finder = find.byWidgetPredicate((w) => w is ListenerGameWidget);
    if (finder.evaluate().length != 1) return false;
    game = _currentGame(tester);
    return game != previous && game!.player?.isMounted == true;
  }

  for (var i = 0; i < 60 && !loaded(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(loaded(), isTrue, reason: 'the next map never loaded');
  // One more frame, so the game's own "mounted" callback (scheduled on the
  // frame it first had children) runs before the test moves on.
  await tester.pump(const Duration(milliseconds: 16));
  return game!;
}

/// Pumps the real [GameScreen] and returns its game once map 01 has loaded.
Future<BonfireGame> _pumpGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: GameScreen()));
  final game = await _waitForGame(tester);
  // The background keeps loading a little after the hero appears.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 16));
  return game;
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

/// Whether MapNavigator is showing the map with this route name. It keys
/// each map's widget with the [MapItem]'s id, which is the route name.
bool _onMap(String route) => find.byKey(Key(route)).evaluate().isNotEmpty;

/// The tile a [component] stands on: its centre, in whole tiles.
Vector2 _tileOf(PositionComponent component) {
  final centre = component.toAbsoluteRect().center;
  return Vector2(
    (centre.dx / TILE_SIZE).floorToDouble(),
    (centre.dy / TILE_SIZE).floorToDouble(),
  );
}

/// The game's single [MapExit].
MapExit _exit(BonfireGame game) => game.query<MapExit>().single;

/// Walks the [game]'s hero from [from] towards its exit (right on map 01,
/// left on map 02) until MapNavigator leaves the map, and returns the next
/// map's game.
Future<BonfireGame> _walkThroughExit(
  WidgetTester tester,
  BonfireGame game, {
  required Vector2 from,
  required bool right,
}) async {
  // The foe paces in front of map 01's exit and would stop the hero, so
  // it steps aside for these tests.
  for (final foe in game.query<Foe>()) {
    foe.removeFromParent();
  }
  final hero = game.player! as Hero;
  hero.position = from;
  // Walk with the keyboard (D or A), like a player would.
  final key = right ? LogicalKeyboardKey.keyD : LogicalKeyboardKey.keyA;
  await tester.sendKeyDownEvent(key);
  final route = right ? GameScreen.mapOneRoute : GameScreen.mapTwoRoute;
  await _run(tester, 4, until: () => !_onMap(route));
  await tester.sendKeyUpEvent(key);
  expect(_onMap(route), isFalse, reason: 'the exit never fired');
  // The next map fades in: it starts out see-through.
  final next = right ? GameScreen.mapTwoRoute : GameScreen.mapOneRoute;
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(
          of: find.byKey(Key(next)),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  expect(fade.opacity.value, lessThan(1));
  return _waitForGame(tester, previous: game);
}

/// The companion's dialogue.
final _dialogue = find.byType(TalkDialog);

/// Walks the hero up to map 01's companion from tile (26, 7), and plays
/// the first talk through to the end: the dialogue tapped closed and the
/// camera back on the hero.
Future<void> _meetCompanion(WidgetTester tester, BonfireGame game) async {
  final hero = game.player! as Hero;
  hero.position = Vector2(26, 7) * TILE_SIZE;
  hero.moveLeft();
  await _run(tester, 3, until: () => game.sceneBuilderStatus.isRunning);
  expect(game.sceneBuilderStatus.isRunning, isTrue);
  hero.stop();
  // The pan to the companion, then the dialogue opens (the game pauses).
  // Pump frame by frame until the dialogue is up, not pumpAndSettle: the
  // companion's face in it is a looping SpriteAnimationWidget, and once its
  // image has loaded (real async work, racing the fake clock) the tree
  // never settles. Then a few more frames for the dialogue's open
  // transition.
  await _run(tester, 3, until: () => _dialogue.evaluate().isNotEmpty);
  expect(_dialogue, findsOneWidget);
  await _run(tester, 0.3);
  // Tap through it until it closes. (No pumpAndSettle once the game runs
  // again: it never settles.)
  for (var i = 0; i < 30 && _dialogue.evaluate().isNotEmpty; i++) {
    await tester.tap(_dialogue, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(_dialogue, findsNothing);
  // The pan back to the hero, and the wave.
  await _run(tester, 2, until: () => !game.sceneBuilderStatus.isRunning);
  await _run(tester, 1);
  expect(game.sceneBuilderStatus.isRunning, isFalse);
  expect(game.query<Companion>().single.isFollowing, isTrue);
}

/// Goes from map 01 to map 02 and straight back, and returns map 01's new
/// game.
Future<BonfireGame> _roundTrip(WidgetTester tester, BonfireGame mapOne) async {
  final mapTwo = await _walkThroughExit(
    tester,
    mapOne,
    from: Vector2(27, 7) * TILE_SIZE,
    right: true,
  );
  await _run(tester, 0.5);
  return _walkThroughExit(
    tester,
    mapTwo,
    from: Vector2(2, 7) * TILE_SIZE,
    right: false,
  );
}

/// A game with only the [hero] and an [exit] on map 01, for testing the
/// exit on its own.
Future<void> _pumpExitGame(
  WidgetTester tester, {
  required Hero hero,
  required MapExit exit,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [exit],
        map: WorldMapBySpritefusion(WorldMapReader.fromAsset(MAP_ONE)),
        onReady: (_) => ready = true,
      ),
    ),
  );
  for (var i = 0; i < 50 && !ready; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready, isTrue, reason: 'the game never became ready');
}

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  group('GameScreen map navigation', () {
    testWidgets('the game starts on map 01, as before', (tester) async {
      final game = await _pumpGameScreen(tester);

      expect(_onMap(GameScreen.mapOneRoute), isTrue);
      expect(_onMap(GameScreen.mapTwoRoute), isFalse);
      // The hero starts at the usual spot (it may have fallen a little).
      expect(game.player!.position.x, closeTo(GameScreen.heroStart().x, 1));
      // Map 01's characters are here, and its exit is at the right edge.
      expect(game.query<Companion>(), hasLength(1));
      expect(game.query<Foe>(), hasLength(1));
      expect(_exit(game).position, GameScreen.mapOneExitPosition());
      // 30 x 10 tiles.
      expect(game.map.size, Vector2(30, 10) * TILE_SIZE);
      // Map changes use MapNavigator's default 300 ms fade.
      expect(
        tester.widget<MapNavigator>(find.byType(MapNavigator)),
        isA<MapNavigator>().having(
          (n) => n.transitionDuration,
          'transitionDuration',
          const Duration(milliseconds: 300),
        ),
      );
    });

    testWidgets(
        "map 01's right-edge exit fades to map 02, "
        'with the hero at its arrival tile', (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      final mapTwo = await _walkThroughExit(
        tester,
        mapOne,
        from: Vector2(27, 7) * TILE_SIZE,
        right: true,
      );

      expect(_onMap(GameScreen.mapTwoRoute), isTrue);
      // The hero arrives at tile (2, 7), clear of map 02's exit.
      final hero = mapTwo.player!;
      expect(hero.position.x, closeTo(GameScreen.mapTwoArrival().x, 1));
      expect(hero.position.y, closeTo(GameScreen.mapTwoArrival().y, 2));
      final exit = _exit(mapTwo);
      expect(exit.position, GameScreen.mapTwoExitPosition());
      expect(hero.toAbsoluteRect().overlaps(exit.toAbsoluteRect()), isFalse);
      // Map 02 has a sign, a campfire and the lizardfolk warrior foe
      // (BCC-35), but no companion or shark.
      // (Decorations grow by about a pixel each way, so allow for it.)
      expect(_tileOf(mapTwo.query<Sign>().single), Vector2(4, 7));
      expect(_tileOf(mapTwo.query<Campfire>().single), Vector2(14, 7));
      expect(mapTwo.query<Companion>(), isEmpty);
      final lizardfolk = mapTwo.query<Foe>().single;
      expect(lizardfolk.asset, CharacterAsset.lizardfolk);
      expect(lizardfolk.position.x, closeTo(23 * TILE_SIZE, 1));
      // The same cave background as map 01 (BCC-34).
      expect(mapTwo.background, isA<ParallaxBackground>());
    });

    testWidgets(
        "map 02's left-edge exit fades back to map 01, "
        'with the hero at its arrival tile', (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      final mapTwo = await _walkThroughExit(
        tester,
        mapOne,
        from: Vector2(27, 7) * TILE_SIZE,
        right: true,
      );
      // Let the hero settle before walking back.
      await _run(tester, 0.5);
      final back = await _walkThroughExit(
        tester,
        mapTwo,
        from: Vector2(2, 7) * TILE_SIZE,
        right: false,
      );

      expect(_onMap(GameScreen.mapOneRoute), isTrue);
      // The hero arrives at tile (23, 7), clear of map 01's exit.
      final hero = back.player!;
      expect(hero.position.x, closeTo(GameScreen.mapOneArrival().x, 1));
      expect(hero.position.y, closeTo(GameScreen.mapOneArrival().y, 2));
      expect(
        hero.toAbsoluteRect().overlaps(_exit(back).toAbsoluteRect()),
        isFalse,
      );
      // Map 01 is built fresh, so its companion and foe are back.
      expect(back.query<Companion>(), hasLength(1));
      expect(back.query<Foe>(), hasLength(1));
    });

    testWidgets('arriving on a map does not bounce the hero straight back',
        (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      final mapTwo = await _walkThroughExit(
        tester,
        mapOne,
        from: Vector2(27, 7) * TILE_SIZE,
        right: true,
      );

      // The hero stands still at the arrival tile for two seconds: map 02's
      // exit never fires and the game stays on map 02.
      await _run(tester, 2);
      expect(_exit(mapTwo).timesEntered, 0);
      expect(_onMap(GameScreen.mapTwoRoute), isTrue);
      expect(_currentGame(tester), same(mapTwo));
    });

    testWidgets('the collision boxes toggle keeps its setting across maps',
        (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      await tester.tap(find.text('Collision boxes'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(mapOne.query<CollisionBoxes>().single.visible.value, isTrue);

      final mapTwo = await _walkThroughExit(
        tester,
        mapOne,
        from: Vector2(27, 7) * TILE_SIZE,
        right: true,
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(mapTwo.query<CollisionBoxes>().single.visible.value, isTrue);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      // And map 02's hitboxes are outlined, the hero's included.
      expect(
        mapTwo.player!.children.whereType<ShapeHitbox>().single.renderShape,
        isTrue,
      );
    });
  });

  group('what map 01 remembers', () {
    testWidgets(
        'after meeting the companion, coming back to map 01 '
        'skips the talk and leaves the controls free', (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      await _meetCompanion(tester, mapOne);

      final back = await _roundTrip(tester, mapOne);
      // The hero lands right next to the new companion (inside its talk
      // radius), but it is already following: no scene, no dialogue.
      await _run(tester, 2);
      expect(back.sceneBuilderStatus.isRunning, isFalse);
      expect(_dialogue, findsNothing);
      expect(back.query<Companion>().single.isFollowing, isTrue);

      // The keyboard still works: Space jumps. (Jumping, because the wall
      // at columns 19-22 is right behind the hero and the companion is in
      // front.)
      final hero = back.player! as Hero;
      final y = hero.y;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _run(tester, 0.2);
      expect(hero.y, lessThan(y - TILE_SIZE / 2));
    });

    testWidgets('a defeated foe stays gone when the hero comes back',
        (tester) async {
      final mapOne = await _pumpGameScreen(tester);
      final foe = mapOne.query<Foe>().single;
      foe.life
          .handleAttack(AttackOriginEnum.PLAYER_OR_ALLY, foe.life.max, null);
      // Its death animation plays, then it removes itself.
      await _run(tester, 2, until: () => !foe.isMounted);
      expect(foe.isMounted, isFalse);

      final back = await _roundTrip(tester, mapOne);
      expect(back.query<Foe>(), isEmpty);
    });

    testWidgets('a foe that was not defeated is back on return',
        (tester) async {
      // _walkThroughExit only moves the foe out of the way, it doesn't
      // defeat it, so map 01 is built with a new one.
      final mapOne = await _pumpGameScreen(tester);
      final back = await _roundTrip(tester, mapOne);
      expect(back.query<Foe>(), hasLength(1));
    });
  });

  group('MapExit', () {
    test(
        "map 01's exit covers column 29 from row 4 (above the ledge) "
        'down to the ground', () {
      final rect = Rect.fromLTWH(
        GameScreen.mapOneExitPosition().x,
        GameScreen.mapOneExitPosition().y,
        GameScreen.mapOneExitSize().x,
        GameScreen.mapOneExitSize().y,
      );
      expect(rect, const Rect.fromLTWH(928, 128, 32, 160));
      // A hero standing on the ledge at (29, 5) is in row 4: inside it.
      expect(
        rect.overlaps(Rect.fromLTWH(28.5 * TILE_SIZE, 4 * TILE_SIZE, 32, 32)),
        isTrue,
      );
      // And so is a hero walking along the ground (row 7).
      expect(
        rect.overlaps(Rect.fromLTWH(28.5 * TILE_SIZE, 7 * TILE_SIZE, 32, 32)),
        isTrue,
      );
    });

    testWidgets('ignores a dead hero', (tester) async {
      var entered = 0;
      final exit = MapExit(
        position: Vector2(26, 5) * TILE_SIZE,
        size: GameScreen.mapTwoExitSize(),
        onEnter: () => entered++,
      );
      // The hero dies outside the exit, then its body is pushed into it.
      final hero = Hero(Vector2(23, 7) * TILE_SIZE);
      await _pumpExitGame(tester, hero: hero, exit: exit);
      hero.life.handleAttack(AttackOriginEnum.WORLD, hero.life.max, null);
      await _run(tester, 0.5);
      expect(hero.isDead, isTrue);
      hero.position = Vector2(26, 7) * TILE_SIZE;

      await _run(tester, 1);
      expect(hero.toAbsoluteRect().overlaps(exit.toAbsoluteRect()), isTrue);
      expect(entered, 0);
    });

    testWidgets('fires once while the hero stands in it, and again on return',
        (tester) async {
      var entered = 0;
      // Columns 23-29 of map 01 are flat open ground, so the hero can walk
      // out of an exit at column 26 and back in.
      final exit = MapExit(
        position: Vector2(26, 5) * TILE_SIZE,
        size: GameScreen.mapTwoExitSize(),
        onEnter: () => entered++,
      );
      // Standing right inside the exit.
      final hero = Hero(Vector2(26, 7) * TILE_SIZE);
      await _pumpExitGame(tester, hero: hero, exit: exit);

      // A second inside it: one call, not one every 100 ms.
      await _run(tester, 1);
      expect(entered, 1);
      expect(exit.timesEntered, 1);

      // Walk out to the left, then back in: it fires again, once.
      hero.moveLeft();
      await _run(
        tester,
        3,
        until: () =>
            hero.toAbsoluteRect().right < exit.toAbsoluteRect().left - 8,
      );
      hero.stop();
      await _run(tester, 0.2);
      expect(hero.toAbsoluteRect().overlaps(exit.toAbsoluteRect()), isFalse);
      expect(entered, 1);

      hero.moveRight();
      await _run(tester, 2, until: () => entered == 2);
      hero.stop();
      await _run(tester, 1);
      expect(entered, 2);
    });

    testWidgets('ignores the companion', (tester) async {
      var entered = 0;
      final exit = MapExit(
        position: Vector2(26, 5) * TILE_SIZE,
        size: GameScreen.mapTwoExitSize(),
        onEnter: () => entered++,
      );
      // The hero waits far away while the companion stands in the exit.
      final hero = Hero(Vector2(1, 7) * TILE_SIZE);
      await _pumpExitGame(tester, hero: hero, exit: exit);
      await exit.parent!.add(Companion(Vector2(26, 7) * TILE_SIZE));

      await _run(tester, 1);
      expect(entered, 0);
    });
  });
}
