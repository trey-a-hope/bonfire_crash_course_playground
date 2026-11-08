import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/debug/collision_boxes.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a game on map 01 with the [hero] and [boxes], and returns once
/// every asset has loaded and the game is running.
Future<void> _pumpGame(
  WidgetTester tester, {
  required Hero hero,
  required CollisionBoxes boxes,
}) async {
  var ready = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BonfireWidget(
        globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
        player: hero,
        components: [boxes],
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
  await tester.pump(const Duration(milliseconds: 16));
}

/// A one-tile block with a hitbox, for adding to the world mid-game.
class _Block extends GameDecoration {
  _Block(Vector2 position)
      : super(position: position, size: Vector2.all(TILE_SIZE));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size));
    return super.onLoad();
  }
}

void main() {
  // Each test runs in its own fake-async zone. A cached asset load from an
  // earlier test never completes in a later one, so start every test cold.
  setUp(() {
    rootBundle.clear();
    Flame.assets.clearCache();
  });

  testWidgets('hitboxes added later are outlined too', (tester) async {
    final hero = Hero(Vector2(100, 100));
    final boxes = CollisionBoxes(visible: true);
    await _pumpGame(tester, hero: hero, boxes: boxes);

    final later = _Block(Vector2(200, 100));
    await boxes.parent!.add(later);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(later.children.whereType<ShapeHitbox>().single.renderShape, isTrue);
  });
}
