import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/movement_utils.dart';

/// A behavior that paces a platform character left and right between two
/// x positions, pausing for a moment at each end before turning around.
///
/// Bonfire's own `BRandomMovement` never starts moving in Bonfire 4.0.0: it
/// rebuilds its wait timer every frame, so the timer never runs out. This
/// behavior paces back and forth instead, which also looks more deliberate.
///
/// It only ever changes the horizontal speed, so gravity keeps working while
/// it runs.
class BPatrol extends Behavior {
  /// Leftmost x (in pixels) of the character's position while patrolling.
  final double minX;

  /// Rightmost x (in pixels) of the character's position while patrolling.
  final double maxX;

  /// Walking speed while patrolling; the character's own speed if null.
  final double? speed;

  /// Waits at each end before turning around.
  final IntervalTick _pause;

  /// The way the character is walking (or will walk after the pause).
  Direction _heading = Direction.left;

  /// True while standing at one end, waiting to turn around.
  bool _isPausing = false;

  /// Creates a patrol between [minX] and [maxX], pausing [pauseMs]
  /// milliseconds at each end.
  BPatrol({
    required this.minX,
    required this.maxX,
    this.speed,
    int pauseMs = 1000,
    super.id,
  })  : assert(minX < maxX),
        _pause = IntervalTick(pauseMs);

  @override
  bool process(double dt, GameComponent comp, BonfireGameInterface game) {
    if (comp is! Movement) return true;

    if (_isPausing) {
      comp.stopWalking();
      if (_pause.update(dt)) {
        _isPausing = false;
        _heading =
            _heading == Direction.left ? Direction.right : Direction.left;
      }
      // Patrolling never ends on its own, but it doesn't block the list.
      return true;
    }

    final atEnd = _heading == Direction.left ? comp.x <= minX : comp.x >= maxX;
    // A wall in the way counts as an end too.
    if (atEnd || !comp.canMove(_heading)) {
      comp.stopWalking();
      _isPausing = true;
      return true;
    }

    // moveLeft and moveRight leave the vertical speed alone.
    if (_heading == Direction.left) {
      comp.moveLeft(speed: speed);
    } else {
      comp.moveRight(speed: speed);
    }
    return true;
  }
}
