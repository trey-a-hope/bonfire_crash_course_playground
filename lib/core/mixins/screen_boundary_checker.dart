// Bonfire is the game engine we use to make our game.
import 'package:bonfire/bonfire.dart';

/// Keeps something from walking off the edge of the map.
///
/// This is a mixin: extra code you can add to a class with the word `with`.
mixin ScreenBoundaryChecker on GameComponent {
  /// Pushes the character back inside the map if they go past an edge.
  /// Call this in [update] so it checks every frame.
  void checkBoundaries() {
    // How wide and tall the map is.
    final mapSize = gameRef.map.size;

    // Half of the character's width. Lets them go a little past the edge so
    // they line up nicely with it.
    final collisionBuffer = size.x / 2;

    // Keep the character between the left and right edges. On the right,
    // they stop right at the edge.
    position.x = position.x.clamp(
      -collisionBuffer,
      mapSize.x - size.x,
    );

    // Keep the character between the top and bottom edges.
    position.y = position.y.clamp(
      -collisionBuffer,
      mapSize.y - collisionBuffer,
    );
  }
}
