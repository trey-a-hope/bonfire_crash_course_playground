// lib/presentation/characters/util/animation_utils.dart
import 'package:bonfire/bonfire.dart';

/// Utility helpers for loading sprite animations.
abstract class AnimationUtils {
  /// Turns a sprite sheet into a looping animation.
  ///
  /// - [path]: Asset path relative to `assets/images/`.
  /// - [amount]: Number of frames in the sheet (defaults to 4).
  /// - [stepTime]: Duration (in seconds) per frame.
  /// - [textureSize]: Frame dimension (defaults to 32x32).
  /// - [loop]: Whether the animation repeats (defaults to true). Use false for
  ///   one-shot animations such as attacks.
  /// - [start]: The frame (0-based) to start from (defaults to 0). With
  ///   `amount: 1` it picks out a single frame, such as the last frame of a
  ///   death sheet to hold once the animation is over.
  static Future<SpriteAnimation> loadAnimation(
    String path, {
    int amount = 4,
    double stepTime = 0.1,
    Vector2? textureSize,
    bool loop = true,
    int start = 0,
  }) {
    final size = textureSize ?? Vector2.all(32);
    return SpriteAnimation.load(
      path,
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: size,
        loop: loop,
        texturePosition: Vector2(start * size.x, 0),
      ),
    );
  }
}
