import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';

/// A patch of red mushrooms to dress the ground. Like [Sign], one sprite.
class Mushrooms extends GameDecoration with BehindCharacters {
  /// Creates the mushrooms at [position] (in pixels from the map's top-left).
  Mushrooms(Vector2 position)
      : super.withSprite(
          sprite: Sprite.load(MUSHROOMS),
          position: position,
          size: Vector2.all(TILE_SIZE),
        );
}
