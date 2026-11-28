import 'package:bonfire/bonfire.dart';
import 'package:material_ui/material_ui.dart';

/// Draws outlines around everything that can bump into something else in the
/// game, so you can see the invisible boxes used for collisions.
///
/// You can turn the outlines on and off while the game is running.
///
/// Green outlines are for solid things. Red outlines are for sensors. Attacks
/// are shown in red while they are happening.
///
/// Each map gets its own [CollisionBoxes], because the game throws away the
/// old map's objects when you move to a new one. To keep the on/off setting
/// the same from map to map, they all share one switch ([CollisionBoxes.shared]).
class CollisionBoxes extends GameComponent {
  /// Whether the outlines are showing. The on-screen button changes this.
  final ValueNotifier<bool> visible;

  /// True if this object created [visible] itself, so it cleans up that switch
  /// when it is removed. A shared switch belongs to whoever gave it to us.
  final bool _ownsVisible;

  /// The colours used for the outlines.
  static final _hitboxPaint = Paint()
    ..color = Colors.lightGreenAccent.withValues(alpha: 0.5);
  static final _sensorPaint = Paint()..color = WithSensor.color;

  /// Remembers whether we have already set up the outlines. This way, when
  /// they are turned off, we only need to go through the world once.
  bool _drawingHitboxes = false;

  /// Makes the outlines with their own on/off switch, starting at [visible].
  CollisionBoxes({bool visible = false})
      : visible = ValueNotifier(visible),
        _ownsVisible = true {
    // Draw on top of the characters so the outlines are never hidden.
    renderAboveComponents = true;
  }

  /// Makes the outlines using a switch that stays around even after the
  /// outlines are removed, like the one `GameScreen` keeps for every map.
  CollisionBoxes.shared(this.visible) : _ownsVisible = false {
    renderAboveComponents = true;
  }

  /// Every collision box in the world: the characters', the walls' and any
  /// sensors'. Attack boxes don't count here. See [render] for those.
  Iterable<ShapeHitbox> get _hitboxes =>
      parent?.descendants().whereType<ShapeHitbox>() ?? const [];

  /// Runs every frame. Boxes keep appearing and disappearing (for example,
  /// when something is thrown or a new character walks in), so while the
  /// outlines are on, we make sure every box gets drawn.
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

  /// Draws the attack boxes that are active right now. The game only draws
  /// these by itself if the outlines were turned on from the start.
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

/// The on/off button for [CollisionBoxes], shown in the top-right corner.
class CollisionBoxesToggle extends StatelessWidget {
  /// The name used to show this button on the game screen.
  static const overlayName = 'collision_boxes_toggle';

  /// The on/off switch this button controls.
  final ValueNotifier<bool> visible;

  const CollisionBoxesToggle({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        // Clicking the button must not take keyboard focus away from the game.
        // If it did, the arrow keys would stop moving the hero.
        child: ExcludeFocus(
          // The game screen has no Material widget above it, and chips need one.
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
