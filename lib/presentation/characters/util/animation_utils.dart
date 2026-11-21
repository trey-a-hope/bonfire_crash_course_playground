// lib/presentation/characters/util/animation_utils.dart
import 'dart:ui';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';

enum AnimationUtilsDirection { IDLE_RIGHT, RUN_RIGHT, IDLE_LEFT, RUN_LEFT }

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
  static Future<SpriteAnimation> loadAnimation({
    required String path,
    int amount = 4,
    double stepTime = 0.1,
    Vector2? textureSize,
    bool loop = true,
    int start = 0,
  }) async {
    final size = textureSize ?? Vector2.all(32);
    return await SpriteAnimation.load(
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

  static Future<SpriteAnimation> buildMoveAnimation({
    required CharacterAsset asset,
    required AnimationUtilsDirection direction,
    int amount = 4,
    double stepTime = 0.2,
    Vector2? textureSize,
    bool loop = true,
    int start = 0,
  }) async {
    final size = textureSize ?? Vector2.all(32);

    late String path;

    switch (direction) {
      case AnimationUtilsDirection.IDLE_RIGHT:
        path = asset.idleRight;
      case AnimationUtilsDirection.RUN_RIGHT:
        path = asset.runRight;
      case AnimationUtilsDirection.IDLE_LEFT:
        path = asset.idleLeft;
      case AnimationUtilsDirection.RUN_LEFT:
        path = asset.runRight;
    }

    return await SpriteAnimation.load(
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

  /// Builds the jump animations for any character.
  static PlatformJumpAnimations buildJumpAnimations({
    required CharacterAsset asset,
    int frames = 6, // how many pictures are in the jump sheet
  }) {
    // One picture sheet turned into an animation.
    // We call this once for each sheet we need.
    Future<SpriteAnimation> load(String path) => AnimationUtils.loadAnimation(
          path: path,
          amount: frames,
        );

    return PlatformJumpAnimations(
      jumpUpRight: load(asset.jumpRight),
      jumpDownRight: load(asset.jumpRight),
      jumpUpLeft: load(asset.jumpLeft),
      jumpDownLeft: load(asset.jumpLeft),
    );
  }

  /// Builds the melee and range attack animations for any character.
  static Map<String, Future<SpriteAnimation>> buildAttackAnimations({
    required CharacterAsset asset,
  }) {
    // One attack sheet turned into a one-time animation.
    // Attacks play once and stop, so loop is false.
    Future<SpriteAnimation> load(String path, int frames) =>
        AnimationUtils.loadAnimation(
          path: path,
          amount: frames,
          stepTime: ATTACK_STEP_TIME,
          loop: false,
        );

    return {
      MELEE_ATTACK_LEFT: load(asset.attackMeleeLeft, asset.attackMeleeFrames),
      MELEE_ATTACK_RIGHT: load(asset.attackMeleeRight, asset.attackMeleeFrames),
      RANGE_ATTACK_LEFT: load(asset.attackRangeLeft, asset.attackRangeFrames),
      RANGE_ATTACK_RIGHT: load(asset.attackRangeRight, asset.attackRangeFrames),
    };
  }
}
