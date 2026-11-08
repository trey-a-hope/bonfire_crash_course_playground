import 'package:bonfire/bonfire.dart';

/// Mixin that prevents a [GameComponent] from moving outside the map boundaries.
mixin ScreenBoundaryChecker on GameComponent {
  /// Clamps the component's position within the map edges.
  /// Typically called inside [update].
  void checkBoundaries() {
    // Total dimensions of the active game map.
    final mapSize = gameRef.map.size;

    // Half-width buffer allowing the sprite to align neatly with map edges.
    final collisionBuffer = size.x / 2;

    // Constrain horizontal position within map bounds. On the right the
    // whole sprite stays inside, so the hero stops flush with the map edge.
    position.x = position.x.clamp(
      -collisionBuffer,
      mapSize.x - size.x,
    );

    // Constrain vertical position within map bounds.
    position.y = position.y.clamp(
      -collisionBuffer,
      mapSize.y - collisionBuffer,
    );
  }
}
