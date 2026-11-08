import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/brass_key.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/campfire.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/chest.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/mushrooms.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/sign.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and [decorations], and returns
/// once every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required List<GameComponent> decorations,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: decorations,
        map: WorldMapBySpritefusion(WorldMapReader.fromAsset(MAP_ONE)),
        onReady: (_) => ready = true,
      ),
    ),
  );
  // Images and the map load with real async work, so give it real time
  // outside the test's fake clock.
  for (var i = 0; i < 50 && !ready; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready, isTrue, reason: 'the game never became ready');
}

/// Advances the game by [seconds], one 16 ms frame at a time.
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Lets a sprite swap that loads an image finish, outside the fake clock.
Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await _run(tester, 0.1);
}

/// The ground under row 7 of map 01 starts at row 8.
const _groundY = 8 * TILE_SIZE;

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('every decoration stands on the ground', (tester) async {
    final decorations = [
      Sign(Vector2(1, 7) * TILE_SIZE),
      Campfire(Vector2(12, 7) * TILE_SIZE),
      Mushrooms(Vector2(16, 7) * TILE_SIZE),
      Chest(Vector2(18, 7) * TILE_SIZE),
    ];
    await _pumpGame(
      tester,
      hero: Hero(Vector2(3, 7) * TILE_SIZE),
      decorations: decorations,
    );
    await _run(tester, 1);

    for (final decoration in decorations) {
      expect(decoration.isMounted, isTrue);
      // Decorations have no gravity, so they stay exactly where placed.
      expect(decoration.toAbsoluteRect().bottom, closeTo(_groundY, 2));
    }
  });

  testWidgets('the campfire keeps animating', (tester) async {
    final campfire = Campfire(Vector2(12, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: Hero(Vector2(3, 7) * TILE_SIZE),
      decorations: [campfire],
    );

    final frames = <int>{};
    for (var i = 0; i < 20; i++) {
      await _run(tester, 0.1);
      frames.add(campfire.animationCurrentIndex);
    }
    // 4 frames at 0.15s each, sampled over 2 seconds: it loops through all.
    expect(frames, {0, 1, 2, 3});
  });

  testWidgets('the chest opens when the hero reaches it, and stays open',
      (tester) async {
    final chest = Chest(Vector2(18, 7) * TILE_SIZE);
    // Two tiles left of the chest, on the flat ground at columns 16-18.
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, decorations: [chest]);
    await _run(tester, 1);

    // Far away: still closed, and its sensor is watching for the hero.
    expect(chest.isOpen, isFalse);
    expect(chest.sensor.enabled, isTrue);
    expect(chest.sprite!.image, same(Flame.images.fromCache(CHEST_CLOSED)));

    // Walk right until the hero reaches the chest.
    hero.moveRight();
    for (var i = 0; i < 300 && !chest.isOpen; i++) {
      await _run(tester, 0.016);
    }
    hero.stop();
    await _load(tester);
    expect(chest.isOpen, isTrue);
    // Open, so its sensor is switched off.
    expect(chest.sensor.enabled, isFalse);
    // It shows the open image now, not the closed one.
    final openSprite = chest.sprite;
    expect(openSprite!.image, same(Flame.images.fromCache(CHEST_OPEN)));

    // Walk away again: it doesn't close.
    hero.moveLeft();
    await _run(tester, 2);
    hero.stop();
    await _load(tester);
    expect(chest.isOpen, isTrue);
    expect(chest.sprite, same(openSprite));
    expect(chest.sensor.enabled, isFalse);
  });

  testWidgets('once open, the chest stops checking for the hero',
      (tester) async {
    final chest = Chest(Vector2(18, 7) * TILE_SIZE);
    // Right on top of the chest, so it opens straight away.
    final hero = Hero(Vector2(18, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, decorations: [chest]);
    // Counts every contact the sensor reports, like the chest's own
    // listener does.
    var contacts = 0;
    chest.sensor.onContactListener((_) => contacts++);
    for (var i = 0; i < 100 && !chest.isOpen; i++) {
      await _run(tester, 0.016);
    }
    await _load(tester);
    expect(chest.isOpen, isTrue);
    final atOpen = contacts;

    // The hero keeps standing on the open chest: no more contacts.
    await _run(tester, 1);
    expect(hero.toAbsoluteRect().overlaps(chest.toAbsoluteRect()), isTrue);
    expect(contacts, atOpen);
  });

  testWidgets('the companion and the foe cannot open the chest',
      (tester) async {
    // The hero waits at the far left of the map, out of the way.
    final hero = Hero(Vector2(1, 7) * TILE_SIZE);
    // Both stand right on top of the chest.
    final chest = Chest(Vector2(18, 7) * TILE_SIZE);
    final companion = Companion(Vector2(18, 7) * TILE_SIZE);
    final foe = Foe(Vector2(18, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: hero,
      decorations: [chest, companion, foe],
    );
    await _run(tester, 1);
    await _load(tester);

    expect(chest.isOpen, isFalse);
    expect(chest.sprite!.image, same(Flame.images.fromCache(CHEST_CLOSED)));
    // Still waiting for the hero.
    expect(chest.sensor.enabled, isTrue);
  });

  testWidgets('the chest does not block the hero', (tester) async {
    // Two tiles left of the chest, which stands against the wall at
    // column 19.
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: hero,
      decorations: [Chest(Vector2(17, 7) * TILE_SIZE)],
    );
    await _run(tester, 0.5);

    hero.moveRight();
    await _run(tester, 1.5);
    hero.stop();

    // The hero walked through the chest and only stopped at the wall.
    expect(hero.x, closeTo(18 * TILE_SIZE, 2));
  });

  testWidgets('the brass key rests on top of the raised block', (tester) async {
    final key = BrassKey(Vector2(10, 5) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: Hero(Vector2(3, 7) * TILE_SIZE),
      decorations: [key],
    );
    await _run(tester, 1);

    // The block at columns 9-11 starts at row 6. The key bobs up to
    // BrassKey.bobHeight above it.
    expect(
      key.toAbsoluteRect().bottom,
      inInclusiveRange(
          6 * TILE_SIZE - BrassKey.bobHeight - 2, 6 * TILE_SIZE + 2),
    );
    // Half a tile wide (GameDecoration pads it a little), centred in its
    // tile.
    expect(key.size.x, closeTo(TILE_SIZE / 2, 1));
    expect(key.toAbsoluteRect().center.dx, closeTo(10.5 * TILE_SIZE, 1));
  });

  testWidgets('the hero picks up the brass key by walking through it',
      (tester) async {
    // Flat ground at columns 16-18, ending at the wall at column 19.
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final key = BrassKey(Vector2(17, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, decorations: [key]);
    await _run(tester, 0.5);
    expect(key.isMounted, isTrue);

    hero.moveRight();
    await _run(tester, 1.5);
    hero.stop();
    // Long enough for the pop to finish.
    await _run(tester, 0.5);

    // Gone from the world, with its sensor off, and it didn't stop the hero.
    expect(key.isPickedUp, isTrue);
    expect(key.sensor.enabled, isFalse);
    expect(key.isMounted, isFalse);
    expect(hero.x, closeTo(18 * TILE_SIZE, 2));
  });

  testWidgets('the hero can collect the brass key where the game puts it',
      (tester) async {
    // The key's real spot, on top of the raised block at columns 9-11. The
    // hero lands on the block one tile to its left.
    final hero = Hero(Vector2(9, 4) * TILE_SIZE);
    final key = BrassKey(Vector2(10, 5) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, decorations: [key]);
    await _run(tester, 1);
    // Standing on the block, not inside it or below it.
    expect(hero.toAbsoluteRect().bottom, closeTo(6 * TILE_SIZE, 2));
    expect(key.isMounted, isTrue);

    hero.moveRight();
    for (var i = 0; i < 100 && !key.isPickedUp; i++) {
      await _run(tester, 0.016);
    }
    hero.stop();
    // Long enough for the pop to finish.
    await _run(tester, 0.5);

    expect(key.isPickedUp, isTrue);
    expect(key.isMounted, isFalse);
  });

  testWidgets('the companion and the foe cannot pick up the brass key',
      (tester) async {
    final key = BrassKey(Vector2(18, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: Hero(Vector2(1, 7) * TILE_SIZE),
      decorations: [
        key,
        Companion(Vector2(18, 7) * TILE_SIZE),
        Foe(Vector2(18, 7) * TILE_SIZE),
      ],
    );
    await _run(tester, 1);

    expect(key.isPickedUp, isFalse);
    expect(key.isMounted, isTrue);
    expect(key.sensor.enabled, isTrue);
  });

  testWidgets('decorations do not block the hero', (tester) async {
    // Columns 16-18 are flat ground ending at the wall at column 19. The
    // mushrooms stand in the middle, right in the hero's way.
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    await _pumpGame(
      tester,
      hero: hero,
      decorations: [Mushrooms(Vector2(17, 7) * TILE_SIZE)],
    );
    await _run(tester, 0.5);

    hero.moveRight();
    await _run(tester, 1.5);
    hero.stop();

    // The hero walked through the mushrooms and only stopped at the wall.
    expect(hero.x, closeTo(18 * TILE_SIZE, 2));
  });

  testWidgets('decorations draw behind the hero', (tester) async {
    final hero = Hero(Vector2(16, 7) * TILE_SIZE);
    final mushrooms = Mushrooms(Vector2(16, 7) * TILE_SIZE);
    await _pumpGame(tester, hero: hero, decorations: [mushrooms]);
    await _run(tester, 1);

    // Both stand on the same ground, so Bonfire's bottom-edge ordering
    // alone can't decide: the hero must still be drawn on top.
    expect(mushrooms.priority, lessThan(hero.priority));
  });
}
