import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';

/// A row of floor spikes that hurts the hero while they touch it: the
/// hazard from the Bonfire sensor doc's own example.
///
/// [WithSensor] notices what overlaps the spikes without blocking anyone, so
/// everyone walks over them. `<Player>` means only the hero gets hurt: the
/// companion and the foe cross unharmed.
class Spikes extends GameDecoration with BehindCharacters, WithSensor<Player> {
  /// Damage per hit, the same as the foe's bite.
  static const damage = 10.0;

  /// The hero is hurt at most this often while they stay on the spikes.
  static const hurtEvery = Duration(seconds: 1);

  /// The part of the tile that hurts: the spikes and their plank, the bottom
  /// 15 px of the sprite. A jump that clears the tips is safe.
  static final dangerSize = Vector2(TILE_SIZE - 2, 15);

  /// Seconds until the spikes can hurt the hero again.
  double _cooldown = 0;

  /// Creates the spikes at [position] (in pixels from the map's top-left).
  Spikes(Vector2 position)
      : super.withSprite(
          sprite: Sprite.load(SPIKES),
          position: position,
          size: Vector2.all(TILE_SIZE),
        );

  /// Runs once when the spikes are added to the game.
  @override
  Future<void> onLoad() async {
    // WithSensor only adds a hitbox the size of the whole tile when there
    // isn't one, so this smaller one, over the spikes alone, is used instead.
    // Passive and solid, like the one WithSensor makes: passive so it never
    // blocks anyone, solid so it still notices the hero when it fits wholly
    // inside the hero's hitbox.
    add(
      RectangleHitbox(
        position: Vector2(1, TILE_SIZE - dangerSize.y),
        size: dangerSize,
        isSolid: true,
        collisionType: CollisionType.passive,
      ),
    );
    // Called while the hero overlaps the spikes (checked every 100 ms).
    //
    // The doc's sensor.setup(interval: 1000) would slow the checks down, but
    // Bonfire only counts that second while the hero is touching, so a hero
    // walking straight across would never be hurt. Instead the spikes keep
    // checking every 100 ms and wait out [hurtEvery] themselves.
    sensor.onContactListener(_hurt);
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) _cooldown -= dt;
  }

  /// Hurts the [hero], unless they were hurt less than [hurtEvery] ago.
  ///
  /// It goes through `life.handleAttack`, like the foe's bite, rather than
  /// `life.remove`, so the hero's shake and red flash play.
  void _hurt(Player hero) {
    if (_cooldown > 0) return;
    _cooldown = hurtEvery.inMilliseconds / 1000;
    hero.life.handleAttack(AttackOriginEnum.WORLD, damage, this);
  }
}
