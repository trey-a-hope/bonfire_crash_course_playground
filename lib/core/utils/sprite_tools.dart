import 'dart:ui';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';

/// Which way the character is facing, and if they're standing still or
/// running.
enum SpriteDirection { IDLE_RIGHT, RUN_RIGHT, IDLE_LEFT, RUN_LEFT }

/// Tools for turning pictures into animations.
///
/// A sprite sheet is one picture with every frame of an animation lined up
/// side by side, like a flip book laid out in a row.
abstract class SpriteTools {
  /// Turns a sprite sheet into an animation.
  ///
  /// - [path]: Where the picture is, inside `assets/images/`.
  /// - [amount]: How many frames are in the picture.
  /// - [stepTime]: How many seconds each frame stays on screen.
  /// - [textureSize]: How big one frame is. Starts at 32 by 32 pixels.
  /// - [loop]: If true, the animation plays over and over. Use false for
  ///   things that happen once, like an attack.
  /// - [start]: Which frame to start on. The first frame is 0.
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

  /// Makes a standing or running animation for a character.
  ///
  /// - [asset]: The character to use.
  /// - [direction]: Which animation to make, like running left.
  /// - [amount]: How many frames are in the picture.
  /// - [stepTime]: How many seconds each frame stays on screen.
  /// - [textureSize]: How big one frame is. Starts at 32 by 32 pixels.
  /// - [loop]: If true, the animation plays over and over.
  /// - [start]: Which frame to start on. The first frame is 0.
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

    // Pick the picture that matches the direction.
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

    // Cut the picture into frames, going left to right.
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

  /// Makes every animation a character needs: standing, running, jumping,
  /// attacking, getting hurt and dying.
  static PlatformAnimations buildAnimation({
    required CharacterAsset asset,
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

  /// Plays an attack one time, facing the way the character is looking.
  ///
  /// - [attackLeft]: The name of the attack to play when facing left.
  /// - [attackRight]: The name of the attack to play when facing right.
  /// - [animation]: The character's animations.
  /// - [direction]: Which way the character is facing.
  /// - [onFinish]: Runs when the attack is done.
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

  /// Makes the jumping animations for a character.
  static PlatformJumpAnimations _buildJumpAnimations({
    required CharacterAsset asset,
    int frames = 6, // how many pictures are in the jump sheet
  }) {
    // A small helper that turns one picture into an animation.
    // We use it once for each picture we need.
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

  /// Makes the animations that play one time: attacking up close, shooting,
  /// getting hurt and dying.
  static Map<String, Future<SpriteAnimation>> _buildOtherAnimations({
    required CharacterAsset asset,
  }) {
    // A small helper that turns one picture into an animation.
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

  /// Makes the animation for the thing a character shoots, like a fireball,
  /// facing the way the character is looking.
  ///
  /// - [asset]: The character to use.
  /// - [direction]: Which way the character is facing.
  /// - [amount]: How many frames are in the picture.
  /// - [textureSize]: How big one frame is. Starts at 16 by 16 pixels.
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
