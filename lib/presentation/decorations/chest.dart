import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';

/// A treasure chest that opens when the hero touches it: a decoration that
/// reacts to the player.
///
/// [WithSensor] gives the chest a hitbox that notices what overlaps it
/// without blocking anything, so the hero walks right through. `<Player>`
/// means only the player counts: the companion and the foe can't open it.
class Chest extends GameDecoration with BehindCharacters, WithSensor<Player> {
  /// True once the hero has opened the chest. It never closes again.
  bool isOpen = false;

  /// Creates the chest at [position] (in pixels from the map's top-left).
  Chest(Vector2 position)
      : super.withSprite(
          sprite: Sprite.load(CHEST_CLOSED),
          position: position,
          size: Vector2.all(TILE_SIZE),
        );

  /// Runs once when the chest is added to the game.
  @override
  Future<void> onLoad() async {
    // WithSensor gives the chest a hitbox the size of the whole tile, so it
    // opens as soon as the hero touches it.
    //
    // Called while the hero overlaps the chest (checked every 100 ms).
    sensor.onContactListener((_) => _open());
    return super.onLoad();
  }

  /// Opens the chest and swaps in the open sprite.
  ///
  /// The sensor's job is done once the chest is open, so it is switched off
  /// with `sensor.enabled = false`, as the Bonfire sensor doc shows. It stops
  /// checking for contact, and [_open] is never called again.
  Future<void> _open() async {
    sensor.enabled = false;
    isOpen = true;
    sprite = await Sprite.load(CHEST_OPEN);
  }
}
