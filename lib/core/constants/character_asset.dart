import 'package:bonfire_crash_course_playground/core/constants/globals.dart';

/// Represents available character asset configurations.
///
/// Encapsulates sprite sheet paths for each directional movement state
/// (idle, walking, and jumping) used to build character animations in Bonfire.
enum CharacterAsset {
  /// Playable shark character sprite set.
  shark(
    id: 'shark',
    idleLeft: SHARK_IDLE_LEFT,
    idleRight: SHARK_IDLE_RIGHT,
    runLeft: SHARK_WALK_LEFT,
    runRight: SHARK_WALK_RIGHT,
    jumpLeft: SHARK_JUMP_LEFT,
    jumpRight: SHARK_JUMP_RIGHT,
    attackMeleeLeft: SHARK_ATTACK_MELEE_LEFT,
    attackMeleeRight: SHARK_ATTACK_MELEE_RIGHT,
    attackRangeLeft: SHARK_ATTACK_RANGE_LEFT,
    attackRangeRight: SHARK_ATTACK_RANGE_RIGHT,
    hurtLeft: SHARK_HURT_LEFT,
    hurtRight: SHARK_HURT_RIGHT,
    deathLeft: SHARK_DEATH_LEFT,
    deathRight: SHARK_DEATH_RIGHT,
    projectileLeft: SHARK_PROJECTILE_LEFT,
    projectileRight: SHARK_PROJECTILE_RIGHT,
    attackMeleeFrames: 5,
    attackRangeFrames: 5,
    attackRangeReleaseFrame: 3,
    hurtFrames: 5,
    deathFrames: 4,
  ),

  /// Wizard character sprite set.
  wizard(
    id: 'wizard',
    idleLeft: WIZARD_IDLE_LEFT,
    idleRight: WIZARD_IDLE_RIGHT,
    runLeft: WIZARD_WALK_LEFT,
    runRight: WIZARD_WALK_RIGHT,
    jumpLeft: WIZARD_JUMP_LEFT,
    jumpRight: WIZARD_JUMP_RIGHT,
    attackMeleeLeft: WIZARD_ATTACK_MELEE_LEFT,
    attackMeleeRight: WIZARD_ATTACK_MELEE_RIGHT,
    attackRangeLeft: WIZARD_ATTACK_RANGE_LEFT,
    attackRangeRight: WIZARD_ATTACK_RANGE_RIGHT,
    hurtLeft: WIZARD_HURT_LEFT,
    hurtRight: WIZARD_HURT_RIGHT,
    deathLeft: WIZARD_DEATH_LEFT,
    deathRight: WIZARD_DEATH_RIGHT,
    projectileLeft: WIZARD_PROJECTILE_LEFT,
    projectileRight: WIZARD_PROJECTILE_RIGHT,
    attackMeleeFrames: 5,
    attackRangeFrames: 6,
    attackRangeReleaseFrame: 5,
    hurtFrames: 5,
    deathFrames: 4,
  ),

  /// Medieval lizardfolk warrior sprite set: spear thrust for melee and an
  /// acid spit for range. Generated with Sprite Fusion (BCC-35).
  lizardfolk(
    id: 'lizardfolk',
    idleLeft: LIZARDFOLK_IDLE_LEFT,
    idleRight: LIZARDFOLK_IDLE_RIGHT,
    runLeft: LIZARDFOLK_WALK_LEFT,
    runRight: LIZARDFOLK_WALK_RIGHT,
    jumpLeft: LIZARDFOLK_JUMP_LEFT,
    jumpRight: LIZARDFOLK_JUMP_RIGHT,
    attackMeleeLeft: LIZARDFOLK_ATTACK_MELEE_LEFT,
    attackMeleeRight: LIZARDFOLK_ATTACK_MELEE_RIGHT,
    attackRangeLeft: LIZARDFOLK_ATTACK_RANGE_LEFT,
    attackRangeRight: LIZARDFOLK_ATTACK_RANGE_RIGHT,
    hurtLeft: LIZARDFOLK_HURT_LEFT,
    hurtRight: LIZARDFOLK_HURT_RIGHT,
    deathLeft: LIZARDFOLK_DEATH_LEFT,
    deathRight: LIZARDFOLK_DEATH_RIGHT,
    projectileLeft: LIZARDFOLK_PROJECTILE_LEFT,
    projectileRight: LIZARDFOLK_PROJECTILE_RIGHT,
    attackMeleeFrames: 6,
    attackRangeFrames: 6,
    attackRangeReleaseFrame: 4,
    hurtFrames: 6,
    deathFrames: 4,
  );

  /// Creates a [CharacterAsset] mapping with all required animation asset paths.
  const CharacterAsset({
    required this.id,
    required this.idleLeft,
    required this.idleRight,
    required this.runLeft,
    required this.runRight,
    required this.jumpLeft,
    required this.jumpRight,
    required this.attackMeleeLeft,
    required this.attackMeleeRight,
    required this.attackRangeLeft,
    required this.attackRangeRight,
    required this.hurtLeft,
    required this.hurtRight,
    required this.projectileLeft,
    required this.projectileRight,
    required this.attackMeleeFrames,
    required this.attackRangeFrames,
    required this.attackRangeReleaseFrame,
    required this.hurtFrames,
    required this.deathLeft,
    required this.deathRight,
    required this.deathFrames,
  });

  /// Unique identifier for the character.
  final String id;

  /// Asset path for the left-facing idle animation sprite sheet.
  final String idleLeft;

  /// Asset path for the right-facing idle animation sprite sheet.
  final String idleRight;

  /// Asset path for the left-facing walking animation sprite sheet.
  final String runLeft;

  /// Asset path for the right-facing walking animation sprite sheet.
  final String runRight;

  /// Asset path for the left-facing jumping animation sprite sheet.
  final String jumpLeft;

  /// Asset path for the right-facing jumping animation sprite sheet.
  final String jumpRight;

  /// Asset path for the left-facing melee attack sprite sheet.
  final String attackMeleeLeft;

  /// Asset path for the right-facing melee attack sprite sheet.
  final String attackMeleeRight;

  /// Asset path for the left-facing range attack sprite sheet.
  final String attackRangeLeft;

  /// Asset path for the right-facing range attack sprite sheet.
  final String attackRangeRight;

  /// Asset path for the left-facing hurt sprite sheet.
  final String hurtLeft;

  /// Asset path for the right-facing hurt sprite sheet.
  final String hurtRight;

  /// Asset path for the left-moving range attack projectile (16x16 frames).
  final String projectileLeft;

  /// Asset path for the right-moving range attack projectile (16x16 frames).
  final String projectileRight;

  /// Number of frames in the melee attack sheet.
  final int attackMeleeFrames;

  /// Number of frames in the range attack sheet.
  final int attackRangeFrames;

  /// The range attack frame (1-based) where the projectile leaves the
  /// character, so the flying projectile picks up where the drawn one ends.
  final int attackRangeReleaseFrame;

  /// Number of frames in the hurt sheet.
  final int hurtFrames;

  /// Asset path for the left-facing death sprite sheet.
  final String deathLeft;

  /// Asset path for the right-facing death sprite sheet.
  final String deathRight;

  /// Number of frames in the death sheet.
  final int deathFrames;
}
