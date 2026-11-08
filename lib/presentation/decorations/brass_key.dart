import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';
import 'package:flutter/animation.dart';

/// A brass key the hero picks up by touching it: the first item in the game.
///
/// Like the [Chest], it uses [WithSensor] so it notices the hero without
/// blocking anyone, and `<Player>` so only the hero can pick it up.
///
/// Flame effects bring it to life: it bobs up and down while it waits, and
/// pops (rises, grows and fades out) when the hero grabs it. Bonfire
/// components are Flame components, so effects work on them directly.
class BrassKey extends GameDecoration
    with BehindCharacters, WithSensor<Player> {
  /// The sprite is 32x32, as tall as the hero, so the key is drawn at half
  /// size. 2:1 keeps the pixel art crisp.
  static final keySize = Vector2.all(TILE_SIZE / 2);

  /// How far (in pixels) the key floats up and back down while it waits.
  static const bobHeight = 3.0;

  /// How long the key takes to float up (and the same again to come down).
  static const bobDuration = 0.6;

  /// How long the pop takes, from the hero's touch to the key being gone.
  static const popDuration = 0.3;

  /// How far (in pixels) the key rises during the pop: half a tile.
  static const popRise = TILE_SIZE / 2;

  /// How big the key grows during the pop.
  static const popScale = 1.5;

  /// True once the hero has picked the key up.
  bool isPickedUp = false;

  /// The endless up-and-down float, stopped when the key is picked up.
  late final MoveByEffect _bob;

  /// Creates the key in the tile whose top-left corner is at [tile] (in
  /// pixels from the map's top-left). It sits centred at the bottom of that
  /// tile, so it rests on the ground.
  BrassKey(Vector2 tile)
      : super.withSprite(
          sprite: Sprite.load(BRASS_KEY),
          position: tile +
              Vector2((TILE_SIZE - keySize.x) / 2, TILE_SIZE - keySize.y),
          size: keySize,
        );

  /// Runs once when the key is added to the game.
  @override
  Future<void> onLoad() async {
    // WithSensor gives the key a hitbox its own size. Called while the hero
    // overlaps it (checked every 100 ms).
    sensor.onContactListener((_) => _pickUp());
    // Up by bobHeight and back, easing at both ends, forever. `alternate`
    // plays the move forwards then backwards, so the key ends each loop
    // where it started.
    add(
      _bob = MoveByEffect(
        Vector2(0, -bobHeight),
        EffectController(
          duration: bobDuration,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
    return super.onLoad();
  }

  /// Pops the key and then takes it out of the world.
  ///
  /// The sensor is switched off first (`sensor.enabled = false`, as the
  /// Bonfire sensor doc shows), so it stops checking for contact and the key
  /// can't be picked up twice during the pop.
  void _pickUp() {
    sensor.enabled = false;
    isPickedUp = true;
    // Stop the float where it is. An infinite effect never finishes, so it
    // would never remove itself.
    _bob.removeFromParent();
    // Scaling grows the key from its top-left corner, so also move it left
    // and up by half the growth to keep it centred while it rises.
    final growth = size * (popScale - 1) / 2;
    add(
      SequenceEffect([
        // All three run together, for popDuration, starting fast.
        CombinedEffect(
          [
            MoveByEffect(Vector2(-growth.x, -popRise - growth.y), _popTiming),
            ScaleEffect.to(Vector2.all(popScale), _popTiming),
            OpacityEffect.fadeOut(_popTiming),
          ],
        ),
        // Then the key leaves the game.
        RemoveEffect(),
      ]),
    );
  }

  /// The timing every part of the pop shares.
  EffectController get _popTiming =>
      EffectController(duration: popDuration, curve: Curves.easeOut);
}
