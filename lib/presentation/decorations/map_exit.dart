import 'package:bonfire/bonfire.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

/// An invisible doorway at the edge of a map. When the hero walks into it,
/// it calls [onEnter], which `GameScreen` uses to take them to the next map
/// with `MapNavigator`.
///
/// [WithSensor] notices the hero without blocking anyone, and `<Player>`
/// means only the hero counts: the companion and the foe can wander into it
/// without changing the map.
///
/// It is a plain [GameComponent] rather than a `GameDecoration`: it draws
/// nothing, and a decoration grows itself by a pixel on every side (to hide
/// seams between sprites), which would make the exit's edges a pixel off.
///
/// The exit doesn't know about maps or `MapNavigator` itself. `GameScreen`
/// passes the navigation in as [onEnter], because it has the `BuildContext`
/// that `MapNavigator.of(context)` needs and a Flame component doesn't. That
/// keeps the exit reusable: any edge of any map can have one.
class MapExit extends GameComponent with WithSensor<Player> {
  /// What to do when the hero walks in, such as
  /// `() => navigator.toNamed('/map2', arguments: ...)`.
  final VoidCallback onEnter;

  /// Whether the next contact should call [onEnter]. Off from the moment the
  /// exit fires until the hero walks back out, so a hero standing in the
  /// exit only triggers it once.
  bool _armed = true;

  /// How many times the exit has fired. Tests use it to check that a hero
  /// standing in the exit doesn't keep firing it.
  int get timesEntered => _timesEntered;
  int _timesEntered = 0;

  /// Creates an exit covering [size] pixels at [position] (from the map's
  /// top-left), usually one tile wide and a few tiles tall.
  MapExit({
    required Vector2 position,
    required Vector2 size,
    required this.onEnter,
  }) {
    this.position = position;
    this.size = size;
  }

  /// Runs once when the exit is added to the game.
  @override
  Future<void> onLoad() async {
    // No hitbox of our own, so WithSensor adds one the size of the exit:
    // passive, so it never blocks anyone.
    //
    // The first listener runs while the hero overlaps the exit (checked
    // every 100 ms). It fires once (and never for a dead hero), then waits
    // for the second listener, which runs when the hero walks back out,
    // before it can fire again.
    sensor.onContactListener(_enter);
    sensor.onContactEndListener((_) => _armed = true);
    return super.onLoad();
  }

  /// Calls [onEnter], unless the exit has already fired for this visit or
  /// the [hero] is dead (a knockback can shove a defeated hero's body into
  /// the exit, and a body shouldn't change maps).
  void _enter(Player hero) {
    if (!_armed || hero.isDead) return;
    _armed = false;
    _timesEntered++;
    onEnter();
  }
}
