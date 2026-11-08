import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/behaviors/b_keep_fall_speed.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/behaviors/b_patrol.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/animation_utils.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/life_bar_utils.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/movement_utils.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

/// An enemy that patrols until it sees the hero, then chases and attacks
/// them up close. It is a shark by default; pass [asset] to use another
/// character's sprites, like the lizardfolk warrior on map 02.
///
/// [PlatformEnemy] is the enemy version of [PlatformPlayer]: side-scroller
/// movement, a life bar's worth of health, and attacks from the hero hurt it.
/// It has no gravity of its own, so [WithForces] lets the world's gravity
/// (set on `BonfireWidget`, see [GRAVITY]) pull it down, like the hero.
/// [UseBehavior] runs its AI from the [behaviors] list (see Step 4).
/// [WithLifeBar] draws its life as a red bar over its head.
class Foe extends PlatformEnemy with WithForces, UseBehavior, WithLifeBar {
  // Step 1: The component

  /// The sprite set this foe is drawn with (the shark by default).
  final CharacterAsset asset;

  /// How far (in pixels) the foe can see the hero: 5 tiles.
  static const _visionRadius = 5 * TILE_SIZE;

  /// The fill of the foe's life bar: bright red, so it reads against the
  /// dusk tint and can't be mixed up with the hero's green one.
  static const lifeBarColor = Color(0xFFFF5252);

  /// Leftmost and rightmost x (in pixels) the foe paces between while it
  /// can't see the hero. When either is null, the foe stands still instead.
  final double? patrolMinX;
  final double? patrolMaxX;

  /// Called once, when the foe's life reaches 0 (see [_onDie]).
  final VoidCallback? onDefeated;

  /// Creates the foe at [position] (in pixels from the map's top-left).
  ///
  /// Give [patrolMinX] and [patrolMaxX] to make it pace between them until
  /// it sees the hero.
  ///
  /// [onDefeated] is called once, when its life runs out. `GameScreen` uses
  /// it to leave the foe out of its map when the map is built again later.
  ///
  /// [asset] picks the sprites; every [CharacterAsset] has the same set of
  /// animations, so any of them works.
  Foe(
    Vector2 position, {
    this.asset = CharacterAsset.shark,
    this.patrolMinX,
    this.patrolMaxX,
    this.onDefeated,
  }) : super(
          position: position,
          // Size on screen; matches one 32x32 frame.
          size: Vector2.all(32),
          life: 100,
          // Half the hero's speed (Bonfire's default, 80), so the hero can
          // outrun it.
          speed: 40,
          countJumps: 1,

          // Step 2: Sprite animations

          // Same frame counts and speeds as the hero.
          animation: PlatformAnimations(
            runLeft: AnimationUtils.loadAnimation(asset.runLeft),
            runRight: AnimationUtils.loadAnimation(asset.runRight),
            idleLeft:
                AnimationUtils.loadAnimation(asset.idleLeft, stepTime: 0.2),
            idleRight:
                AnimationUtils.loadAnimation(asset.idleRight, stepTime: 0.2),
            jump: PlatformJumpAnimations(
              jumpUpRight:
                  AnimationUtils.loadAnimation(asset.jumpRight, amount: 6),
              jumpDownRight:
                  AnimationUtils.loadAnimation(asset.jumpRight, amount: 6),
              jumpUpLeft:
                  AnimationUtils.loadAnimation(asset.jumpLeft, amount: 6),
              jumpDownLeft:
                  AnimationUtils.loadAnimation(asset.jumpLeft, amount: 6),
            ),
            // One-shot sheets: the melee attack, getting hurt, and dying.
            others: {
              MELEE_ATTACK_LEFT: AnimationUtils.loadAnimation(
                asset.attackMeleeLeft,
                amount: asset.attackMeleeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              MELEE_ATTACK_RIGHT: AnimationUtils.loadAnimation(
                asset.attackMeleeRight,
                amount: asset.attackMeleeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              HURT_LEFT: AnimationUtils.loadAnimation(
                asset.hurtLeft,
                amount: asset.hurtFrames,
                loop: false,
              ),
              HURT_RIGHT: AnimationUtils.loadAnimation(
                asset.hurtRight,
                amount: asset.hurtFrames,
                loop: false,
              ),
              // Every character has death sheets (character_asset_test
              // checks them).
              DEATH_LEFT: AnimationUtils.loadAnimation(
                asset.deathLeft,
                amount: asset.deathFrames,
                loop: false,
              ),
              DEATH_RIGHT: AnimationUtils.loadAnimation(
                asset.deathRight,
                amount: asset.deathFrames,
                loop: false,
              ),
            },
          ),
        ) {
    lifeBar.setUpBar(lifeBarColor);
  }

  // Step 3: Gravity and collision
  //
  // Gravity comes from the world (see GRAVITY), so the foe only needs
  // WithForces and a hitbox.

  /// Runs once when the foe is added to the game.
  @override
  Future<void> onLoad() async {
    // The hitbox is the foe's solid shape: it stands on the ground, stops at
    // walls, and is what the hero's attacks hit.
    add(RectangleHitbox(size: size));
    return super.onLoad();
  }

  // Step 4: The foe's brain

  /// The foe's AI, as a list of behaviors that Bonfire runs every tick.
  ///
  /// `late final` builds the list once, so behaviors keep their state (like
  /// the patrol's pause) between ticks. The one behavior here reads as:
  /// while the foe is on screen and no cutscene is running, chase and bite
  /// the hero if they're alive and in sight, otherwise patrol; else stand
  /// still.
  @override
  late final List<Behavior> behaviors = [
    BCondition(
      // Enemies only move while they're on screen, so a foe far away waits
      // where it is until the hero comes near. And it stands still while a
      // scene runs (like the companion's first talk), as the hero does.
      condition: (_, __, game) =>
          isVisible && !game.sceneBuilderStatus.isRunning,
      doBehavior: BCondition(
        // A defeated hero isn't worth chasing.
        condition: (_, __, game) => game.player?.isDead == false,
        doBehavior: _chase ?? _patrol,
        doElseBehavior: _patrol,
      ),
      doElseBehavior: _standStill,
    ),
  ];

  /// Walks after the hero while it can see them, and bites when close.
  /// Patrols when it can't see them. Null if the game has no hero.
  late final Behavior? _chase = switch (gameRef.player) {
    null => null,
    // Bonfire's movement behaviors set the vertical speed to 0 whenever
    // they walk or stop, which would cancel gravity and make the foe float
    // down slowly off a ledge. BKeepFallSpeed puts the fall speed back.
    final hero => BKeepFallSpeed(
        BSeeAndMoveToTarget(
          target: hero,
          // How far it can see the hero.
          radiusVision: _visionRadius,
          // Walk left or right only: no jumping or floating up to the hero.
          movementAxis: MovementAxis.horizontal,
          // How close (in pixels) counts as next to the hero.
          distance: 2,
          // Called each tick the foe is next to the hero. Bonfire passes the
          // foe itself here, not the hero, so bite the hero from above.
          onClose: (dt, _) {
            if (_biteInterval.update(dt)) _bite(hero);
          },
          // Can't see the hero: patrol.
          doElseBehavior: _patrol,
        ),
      ),
  };

  /// Paces between [patrolMinX] and [patrolMaxX] at half speed, pausing a
  /// second at each end. Without both, the foe stands still instead.
  late final Behavior _patrol = (patrolMinX == null || patrolMaxX == null)
      ? _standStill
      : BPatrol(
          minX: patrolMinX!,
          maxX: patrolMaxX!,
          speed: speed / 2,
        );

  /// Stands still (without cancelling a fall).
  final Behavior _standStill = BAction(
    action: (_, comp, __) {
      if (comp is Movement) comp.stopWalking();
    },
  );

  // Step 5: Biting the hero

  /// Lets the foe bite at most once a second while next to the hero.
  /// `tickFirstUpdate` makes the first bite happen right away.
  final _biteInterval = IntervalTick(1000, tickFirstUpdate: true);

  /// Plays the bite facing [hero] and hurts them.
  void _bite(Player hero) {
    final heroIsLeft = hero.rectCollision.center.dx < rectCollision.center.dx;

    animation?.playOnceOther(
      heroIsLeft ? MELEE_ATTACK_LEFT : MELEE_ATTACK_RIGHT,
      // Keeps standing still (idle) from cutting the bite short.
      runToTheEnd: true,
    );

    // An invisible hitbox in front of the foe. ENEMY attacks hurt the hero,
    // but not the foe itself.
    attack.melee(
      damage: 10,
      size: Vector2.all(32),
      direction: heroIsLeft ? Direction.left : Direction.right,
      // Bonfire pushes the target a whole tile in one frame by default,
      // which makes the hero jump away. The hero shoves itself back
      // smoothly instead (see Hero._knockBackFrom).
      withPush: false,
      attackFrom: AttackOriginEnum.ENEMY,
      // Tells the hero who bit it, so it knows which way to be knocked back.
      id: this,
    );
  }

  // Step 6: Taking damage and dying

  /// Tells Bonfire what to do when the foe is hit and when it dies.
  @override
  void onMount() {
    super.onMount();
    life.onReceiveDamageListener(_onHurt);
    life.onDieListener(_onDie);
  }

  /// Called every time an attack hits the foe.
  void _onHurt(AttackOriginEnum attacker, double damage, dynamic identify) {
    animation?.playOnceOther(
      hDirection.isLeftSide ? HURT_LEFT : HURT_RIGHT,
      runToTheEnd: true,
    );
  }

  /// Called once, when the foe's life reaches 0.
  ///
  /// Bonfire doesn't remove a dead enemy by itself, so the foe drops its
  /// life bar, pauses its behaviors (no more chasing, patrolling or biting),
  /// stops, plays its death animation, and removes itself when the animation
  /// ends. Once dead it can't be hit again.
  void _onDie() {
    onDefeated?.call();
    // The life bar goes straight away, before the death animation plays.
    lifeBar.dispose();
    pauseBehaviors();
    stop();
    animation?.playOnceOther(
      hDirection.isLeftSide ? DEATH_LEFT : DEATH_RIGHT,
      runToTheEnd: true,
      onFinish: removeFromParent,
    );
  }
}
