import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';

/// Outlines every collision box in the world while [visible] is true, and
/// can be switched on and off while the game runs.
///
/// Bonfire's own `showCollisionArea` is fixed when the game starts, so this
/// does the same drawing itself: hitboxes in green (sensors in red, like
/// Bonfire), and attack hitboxes in red while they are active.
///
/// Every map gets its own [CollisionBoxes] (a map's components are thrown
/// away when `MapNavigator` switches maps), but they can share one [visible]
/// switch with [CollisionBoxes.shared], so the toggle keeps its setting from
/// map to map.
class CollisionBoxes extends GameComponent {
  /// Whether the boxes are drawn. The on-screen toggle flips this.
  final ValueNotifier<bool> visible;

  /// Whether this component made [visible] itself, and so disposes of it
  /// when it is removed. A shared switch belongs to whoever passed it in.
  final bool _ownsVisible;

  /// Bonfire's default colour for `showCollisionArea`.
  static final _hitboxPaint = Paint()
    ..color = Colors.lightGreenAccent.withValues(alpha: 0.5);
  static final _sensorPaint = Paint()..color = WithSensor.color;

  /// Whether the hitboxes were last set up to draw, so switching off only
  /// has to walk the world once.
  bool _drawingHitboxes = false;

  /// Creates the boxes with their own switch, starting at [visible].
  CollisionBoxes({bool visible = false})
      : visible = ValueNotifier(visible),
        _ownsVisible = true {
    // Drawn over the characters, so the boxes are never hidden.
    renderAboveComponents = true;
  }

  /// Creates the boxes with a switch that outlives them, like the one
  /// `GameScreen` keeps for every map. Removing the boxes leaves it alone.
  CollisionBoxes.shared(this.visible) : _ownsVisible = false {
    renderAboveComponents = true;
  }

  /// Every hitbox in the world: the characters', the solid tiles' and any
  /// sensors'. Attack hitboxes aren't [ShapeHitbox]es, see [render].
  Iterable<ShapeHitbox> get _hitboxes =>
      parent?.descendants().whereType<ShapeHitbox>() ?? const [];

  /// Runs every frame. Hitboxes come and go (projectiles, new characters),
  /// so while the boxes are on, each one is set up to draw.
  @override
  void update(double dt) {
    super.update(dt);
    final show = visible.value;
    if (!show && !_drawingHitboxes) return;
    for (final hitbox in _hitboxes) {
      hitbox.renderShape = show;
      if (show) {
        hitbox.paint =
            hitbox.parent is WithSensor ? _sensorPaint : _hitboxPaint;
      }
    }
    _drawingHitboxes = show;
  }

  /// Draws the active attack hitboxes. Bonfire only draws these itself when
  /// `showCollisionArea` was on from the start.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!visible.value) return;
    for (final attack
        in parent?.children.whereType<DamageHitbox>() ?? <DamageHitbox>[]) {
      canvas.drawRect(attack.toAbsoluteRect(), _sensorPaint);
    }
  }

  @override
  void onRemove() {
    if (_ownsVisible) visible.dispose();
    super.onRemove();
  }
}

/// The on-screen switch for [CollisionBoxes], shown in the top-right corner.
class CollisionBoxesToggle extends StatelessWidget {
  /// The overlay name to pass to `BonfireWidget.overlayBuilderMap`.
  static const overlayName = 'collision_boxes_toggle';

  /// The switch it flips: a [CollisionBoxes.visible].
  final ValueNotifier<bool> visible;

  const CollisionBoxesToggle({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        // Tapping it must not take keyboard focus from the game, or the
        // arrow keys would stop moving the hero.
        child: ExcludeFocus(
          // Game overlays have no Material above them, which chips need.
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) => FilterChip(
                avatar: const Icon(Icons.crop_free, size: 18),
                label: const Text('Collision boxes'),
                selected: show,
                showCheckmark: false,
                tooltip: show ? 'Hide collision boxes' : 'Show collision boxes',
                onSelected: (value) => visible.value = value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
