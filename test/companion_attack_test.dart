import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero], the [companion] and the [foe],
/// and returns once every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required Companion companion,
  required Foe foe,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [companion, foe],
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

/// Every hit the [foe] takes, with the game time (in seconds since the
/// listener was added) it landed at.
class _Hits {
  final times = <double>[];
  final origins = <AttackOriginEnum>[];
  double clock = 0;
}

/// A game on the flat ground at columns 23-29: the hero, the companion one
/// tile to the right of [heroColumn] (unless given), and the shark at
/// [foeColumn]. The shark stands still (its behaviors are paused), so only
/// the companion fights.
///
/// With [following], the companion starts out following, skipping its
/// first talk (the hero is close enough to start it, and the dialogue would
/// pause the game). The shark loads at the far end of the ground and is put
/// in place once the game is ready, so no swipe lands while it loads.
Future<(Hero, Companion, Foe)> _game(
  WidgetTester tester, {
  double heroColumn = 24,
  double companionColumn = 25,
  double foeColumn = 26,
  bool following = true,
}) async {
  final hero = Hero(Vector2(heroColumn, 7) * TILE_SIZE);
  final companion = Companion(Vector2(companionColumn, 7) * TILE_SIZE);
  if (following) companion.startFollowing();
  final foe = Foe(Vector2(29, 7) * TILE_SIZE);
  await _pumpGame(tester, hero: hero, companion: companion, foe: foe);
  foe.pauseBehaviors();
  foe.position = Vector2(foeColumn, 7) * TILE_SIZE;
  return (hero, companion, foe);
}

/// Records the [foe]'s hits while running the game for [seconds].
Future<_Hits> _watch(WidgetTester tester, Foe foe, double seconds) async {
  final hits = _Hits();
  foe.life.onReceiveDamageListener((origin, damage, id) {
    hits.times.add(hits.clock);
    hits.origins.add(origin);
  });
  final frames = (seconds * 1000 / 16).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    hits.clock += 0.016;
  }
  return hits;
}

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('a following companion swipes at a foe in reach', (
    tester,
  ) async {
    final (_, companion, foe) = await _game(tester);

    final hits = await _watch(tester, foe, 0.2);
    expect(hits.times, hasLength(1));
    expect(hits.origins, [AttackOriginEnum.PLAYER_OR_ALLY]);
    expect(foe.life.value, foe.life.max - Companion.attackDamage);
    // The swipe is playing.
    expect(companion.animation!.fastAnimationcurrentIndex, greaterThan(0));
  });

  testWidgets('it faces the foe: flipped for a foe on the left', (
    tester,
  ) async {
    // Shark on the left this time, a tile left of the companion.
    final (_, companion, foe) = await _game(
      tester,
      heroColumn: 26,
      foeColumn: 24,
    );

    await _run(tester, 0.1);
    expect(foe.life.value, foe.life.max - Companion.attackDamage);
    expect(companion.animation!.isFlipHorizontallyFastAnimation, isTrue);
  });

  testWidgets('a foe on the right gets an unflipped swipe', (tester) async {
    final (_, companion, foe) = await _game(tester);

    await _run(tester, 0.1);
    expect(foe.life.value, lessThan(foe.life.max));
    expect(companion.animation!.isFlipHorizontallyFastAnimation, isFalse);
  });

  testWidgets('it swipes at most once a second', (tester) async {
    final (_, companion, foe) = await _game(tester);

    final hits = await _watch(tester, foe, 3.5);
    expect(hits.times, hasLength(4));
    for (var i = 1; i < hits.times.length; i++) {
      expect(hits.times[i] - hits.times[i - 1], closeTo(1, 0.05));
    }
  });

  testWidgets('it never hurts the hero', (tester) async {
    final (hero, companion, foe) = await _game(tester);
    final origins = <AttackOriginEnum>[];
    hero.life.onReceiveDamageListener((origin, _, __) => origins.add(origin));

    await _run(tester, 2.5);
    expect(foe.life.value, lessThan(foe.life.max));
    expect(origins, isEmpty);
    expect(hero.life.value, hero.life.max);
    // Its attacks are PLAYER_OR_ALLY ones, which the hero never takes.
    expect(
      hero.life.checkCanReceiveDamage(AttackOriginEnum.PLAYER_OR_ALLY),
      isFalse,
    );
  });

  testWidgets("it leaves a foe out of reach alone", (tester) async {
    final (_, companion, foe) = await _game(tester, foeColumn: 28);

    final hits = await _watch(tester, foe, 2);
    expect(hits.times, isEmpty);
  });

  testWidgets("it doesn't attack before its first talk", (tester) async {
    // The hero is far off, so the companion never talks or follows, with
    // the shark right beside it.
    final (_, companion, foe) = await _game(
      tester,
      heroColumn: 16,
      following: false,
    );

    final hits = await _watch(tester, foe, 2);
    expect(companion.isFollowing, isFalse);
    expect(hits.times, isEmpty);
  });
}
