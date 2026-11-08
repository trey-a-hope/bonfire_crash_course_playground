import 'package:bonfire/bonfire.dart';

/// Runs [child], then puts back the vertical speed the character had before.
///
/// Bonfire's movement behaviors (like `BSeeAndMoveToTarget`) call `stop()`
/// and move with `resetCrossAxis`, which set the vertical speed to 0. In a
/// platformer that cancels gravity every frame, so a character walking off
/// a ledge would float down slowly. Wrapping them in this behavior keeps the
/// fall speed.
class BKeepFallSpeed extends Behavior {
  /// The behavior to run.
  final Behavior child;

  /// Wraps [child].
  BKeepFallSpeed(this.child, {super.id});

  @override
  bool process(double dt, GameComponent comp, BonfireGameInterface game) {
    if (comp is! Movement) return child.process(dt, comp, game);

    final fallSpeed = comp.velocity.y;
    final finished = child.process(dt, comp, game);
    comp.velocity = comp.velocity.copyWith(y: fallSpeed);
    return finished;
  }
}
