import 'dart:ui';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';

/// Which movement sheet to load: standing still or running, facing left or
/// right.
enum SpriteDirection { IDLE_RIGHT, RUN_RIGHT, IDLE_LEFT, RUN_LEFT }

/// Utility helpers for loading sprite animations.
abstract class SpriteTools {
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
  static Future<SpriteAnimation> _loadAnimation({
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

  /// Builds an idle or run animation for a character.
  ///
  /// - [asset]: The character whose sprite sheets to use.
  /// - [direction]: Which sheet to load (idle/run, left/right).
  /// - [amount]: Number of frames in the sheet (defaults to 4).
  /// - [stepTime]: Duration (in seconds) per frame (defaults to 0.2).
  /// - [textureSize]: Frame dimension (defaults to 32x32).
  /// - [loop]: Whether the animation repeats (defaults to true).
  /// - [start]: The frame (0-based) to start from (defaults to 0).
  static Future<SpriteAnimation> _buildAnimation({
    required CharacterAsset asset,
    required SpriteDirection direction,
    int amount = 4,
    double stepTime = 0.2,
    Vector2? textureSize,
    bool loop = true,
    int start = 0,
  }) async {
    final size = textureSize ?? Vector2.all(32);

    // Pick the sprite sheet that matches the requested direction.
    late String path;

    switch (direction) {
      case SpriteDirection.IDLE_RIGHT:
        path = asset.idleRight;
      case SpriteDirection.RUN_RIGHT:
        path = asset.runRight;
      case SpriteDirection.IDLE_LEFT:
        path = asset.idleLeft;
      case SpriteDirection.RUN_LEFT:
        path = asset.runLeft;
    }

    // Slice the sheet into frames laid out left to right, starting at [start].
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

  static PlatformAnimations buildAnimation({
    required CharacterAsset asset,
    int frames = 6, // how many pictures are in the jump sheet
  }) =>
      PlatformAnimations(
        idleRight: _buildAnimation(
            asset: asset, direction: SpriteDirection.IDLE_RIGHT),
        idleLeft:
            _buildAnimation(asset: asset, direction: SpriteDirection.IDLE_LEFT),
        runRight:
            _buildAnimation(asset: asset, direction: SpriteDirection.RUN_RIGHT),
        runLeft:
            _buildAnimation(asset: asset, direction: SpriteDirection.RUN_LEFT),
        jump: _buildJumpAnimations(asset: asset),
        others: _buildOtherAnimations(asset: asset),
      );

  /// Plays an attack animation once, facing the way the character is looking.
  ///
  /// - [attackLeft] / [attackRight]: Keys of the attack animations registered
  ///   as `others` on [animation] (see [_buildOtherAnimations]).
  /// - [animation]: The character's animation set to play on.
  /// - [direction]: The direction the character is facing; any left-side
  ///   direction plays [attackLeft], everything else plays [attackRight].
  /// - [onFinish]: Called once the attack animation has run to the end.
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
  static PlatformJumpAnimations _buildJumpAnimations({
    required CharacterAsset asset,
    int frames = 6, // how many pictures are in the jump sheet
  }) {
    // One picture sheet turned into an animation.
    // We call this once for each sheet we need.
    Future<SpriteAnimation> load(String path) => _loadAnimation(
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

  /// Builds the one-shot "other" animations for any character: melee and
  /// range attacks, hurt and death.
  static Map<String, Future<SpriteAnimation>> _buildOtherAnimations({
    required CharacterAsset asset,
  }) {
    // One sheet turned into a one-time animation.
    // These all play once and stop, so loop is false.
    Future<SpriteAnimation> load(
      String path,
      int frames, {
      double stepTime = 0.1,
    }) =>
        _loadAnimation(
          path: path,
          amount: frames,
          stepTime: stepTime,
          loop: false,
        );

    return {
      MELEE_ATTACK_LEFT: load(
        asset.attackMeleeLeft,
        asset.attackMeleeFrames,
        stepTime: ATTACK_STEP_TIME,
      ),
      MELEE_ATTACK_RIGHT: load(
        asset.attackMeleeRight,
        asset.attackMeleeFrames,
        stepTime: ATTACK_STEP_TIME,
      ),
      RANGE_ATTACK_LEFT: load(
        asset.attackRangeLeft,
        asset.attackRangeFrames,
        stepTime: ATTACK_STEP_TIME,
      ),
      RANGE_ATTACK_RIGHT: load(
        asset.attackRangeRight,
        asset.attackRangeFrames,
        stepTime: ATTACK_STEP_TIME,
      ),
      HURT_LEFT: load(asset.hurtLeft, asset.hurtFrames),
      HURT_RIGHT: load(asset.hurtRight, asset.hurtFrames),
      DEATH_LEFT: load(asset.deathLeft, asset.deathFrames),
      DEATH_RIGHT: load(asset.deathRight, asset.deathFrames),
    };
  }

  /// Loads the projectile animation for a ranged attack, facing the way the
  /// character is looking.
  ///
  /// - [asset]: The character whose projectile sheets to use.
  /// - [direction]: The direction the character is facing; any left-side
  ///   direction loads the left sheet, everything else loads the right one.
  /// - [amount]: Number of frames in the sheet (defaults to 4).
  /// - [textureSize]: Frame dimension (defaults to 16x16).
  static Future<SpriteAnimation> loadProjectileAnimation({
    required CharacterAsset asset,
    required Direction direction,
    int amount = 4,
    Vector2? textureSize,
  }) =>
      _loadAnimation(
        path:
            direction.isLeftSide ? asset.projectileLeft : asset.projectileRight,
        amount: amount,
        textureSize: textureSize ?? Vector2.all(16),
      );
}
