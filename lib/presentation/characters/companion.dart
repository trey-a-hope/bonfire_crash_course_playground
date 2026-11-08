import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/util/animation_utils.dart';
import 'package:flutter/material.dart';

/// What the companion does this tick while following the hero.
enum FollowAction {
  /// Close enough, or blocked by a wall or step: stand still.
  stop,

  /// The hero is out of sight: stand still and wait for them to come back.
  lost,

  /// Walk left, towards the hero.
  left,

  /// Walk right, towards the hero.
  right,

  /// Jump up the step on the left, towards the hero.
  jumpLeft,

  /// Jump up the step on the right, towards the hero.
  jumpRight,
}

/// A friendly NPC that talks to the hero, waves hello, and then follows
/// them around, jumping up steps after them. Once following, it swipes at
/// the shark when the shark comes within reach. The shark's bite can hurt it
/// too: it flinches on each hit, and at 0 life it falls over and is removed.
///
/// [SimpleAlly] is Bonfire's Ally: an NPC on the player's side. Bonfire 4.0
/// has no `PlatformAlly`, so [WithCollision], [WithForces], [WithJumper]
/// and [JumperAnimation] give it the same platform behaviour the hero gets
/// from [PlatformPlayer], and [WithAttack] gives it a melee attack.
class Companion extends SimpleAlly
    with WithCollision, WithForces, WithJumper, JumperAnimation, WithAttack {
  /// How close (in pixels) the hero must be before the companion talks.
  static const _talkRadius = 48.0;

  /// How close (centre to centre, in pixels) the companion walks up to the
  /// hero before stopping. Both are 32 wide, so this leaves a 4px gap.
  ///
  /// It is less than [_talkRadius] on purpose, so the companion can stand
  /// beside the hero without crowding them. Following never reopens the
  /// dialogue: once the companion follows, it has had its one talk.
  static const followDistance = 36.0;

  /// How far (in pixels) the companion can see the hero while following.
  /// If the hero gets farther than this, the companion stops and waits.
  static const followRadius = 160.0;

  /// The highest step (in pixels, feet to feet) the companion jumps up
  /// after the hero. A one-tile step is 32px, and the jump (the hero's
  /// jump speed against [GRAVITY]) rises about 37px, so a little over one
  /// tile is as high as it can reach. Anything higher, it waits below.
  static const maxStep = TILE_SIZE + 4;

  /// Steps lower than this (in pixels) are just the ground being uneven, not
  /// something to jump up.
  static const _minStep = 8.0;

  /// How close (centre to centre, in pixels) a foe must be, sideways, for
  /// the companion to swipe at it: its own width plus a little, so the
  /// 32px swipe in front of it lands.
  static const attackReach = 40.0;

  /// How far above or below (centre to centre, in pixels) a foe can be and
  /// still be swiped at: less than a tile, so it only hits a foe standing
  /// on the same ground.
  static const _attackHeight = 24.0;

  /// How much damage each swipe does: small, since the hero does the real
  /// fighting (its melee does 20).
  static const attackDamage = 5.0;

  /// Lets the companion swipe at most once a second while a foe is in
  /// reach. `tickFirstUpdate` makes the first swipe happen right away.
  final _attackInterval = IntervalTick(1000, tickFirstUpdate: true);

  /// Key of the wave animation in the animation's `others` map.
  static const _waveAnimation = 'wave';

  /// Key of the attack animation in the animation's `others` map.
  static const _attackAnimation = 'attack';

  /// Key of the jump's take-off crouch in the animation's `others` map.
  static const _crouchAnimation = 'crouch';

  /// Key of the hurt animation in the animation's `others` map.
  static const _hurtAnimation = 'hurt';

  /// Key of the death animation in the animation's `others` map.
  static const _deathAnimation = 'death';

  /// True once the companion has talked. It never resets: the dialogue opens
  /// only once, and after it the companion follows the hero.
  bool _hasTalked = false;

  /// True after the first conversation: from then on the companion follows
  /// the hero around.
  bool _isFollowing = false;

  /// True once the companion follows the hero (after its first talk).
  bool get isFollowing => _isFollowing;

  /// Starts following the hero straight away, as if the first talk had
  /// already happened, so the dialogue never opens. The tests use this to
  /// skip the cutscene.
  void startFollowing() {
    _hasTalked = true;
    _isFollowing = true;
  }

  /// Called once, when the first talk's dialogue closes. `GameScreen` uses
  /// it to remember that the hero has met the companion, so a map 01 built
  /// again later (after a trip to map 02) doesn't replay the talk.
  final VoidCallback? onMet;

  /// Creates the companion at [position] (in pixels from the map's top-left).
  ///
  /// With [alreadyMet], it starts out following the hero and never opens the
  /// dialogue, as after its first talk ([startFollowing]).
  Companion(Vector2 position, {bool alreadyMet = false, this.onMet})
      : super(
          position: position,
          // Size on screen; matches one 32x32 frame.
          size: Vector2.all(32),
          life: 100,
          // Same speed as the hero (Bonfire's default, 80), so it keeps up
          // instead of falling behind and losing sight of them.
          speed: 80,
          // The strawberry faces the camera, so left and right share a sheet.
          animation: SimpleDirectionAnimation(
            // Idle breathes, sways its stem and blinks: 8 frames, played slowly.
            idleRight: AnimationUtils.loadAnimation(
              STRAWBERRY_IDLE,
              amount: 8,
              stepTime: 0.15,
            ),
            idleLeft: AnimationUtils.loadAnimation(
              STRAWBERRY_IDLE,
              amount: 8,
              stepTime: 0.15,
            ),
            // Walk steps quickly enough to match the speed, so the feet
            // don't look like they're sliding.
            runRight: AnimationUtils.loadAnimation(
              STRAWBERRY_WALK,
              amount: 4,
              stepTime: 0.08,
            ),
            runLeft: AnimationUtils.loadAnimation(
              STRAWBERRY_WALK,
              amount: 4,
              stepTime: 0.08,
            ),
            // Played once when the dialogue closes, as a "let's go" wave
            // before following the hero (see [_talk]).
            others: {
              _waveAnimation: AnimationUtils.loadAnimation(
                STRAWBERRY_WAVE,
                amount: 6,
                stepTime: 0.12,
                loop: false,
              ),
              // In the air, [JumperAnimation] plays these, flipping them for
              // left. Going up: arms raised, legs tucking in (frames 2-3).
              JumpAnimationsEnum.jumpUpRight: AnimationUtils.loadAnimation(
                STRAWBERRY_JUMP,
                amount: 2,
                stepTime: 0.15,
                start: 1,
              ),
              // Coming down: arms out, legs reaching for the ground (frame 4).
              JumpAnimationsEnum.jumpDownRight: AnimationUtils.loadAnimation(
                STRAWBERRY_JUMP,
                amount: 1,
                start: 3,
              ),
              // A quick crouch (frame 1), played once as it takes off.
              _crouchAnimation: AnimationUtils.loadAnimation(
                STRAWBERRY_JUMP,
                amount: 1,
                stepTime: 0.08,
                loop: false,
              ),
              // Played once per swipe, flipped to face a foe on the left
              // (see [_attack]).
              _attackAnimation: AnimationUtils.loadAnimation(
                STRAWBERRY_ATTACK,
                amount: 5,
                stepTime: ATTACK_STEP_TIME,
                loop: false,
              ),
              // Played once on each hit (see [_onHurt]). The strawberry faces
              // the camera, so one sheet does for both directions, like idle.
              _hurtAnimation: AnimationUtils.loadAnimation(
                STRAWBERRY_HURT,
                amount: 5,
                stepTime: 0.08,
                loop: false,
              ),
              // Played once when its life runs out (see [_onDie]).
              _deathAnimation: AnimationUtils.loadAnimation(
                STRAWBERRY_DEATH,
                amount: 4,
                stepTime: 0.15,
                loop: false,
              ),
            },
          ),
        ) {
    if (alreadyMet) startFollowing();
  }

  /// Runs once when the companion is added to the game.
  @override
  Future<void> onLoad() async {
    // The hitbox is the companion's solid shape: it stands on the ground
    // and stops at walls.
    add(RectangleHitbox(size: size));

    // The hero and the companion pass through each other instead of
    // bumping: otherwise a hero who turns around would shove the companion
    // along. Bonfire asks this before a collision stops either of them;
    // returning false lets the movement through. Tiles still block it, so it
    // still stands on the ground and stops at walls.
    collision.onBlockMovementListener((_, other) => other is! Player);
    return super.onLoad();
  }

  /// Tells Bonfire what to do when the companion is hit and when it dies.
  ///
  /// As an Ally it takes damage from ENEMY attacks (Bonfire's default for
  /// allies), so the shark's bite hurts it when it is caught in the bite.
  /// These are the companion's own listeners: the hero's shake and red
  /// flash belong to the hero's life, so they don't play when it is hit.
  @override
  void onMount() {
    super.onMount();
    life.onReceiveDamageListener(_onHurt);
    life.onDieListener(_onDie);
  }

  /// Called every time an attack hits the companion: flinches once.
  void _onHurt(AttackOriginEnum attacker, double damage, dynamic identify) {
    animation?.playOnceOther(
      _hurtAnimation,
      // Walking or standing still would otherwise cut the flinch short.
      runToTheEnd: true,
    );
  }

  /// Called once, when the companion's life reaches 0: stops following,
  /// plays the death animation once, and removes itself when it ends. Once
  /// dead it can't be hit again.
  void _onDie() {
    _isFollowing = false;
    _stopWalking();
    animation?.playOnceOther(
      _deathAnimation,
      runToTheEnd: true,
      onFinish: removeFromParent,
    );
  }

  /// Draw order: Bonfire draws components with a higher priority on top,
  /// based on how low they stand on screen. The companion takes one less
  /// than the hero, so the hero is always drawn in front, even when they
  /// stand on the same spot.
  @override
  int get priority {
    final hero = hasGameRef ? gameRef.player : null;
    if (hero == null) return super.priority;
    return hero.priority - 1;
  }

  /// Called every game tick: follows the hero (after the first talk) and
  /// checks whether the hero is close enough to talk.
  @override
  void update(double dt) {
    // A dead companion only falls (gravity) while its death animation plays.
    if (isDead) return super.update(dt);
    if (_isFollowing) {
      _follow();
      _attackFoeInReach(dt);
    }

    vision.seePlayer(
      radiusVision: _talkRadius,
      observed: (_) => _talk(),
    );
    super.update(dt);
  }

  /// Decides what the companion does this tick while following.
  ///
  /// [dx] is the hero's centre minus the companion's, along x (positive
  /// means the hero is to the right). [distance] is the straight-line
  /// distance between their centres. [canMove] says whether the companion
  /// can step towards the hero (no wall or step in the way). [stepUp] is
  /// how far the hero's feet are above the companion's, and [onGround] says
  /// whether the companion is standing (not jumping or falling).
  ///
  /// Pure function with no game state, so it is easy to unit test.
  static FollowAction followAction({
    required double dx,
    required double distance,
    required bool canMove,
    double stepUp = 0,
    bool onGround = true,
  }) {
    // Hero out of sight: wait here until they come back.
    if (distance > followRadius) return FollowAction.lost;
    final heroOnStep = stepUp > _minStep && stepUp <= maxStep;
    final right = dx > 0;
    if (!canMove) {
      // The hero is up a step it can reach: jump up after them.
      if (heroOnStep && onGround) {
        return right ? FollowAction.jumpRight : FollowAction.jumpLeft;
      }
      // A wall or step it can't climb: wait instead of walking into it.
      return FollowAction.stop;
    }
    // Close enough: stand beside the hero. With the hero up a step, keep
    // walking to the foot of the step to jump it, unless the hero is right
    // overhead (on a ledge with no wall underneath to stop at).
    if (dx.abs() <= (heroOnStep ? _minStep : followDistance)) {
      return FollowAction.stop;
    }
    return right ? FollowAction.right : FollowAction.left;
  }

  /// Walks along the ground towards the hero and stops a short way off.
  ///
  /// Only the horizontal speed is set; the vertical speed is left alone so
  /// gravity keeps the companion on the ground (it walks off ledges and
  /// lands instead of floating). If the hero is up a step it can reach, it
  /// jumps up after them; on anything higher it waits at the wall below
  /// until they come back down.
  void _follow() {
    final hero = gameRef.player;
    if (hero == null) return;

    final heroCenter = hero.rectCollision.center;
    final myCenter = rectCollision.center;
    final dx = heroCenter.dx - myCenter.dx;
    final heroIsJumping = switch (hero) {
      WithJumper(:final jumper) => jumper.isJumping,
      _ => false,
    };

    final action = followAction(
      dx: dx,
      distance: (heroCenter - myCenter).distance,
      // The hero's own hitbox is ignored; the distance check handles it.
      canMove: canMove(
        dx > 0 ? Direction.right : Direction.left,
        ignoreHitboxes: hero.shapeHitboxes,
      ),
      // Only a hero standing on a step counts, not one mid-jump.
      stepUp:
          heroIsJumping ? 0 : rectCollision.bottom - hero.rectCollision.bottom,
      onGround: !jumper.isJumping,
    );

    // None of these touch the vertical speed, so gravity still applies.
    switch (action) {
      case FollowAction.stop:
      case FollowAction.lost:
        _stopWalking();
      case FollowAction.left:
        moveLeft();
      case FollowAction.right:
        moveRight();
      case FollowAction.jumpLeft:
        _jump();
        moveLeft();
      case FollowAction.jumpRight:
        _jump();
        moveRight();
    }
  }

  /// Jumps as high as the hero does (Bonfire's default jump speed, which
  /// the hero uses too), with a quick crouch on take-off.
  void _jump() {
    animation?.playOnceOther(_crouchAnimation);
    jumper.jump();
  }

  /// Swipes at the closest living foe within [attackReach], at most once
  /// per [_attackInterval]. Only called while following, so the companion
  /// never fights before its first talk.
  void _attackFoeInReach(double dt) {
    final foe = _foeInReach();
    if (foe == null) return;
    if (_attackInterval.update(dt)) _attack(foe);
  }

  /// The closest living, on-screen enemy on the same ground, sideways
  /// within [attackReach], or null if there is none.
  Enemy? _foeInReach() {
    final me = rectCollision.center;
    Enemy? closest;
    var closestDx = double.infinity;
    for (final enemy in gameRef.query<Enemy>()) {
      // Bonfire's melee only hits what is on screen, so skip the rest.
      if (enemy.isDead || !enemy.isVisible) continue;
      final them = enemy.rectCollision.center;
      final dx = (them.dx - me.dx).abs();
      if (dx > attackReach || (them.dy - me.dy).abs() > _attackHeight) {
        continue;
      }
      if (dx < closestDx) {
        closest = enemy;
        closestDx = dx;
      }
    }
    return closest;
  }

  /// Plays the swipe facing [foe] and hurts it.
  void _attack(Enemy foe) {
    final foeIsLeft = foe.rectCollision.center.dx < rectCollision.center.dx;
    animation?.playOnceOther(
      _attackAnimation,
      // The sheet faces right; flip it to swipe at a foe on the left.
      flipX: foeIsLeft,
      // Walking or standing still would otherwise cut the swipe short.
      runToTheEnd: true,
    );
    // An invisible hitbox in front of the companion. PLAYER_OR_ALLY attacks
    // hurt enemies, never the hero or the companion itself.
    attack.melee(
      damage: attackDamage,
      size: Vector2.all(32),
      direction: foeIsLeft ? Direction.left : Direction.right,
      withPush: false,
      attackFrom: AttackOriginEnum.PLAYER_OR_ALLY,
    );
  }

  /// Stops walking sideways without cancelling a fall.
  void _stopWalking() {
    if (velocity.x != 0) velocity = velocity.copyWith(x: 0);
  }

  /// How much closer the camera zooms in on the companion while it talks.
  static const _talkZoom = 1.25;

  /// How long the camera takes to pan to the companion, and back to the
  /// hero afterwards.
  ///
  /// Whole seconds only: [CameraSceneAction] drops any fraction of a second.
  static const _panDuration = Duration(seconds: 1);

  /// Plays the first conversation as a short cutscene (only once): the
  /// camera pans to the companion, the dialogue opens, and when it closes
  /// the camera pans back to the hero. The companion waves on the way back,
  /// then follows the hero.
  void _talk() {
    if (_hasTalked) return;
    _hasTalked = true;

    final hero = gameRef.player;
    if (hero == null) return;

    // Stop the hero, and the companion if it was following.
    hero.onJoystickChangeDirectional(
      JoystickDirectionalEvent(directional: JoystickMoveDirectional.IDLE),
    );
    _stopWalking();

    // The zoom the game had before the cutscene, to go back to after it.
    final zoom = gameRef.camera.zoom;

    // A scene runs its actions one after another. While it runs the hero
    // ignores input and stands still (see Hero.update), so the player gets
    // control back only once the camera is back on the hero.
    gameRef.startScene([
      // Pan (and zoom in a little) to the companion.
      CameraSceneAction.target(
        this,
        zoom: zoom * _talkZoom,
        duration: _panDuration,
      ),
      // Talk, and wait here until the dialogue closes.
      AwaitSceneAction(wait: _showDialogue),
      // Pan back to the hero at the original zoom. The camera keeps
      // following the hero after this.
      CameraSceneAction.target(hero, zoom: zoom, duration: _panDuration),
    ]);
  }

  /// Pauses the game and shows the dialogue. Completes once it has closed
  /// and the game is running again; the companion starts its wave then.
  Future<void> _showDialogue() {
    final closed = Completer<void>();

    // Freeze the game right away, before the dialogue opens. Opening it can
    // stall the app for a moment; if the game kept running, that stall would
    // become one huge physics step and a hero in mid-jump could fall
    // straight through the ground.
    gameRef.pauseEngine();

    TalkDialog.show(
      context,
      [
        // The first line waves hello in the dialogue itself, since the game
        // (and the companion in it) is frozen.
        _say('Oh, hi there! I\'m Berry.', face: const _WaveThenTalk()),
        _say('Watch your step, the rocks in this cave are tricky.'),
        _say('Mind if I tag along?'),
      ],
      // Runs once the dialogue is gone from the screen.
      onClose: () {
        gameRef.resumeEngine();
        // The talk is over: from now on, they have met.
        onMet?.call();
        // Wave once more (while the camera pans back), then follow the hero
        // from now on. playOnceOther returns a Future that completes when
        // the wave ends (or right away if there is no wave), so following
        // always starts.
        final wave = animation?.playOnceOther(
          _waveAnimation,
          // Without this, the switch back to idle would cut the wave short.
          runToTheEnd: true,
        );
        (wave ?? Future.value()).then((_) => _isFollowing = true);
        closed.complete();
      },
    );
    return closed.future;
  }

  /// One line of dialogue, with the companion's [face] beside it (its
  /// talking face unless another is given).
  Say _say(String text, {Widget face = _talkingFace}) {
    return Say(
      text: [TextSpan(text: text)],
      // 96px, three times the sprite's size, so it is easy to see.
      person: SizedBox.square(dimension: 96, child: face),
    );
  }
}

/// The companion's talking face in the dialogue: its mouth opens and closes.
const _talkingFace = _Face(STRAWBERRY_TALK, amount: 2, stepTime: 0.15);

/// One of the companion's sprite sheets, played as a widget in the dialogue.
class _Face extends StatelessWidget {
  const _Face(
    this.path, {
    required this.amount,
    required this.stepTime,
    this.loop = true,
    this.onComplete,
  });

  /// Asset path of the sheet, relative to `assets/images/`.
  final String path;

  /// Number of 32x32 frames in the sheet.
  final int amount;

  /// Duration (in seconds) of each frame.
  final double stepTime;

  /// Whether the animation repeats; false plays it once and holds the last
  /// frame.
  final bool loop;

  /// Called when an animation that doesn't loop reaches its last frame.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return SpriteAnimationWidget.asset(
      path: path,
      data: SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
        loop: loop,
      ),
      onComplete: onComplete,
    );
  }
}

/// The companion's face in the first line of dialogue: waves hello once,
/// then switches to [_talkingFace].
class _WaveThenTalk extends StatefulWidget {
  const _WaveThenTalk();

  @override
  State<_WaveThenTalk> createState() => _WaveThenTalkState();
}

class _WaveThenTalkState extends State<_WaveThenTalk> {
  /// True until the wave has played once.
  bool _isWaving = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Built (but hidden) from the start, so it has loaded by the time
        // the wave ends and shows up without a blank frame in between.
        Visibility.maintain(visible: !_isWaving, child: _talkingFace),
        if (_isWaving)
          _Face(
            STRAWBERRY_WAVE,
            amount: 6,
            stepTime: 0.12,
            // Play once and stop, instead of waving forever.
            loop: false,
            // The dialogue may close (and remove this widget) before the
            // wave ends.
            onComplete: () {
              if (mounted) setState(() => _isWaving = false);
            },
          ),
      ],
    );
  }
}
