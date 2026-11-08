import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/core/mixins/screen_boundary_checker.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/animation_utils.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/life_bar_utils.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// The playable hero character.
///
/// [PlatformPlayer] gives us side-scroller movement and jumping.
/// [WithLifeBar] draws the hero's life as a green bar over its head.
/// When its life runs out it plays its death animation once and stays down,
/// and the keyboard does nothing from then on.
class Hero extends PlatformPlayer
    with
        WithForces,
        KeyboardEventListener,
        ScreenBoundaryChecker,
        WithAttack,
        WithLifeBar {
  static const _asset = CharacterAsset.wizard;

  /// True while an attack animation is playing, so attacks can't be spammed
  /// faster than the hero can swing.
  bool _isAttacking = false;

  /// How long the screen shakes when the hero gets hurt.
  static const shakeDuration = Duration(milliseconds: 250);

  /// How far (in pixels) the camera jolts each frame while shaking. Small,
  /// so the shake reads as a hit without making the game hard to follow.
  static const _shakeIntensity = 3.0;

  /// Seconds left in the current shake. While it is above 0, another hit
  /// doesn't start a new shake, so quick hits never stack into a long one.
  double _shakeTimeLeft = 0;

  /// How much the camera zooms in while it shakes. Zooming in a little
  /// leaves a few pixels of map around the screen for the shake to move
  /// into, so it never shows past the map's edge.
  static const _shakeZoom = 1.04;

  /// The camera's zoom before the shake, to go back to when it ends.
  double _zoomBeforeShake = 1;

  /// The color of the light the magic bolt carries: the bolt's own cyan at
  /// 25% opacity, so it lights up the dusk as it flies.
  static const projectileLightColor = Color(0x404FD6FF);

  /// The red the whole game view flashes when the hero gets hurt, at 35%
  /// opacity so the scene still shows through it.
  static const hurtFlashColor = Color(0x59E53935);

  /// How long the hurt flash takes to fade in, then out. Together they last
  /// as long as the shake.
  static const _flashIn = Duration(milliseconds: 60);
  static const _flashOut = Duration(milliseconds: 190);

  /// The fill of the hero's life bar: bright green, so it reads against the
  /// dusk tint and can't be mixed up with the shark's red one.
  static const lifeBarColor = Color(0xFF69F0AE);

  /// The name of the custom force that knocks the hero back when an enemy
  /// bites it.
  static const knockbackForceName = 'knockback';

  /// How hard the knockback pushes, in pixels per second squared: away from
  /// the enemy (x) and up (y). Gravity still pulls down at the same time, so
  /// the hero ends up about a tile back and half a tile up.
  static final knockbackForce = Vector2(1000, -600);

  /// How long each frame of the death animation shows, in seconds. Slower
  /// than an attack, so the fall reads clearly.
  static const deathStepTime = 0.15;

  /// The animation the hero holds once its death animation is over (lying
  /// down, facing the way it fell), or null while it is alive or still
  /// falling.
  String? _deadAnimation;

  /// The animation the hero holds once it has died ([DEAD_LEFT] or
  /// [DEAD_RIGHT]), or null while it is alive or its death is still playing.
  String? get deadAnimation => _deadAnimation;

  /// How long the knockback lasts. The keyboard can't move or jump the hero
  /// until it's over, so the shove always looks the same.
  static const knockbackDuration = Duration(milliseconds: 250);

  /// Seconds left in the current knockback. Counted in [update], on game
  /// time, so pausing the game pauses the knockback too.
  double _knockbackTimeLeft = 0;

  /// True while the hero is being knocked back.
  bool get isKnockedBack => _knockbackTimeLeft > 0;

  /// The way to face once the knockback is over: towards the enemy.
  Direction _faceAfterKnockback = Direction.right;

  /// Creates the hero at [position] (in pixels from the map's top-left).
  Hero(Vector2 position)
      : super(
          position: position,
          // Size on screen; matches one 32x32 frame.
          size: Vector2.all(32),
          countJumps: 2,
          // Which animation to play for each state and direction.
          animation: PlatformAnimations(
            runLeft: AnimationUtils.loadAnimation(_asset.runLeft),
            runRight: AnimationUtils.loadAnimation(_asset.runRight),
            // Idle uses a larger stepTime so it plays slower than walking.
            idleLeft:
                AnimationUtils.loadAnimation(_asset.idleLeft, stepTime: 0.2),
            idleRight:
                AnimationUtils.loadAnimation(_asset.idleRight, stepTime: 0.2),
            jump: PlatformJumpAnimations(
              jumpUpRight:
                  AnimationUtils.loadAnimation(_asset.jumpRight, amount: 6),
              jumpDownRight:
                  AnimationUtils.loadAnimation(_asset.jumpRight, amount: 6),
              jumpUpLeft:
                  AnimationUtils.loadAnimation(_asset.jumpLeft, amount: 6),
              jumpDownLeft:
                  AnimationUtils.loadAnimation(_asset.jumpLeft, amount: 6),
            ),
            // Attack sheets play once on the hero's body, one per direction.
            others: {
              MELEE_ATTACK_LEFT: AnimationUtils.loadAnimation(
                _asset.attackMeleeLeft,
                amount: _asset.attackMeleeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              MELEE_ATTACK_RIGHT: AnimationUtils.loadAnimation(
                _asset.attackMeleeRight,
                amount: _asset.attackMeleeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              RANGE_ATTACK_LEFT: AnimationUtils.loadAnimation(
                _asset.attackRangeLeft,
                amount: _asset.attackRangeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              RANGE_ATTACK_RIGHT: AnimationUtils.loadAnimation(
                _asset.attackRangeRight,
                amount: _asset.attackRangeFrames,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              // Played once when the hero dies, facing the way it last faced.
              DEATH_LEFT: AnimationUtils.loadAnimation(
                _asset.deathLeft,
                amount: _asset.deathFrames,
                stepTime: deathStepTime,
                loop: false,
              ),
              DEATH_RIGHT: AnimationUtils.loadAnimation(
                _asset.deathRight,
                amount: _asset.deathFrames,
                stepTime: deathStepTime,
                loop: false,
              ),
              // The death sheet's last frame (lying down), held once the
              // death animation is over so the hero stays down.
              DEAD_LEFT: AnimationUtils.loadAnimation(
                _asset.deathLeft,
                amount: 1,
                start: _asset.deathFrames - 1,
              ),
              DEAD_RIGHT: AnimationUtils.loadAnimation(
                _asset.deathRight,
                amount: 1,
                start: _asset.deathFrames - 1,
              ),
            },
          ),
        ) {
    lifeBar.setUpBar(lifeBarColor);
  }

  @override
  bool onKeyboard(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // A dead hero can't move, jump or attack. Returning true still marks
    // the key as handled, so nothing else acts on it.
    if (isDead) return true;
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          if (!isKnockedBack) jumper.jump();
          return true;
        case LogicalKeyboardKey.keyW:
          _rangeAttack();
          return true;
        case LogicalKeyboardKey.keyS:
          _meleeAttack();
          return true;
        case LogicalKeyboardKey.keyA:
          onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: JoystickMoveDirectional.MOVE_LEFT,
            ),
          );
          return true;
        case LogicalKeyboardKey.keyD:
          onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: JoystickMoveDirectional.MOVE_RIGHT,
            ),
          );
          return true;
      }
    } else if (event is KeyUpEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyA:
          onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: keysPressed.contains(LogicalKeyboardKey.keyD)
                  ? JoystickMoveDirectional.MOVE_RIGHT
                  : JoystickMoveDirectional.IDLE,
            ),
          );
          return true;
        case LogicalKeyboardKey.keyD:
          onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: keysPressed.contains(LogicalKeyboardKey.keyA)
                  ? JoystickMoveDirectional.MOVE_LEFT
                  : JoystickMoveDirectional.IDLE,
            ),
          );
          return true;
      }
    }

    return super.onKeyboard(event, keysPressed);
  }

  /// Runs once when the hero is added to the game.
  @override
  Future<void> onLoad() async {
    // The hitbox is the hero's solid shape.
    // Without it, the hero falls straight through the ground.
    add(RectangleHitbox(size: size));
    return super.onLoad();
  }

  /// Tells Bonfire what to do when the hero is hit.
  @override
  void onMount() {
    super.onMount();
    life.onReceiveDamageListener(_onHurt);
    life.onDieListener(_onDie);
  }

  /// Called once, when the hero's life reaches 0: stops the hero where it
  /// stands and plays the death animation once, facing the way it last
  /// faced. When it ends, the hero holds the last frame and stays down.
  ///
  /// [onKeyboard] ignores every key from now on, so the hero can't move,
  /// jump or attack. Gravity still applies, so a hero who dies mid-jump
  /// falls to the ground.
  void _onDie() {
    // Let go of any held direction, then stop walking sideways.
    super.onJoystickChangeDirectional(
      JoystickDirectionalEvent(directional: JoystickMoveDirectional.IDLE),
    );
    velocity = velocity.copyWith(x: 0);
    final facingLeft = _isFacingLeft;
    animation?.playOnceOther(
      facingLeft ? DEATH_LEFT : DEATH_RIGHT,
      // Landing or standing still would otherwise cut the fall short.
      runToTheEnd: true,
      onFinish: () => _deadAnimation = facingLeft ? DEAD_LEFT : DEAD_RIGHT,
    );
  }

  /// Ignores the joystick once the hero is dead (the companion's cutscene
  /// and the knockback call this too, not only the keyboard).
  @override
  void onJoystickChangeDirectional(JoystickDirectionalEvent event) {
    if (isDead) return;
    super.onJoystickChangeDirectional(event);
  }

  /// Called every time an attack hits the hero (like the foe's bite): shakes
  /// the screen and flashes it red so the player feels the hit. Only the
  /// hero's own damage gets here, so hitting the foe doesn't shake or flash
  /// anything.
  void _onHurt(AttackOriginEnum attacker, double damage, dynamic identify) {
    if (_shakeTimeLeft > 0) return;
    _shakeTimeLeft = shakeDuration.inMilliseconds / 1000;

    final camera = gameRef.camera;
    // The camera is kept inside the map (`moveOnlyMapArea`), and the map
    // fills the screen's height (and near its ends, its width), so there is
    // no room to shake. Zoom in a little to make some, and work out the
    // map's limits again for the closer view.
    _zoomBeforeShake = camera.zoom;
    camera.zoom = _zoomBeforeShake * _shakeZoom;
    _keepCameraInMap();
    camera.shake(intensity: _shakeIntensity, duration: shakeDuration);
    _flashRed();
    // Only an enemy's attack (the foe's bite) knocks the hero back. The
    // spikes hurt as the world (AttackOriginEnum.WORLD), so they don't.
    if (attacker == AttackOriginEnum.ENEMY && identify is GameComponent) {
      _knockBackFrom(identify);
    }
  }

  /// Shoves the hero up and away from [enemy] with a named custom force.
  ///
  /// Forces from `forces.addForce` act like gravity: every tick they add to
  /// the hero's speed, so the hero speeds up smoothly instead of jumping a
  /// whole tile in one frame. [_endKnockback] takes the force away again.
  void _knockBackFrom(GameComponent enemy) {
    final away = absoluteCenter.x >= enemy.absoluteCenter.x ? 1.0 : -1.0;
    // Start from standing still sideways, so walking into the bite doesn't
    // eat into the shove.
    velocity = velocity.copyWith(x: 0);
    forces.addForce(
      knockbackForceName,
      Vector2(knockbackForce.x * away, knockbackForce.y),
    );
    _knockbackTimeLeft = knockbackDuration.inMilliseconds / 1000;
    // Moving backwards turns the hero around, so turn back to the enemy at
    // the end, ready to hit back.
    _faceAfterKnockback = away > 0 ? Direction.left : Direction.right;
    // Hand the hero over to the force: the keyboard would otherwise set the
    // sideways speed every tick and cancel the shove.
    setupMovementByJoystick(enabled: false);
  }

  /// Counts down the knockback and, once it is over, removes the force and
  /// gives the keyboard back.
  void _endKnockback(double dt) {
    if (_knockbackTimeLeft <= 0) return;
    _knockbackTimeLeft -= dt;
    if (_knockbackTimeLeft > 0) return;
    forces.removeForce(knockbackForceName);
    // Nothing slows the hero down sideways, so stop the drift here. Gravity
    // keeps the fall speed and lands the hero.
    velocity = velocity.copyWith(x: 0);
    direction = _faceAfterKnockback;
    hDirection = _faceAfterKnockback;
    // Back to Bonfire's default joystick settings, which the hero uses.
    setupMovementByJoystick();
  }

  /// Fades Bonfire's game color filter to [hurtFlashColor] and back out.
  /// The filter is drawn over the whole game, dusk tint included. Once the
  /// flash is over it is switched off (a null color), so no tint is left.
  void _flashRed() {
    final filter = gameRef.colorFilter;
    if (filter == null) return;
    // Start from a see-through red, and fade back to it, rather than
    // see-through black, so the red never darkens on the way in or out.
    final clear = hurtFlashColor.withAlpha(0);
    filter.config.color = clear;
    filter.animateTo(
      hurtFlashColor,
      // Lay the red over the picture, rather than Bonfire's default
      // BlendMode.color, which would turn the whole scene a flat red.
      blendMode: BlendMode.srcOver,
      duration: _flashIn,
      curve: Curves.easeOut,
      onFinish: () => filter.animateTo(
        clear,
        duration: _flashOut,
        curve: Curves.easeIn,
        onFinish: () => filter.config.color = null,
      ),
    );
  }

  /// Counts down the shake and, once it is over, puts the zoom back.
  void _endShake(double dt) {
    if (_shakeTimeLeft <= 0) return;
    _shakeTimeLeft -= dt;
    if (_shakeTimeLeft > 0) return;
    gameRef.camera.zoom = _zoomBeforeShake;
    _keepCameraInMap();
  }

  /// Works out again where the camera may go to stay inside the map, for
  /// how far it is zoomed in right now (if the game keeps it in the map).
  void _keepCameraInMap() {
    final camera = gameRef.camera;
    if (camera.config.moveOnlyMapArea) camera.moveOnlyMapArea = true;
  }

  /// Called every game tick to update the player's state.
  @override
  void update(double dt) {
    _endShake(dt);
    _endKnockback(dt);
    // Pause player logic and movement while a cutscene/cinematic scene is active.
    if (gameRef.sceneBuilderStatus.isRunning) return;
    // Run standard PlatformPlayer animation updates.
    super.update(dt);
    // Once dead, keep lying down. playOther does nothing if it is already
    // playing, so this only switches back if landing picked another one.
    final dead = _deadAnimation;
    if (dead != null) animation?.playOther(dead);
    // Constrain the player to stay within the map/screen boundaries. This
    // runs after the move, so the hero never draws past the edge.
    checkBoundaries();
  }

  /// Whether the hero is facing left (based on the last horizontal move).
  bool get _isFacingLeft => hDirection.isLeftSide;

  /// Plays the attack animation for the hero's facing direction on the hero
  /// itself. `runToTheEnd` keeps walking or landing from cutting it short.
  void _playAttackAnimation(String leftKey, String rightKey) {
    _isAttacking = true;
    animation?.playOnceOther(
      _isFacingLeft ? leftKey : rightKey,
      runToTheEnd: true,
      onFinish: () => _isAttacking = false,
    );
  }

  void _meleeAttack() {
    if (_isAttacking || isDead) return;
    _playAttackAnimation(MELEE_ATTACK_LEFT, MELEE_ATTACK_RIGHT);

    // The swing and sparks are drawn in the hero's own sheet, so the attack
    // only needs an invisible hitbox in front of the hero (no animation here).
    attack.melee(
      damage: 20,
      size: Vector2.all(32),
      direction: _isFacingLeft ? Direction.left : Direction.right,
      withPush: true,
      sizePush: 8,
      attackFrom: AttackOriginEnum.PLAYER_OR_ALLY,
    );
  }

  void _rangeAttack() {
    if (_isAttacking || isDead) return;
    final facingLeft = _isFacingLeft;
    _playAttackAnimation(RANGE_ATTACK_LEFT, RANGE_ATTACK_RIGHT);

    // Fire the projectile on the sheet's release frame so it picks up where
    // the projectile drawn in the hero's hand leaves off.
    final releaseDelay = Duration(
      milliseconds:
          ((_asset.attackRangeReleaseFrame - 1) * ATTACK_STEP_TIME * 1000)
              .round(),
    );

    Future.delayed(releaseDelay, () {
      // No bolt if the hero was removed or died while casting.
      if (!isMounted || isDead) return;
      attack.range(
        // The projectile is its own 16x16 sheet, not the hero's cast sheet.
        animation: AnimationUtils.loadAnimation(
          facingLeft ? _asset.projectileLeft : _asset.projectileRight,
          textureSize: Vector2.all(16),
        ),
        size: Vector2.all(16),
        destroySize: Vector2.all(32),
        direction: facingLeft ? Direction.left : Direction.right,
        speed: 220,
        damage: 15,
        marginFromOrigin: 8,
        attackFrom: AttackOriginEnum.PLAYER_OR_ALLY,
        // A small, steady light that travels with the bolt and goes out
        // when the bolt is destroyed. It only shows against the dusk tint
        // (lightingColorGame in game_screen.dart).
        lightingConfig: LightingConfig(
          radius: TILE_SIZE,
          color: projectileLightColor,
        ),
      );
    });
  }
}
