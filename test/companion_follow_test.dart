import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Shorthand: what the companion does with the hero at [dx] (and
  // [distance], defaulting to |dx|) when nothing blocks the way.
  // [stepUp] is how far the hero's feet are above the companion's.
  FollowAction act(
    double dx, {
    double? distance,
    bool canMove = true,
    double stepUp = 0,
    bool onGround = true,
  }) =>
      Companion.followAction(
        dx: dx,
        distance: distance ?? dx.abs(),
        canMove: canMove,
        stepUp: stepUp,
        onGround: onGround,
      );

  group('Companion.followAction', () {
    test('walks right when the hero is to the right', () {
      expect(act(100), FollowAction.right);
    });

    test('walks left when the hero is to the left', () {
      expect(act(-100), FollowAction.left);
    });

    test('stops exactly at the follow distance', () {
      expect(act(Companion.followDistance), FollowAction.stop);
      expect(act(-Companion.followDistance), FollowAction.stop);
    });

    test('keeps walking just past the follow distance', () {
      expect(act(Companion.followDistance + 0.1), FollowAction.right);
      expect(act(-Companion.followDistance - 0.1), FollowAction.left);
    });

    test('stops when a wall or step is in the way', () {
      expect(act(100, canMove: false), FollowAction.stop);
      expect(act(-100, canMove: false), FollowAction.stop);
    });

    test('loses the hero just past the follow radius', () {
      expect(
        act(100, distance: Companion.followRadius + 0.1),
        FollowAction.lost,
      );
    });

    test('still follows right at the follow radius', () {
      expect(
        act(100, distance: Companion.followRadius),
        FollowAction.right,
      );
    });

    test('waits below when the hero is straight above on a ledge', () {
      // Hero 96px up, 10px across: close enough sideways, so stand still.
      expect(act(10, distance: 96.5), FollowAction.stop);
    });

    test('jumps when a one-tile step is in the way and the hero is on it', () {
      expect(
          act(60, canMove: false, stepUp: TILE_SIZE), FollowAction.jumpRight);
      expect(
          act(-60, canMove: false, stepUp: TILE_SIZE), FollowAction.jumpLeft);
      // Even when already close sideways.
      expect(
          act(20, canMove: false, stepUp: TILE_SIZE), FollowAction.jumpRight);
    });

    test('walks to the foot of the step before jumping', () {
      // Within the follow distance, but the hero is up a step: keep going.
      expect(act(30, stepUp: TILE_SIZE), FollowAction.right);
      // Right underneath the hero: nowhere to go.
      expect(act(4, stepUp: TILE_SIZE), FollowAction.stop);
    });

    test("doesn't jump again while in the air", () {
      expect(
        act(60, canMove: false, stepUp: TILE_SIZE, onGround: false),
        FollowAction.stop,
      );
    });

    test('waits below a step too high to reach', () {
      expect(
        act(60, canMove: false, stepUp: Companion.maxStep + 1),
        FollowAction.stop,
      );
      expect(act(20, stepUp: 3 * TILE_SIZE), FollowAction.stop);
    });

    test("doesn't jump at a wall when the hero is on the same ground", () {
      expect(act(60, canMove: false, stepUp: 2), FollowAction.stop);
    });

    test('still waits for a lost hero, even up a step', () {
      expect(
        act(60,
            distance: Companion.followRadius + 1,
            canMove: false,
            stepUp: TILE_SIZE),
        FollowAction.lost,
      );
    });
  });
}
