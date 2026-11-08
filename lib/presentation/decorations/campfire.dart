import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/animation_utils.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';

/// A crackling campfire: a decoration that plays a looping animation
/// instead of showing one sprite, and lights up the dusk around it.
class Campfire extends GameDecoration with BehindCharacters {
  /// The warm orange the light tints everything near the fire.
  static const lightColor = Color(0x40FF8C1A);

  /// How far the light reaches: 3 tiles from the fire's centre.
  static const lightRadius = 3 * TILE_SIZE;

  /// Creates the campfire at [position] (in pixels from the map's top-left).
  Campfire(Vector2 position)
      : super.withAnimation(
          // 4 frames of flickering flames, looping forever.
          animation: AnimationUtils.loadAnimation(
            CAMPFIRE,
            amount: 4,
            stepTime: 0.15,
          ),
          position: position,
          size: Vector2.all(TILE_SIZE),
          // Every GameDecoration already has Bonfire's WithLighting mixin, so
          // a light is just a LightingConfig. It only shows once the game
          // has a dark tint (lightingColorGame in game_screen.dart).
          lightingConfig: LightingConfig(
            radius: lightRadius,
            color: lightColor,
            // The light shrinks by up to about 10% and grows back, about
            // twice a second, so it flickers along with the flames. (Bonfire
            // eases the pulse, so a variation of 0.05 shrinks it by ~10%.)
            withPulse: true,
            pulseVariation: 0.05,
            pulseSpeed: 0.2,
          ),
        );
}
