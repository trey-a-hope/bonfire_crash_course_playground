import 'package:bonfire_crash_course_playground/core/constants/globals.dart';

/// The characters in our game, and the pictures each one uses.
///
/// This is an enum: a list of choices that can't change. Each choice is one
/// character.
enum CharacterAsset {
  /// The shark. It bites up close and shoots water balls.
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
    attackRangeReleaseFrame: 2,
    hurtFrames: 5,
    deathFrames: 4,
  ),

  /// The wizard. It shoots magic bolts.
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
    attackRangeReleaseFrame: 4,
    hurtFrames: 5,
    deathFrames: 4,
  ),

  /// The lizardfolk warrior. It pokes with a spear up close and spits acid.
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
    attackRangeReleaseFrame: 3,
    hurtFrames: 6,
    deathFrames: 4,
  );

  /// Sets up a character. Every value has to be filled in.
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

  /// The character's name, like `'shark'`.
  final String id;

  /// The picture for standing still, facing left.
  final String idleLeft;

  /// The picture for standing still, facing right.
  final String idleRight;

  /// The picture for walking, facing left.
  final String runLeft;

  /// The picture for walking, facing right.
  final String runRight;

  /// The picture for jumping, facing left.
  final String jumpLeft;

  /// The picture for jumping, facing right.
  final String jumpRight;

  /// The picture for attacking up close, facing left.
  final String attackMeleeLeft;

  /// The picture for attacking up close, facing right.
  final String attackMeleeRight;

  /// The picture for shooting, facing left.
  final String attackRangeLeft;

  /// The picture for shooting, facing right.
  final String attackRangeRight;

  /// The picture for getting hurt, facing left.
  final String hurtLeft;

  /// The picture for getting hurt, facing right.
  final String hurtRight;

  /// The picture for the thing the character shoots, flying left.
  final String projectileLeft;

  /// The picture for the thing the character shoots, flying right.
  final String projectileRight;

  /// How many frames are in the attacking up close picture.
  final int attackMeleeFrames;

  /// How many frames are in the shooting picture.
  final int attackRangeFrames;

  /// Which frame of the shooting animation lets go of the shot. The first
  /// frame is 0.
  final int attackRangeReleaseFrame;

  /// How many frames are in the getting hurt picture.
  final int hurtFrames;

  /// The picture for dying, facing left.
  final String deathLeft;

  /// The picture for dying, facing right.
  final String deathRight;

  /// How many frames are in the dying picture.
  final int deathFrames;
}
