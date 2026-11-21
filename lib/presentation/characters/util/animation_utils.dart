// lib/presentation/characters/util/animation_utils.dart
// Needed for `VoidCallback` used by `playAttackAnimation`.
import 'dart:ui';

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
  ///
  /// [path] is now a required named parameter, so call sites read as
  /// `loadAnimation(path: '...')`.
  static Future<SpriteAnimation> loadAnimation({
    required String path,
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

  /// Plays a one-shot attack animation facing the character's [direction].
  ///
  /// - [attackLeft] / [attackRight]: Keys of the attack animations registered
  ///   in [animation]'s `others` map. The left one is used when [direction]
  ///   is on the left side, otherwise the right one.
  /// - [animation]: The character's direction animation set to play on.
  /// - [direction]: The direction the character is currently facing.
  /// - [onFinish]: Called once the animation has run to its last frame.
  static Future<void> playAttackAnimation({
    required String attackLeft,
    required String attackRight,
    required SimpleDirectionAnimation animation,
    required Direction direction,
    required VoidCallback onFinish,
  }) async =>
      animation.playOnceOther(
        direction.isLeftSide ? attackLeft : attackRight,
        runToTheEnd: true,
        onFinish: onFinish,
      );
}
