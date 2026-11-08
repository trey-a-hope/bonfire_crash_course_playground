import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/behind_characters.dart';
import 'package:flutter/painting.dart';

/// A wooden signpost pointing the way. While the hero stands at it, a small
/// speech bubble above it shows what it says.
///
/// [WithSensor] notices the hero without blocking anyone, and `<Player>`
/// means only the hero counts: the companion and the foe walk past without
/// showing the message.
class Sign extends GameDecoration with BehindCharacters, WithSensor<Player> {
  /// What the sign says.
  // No arrow: the sign itself has one painted on, and not every font has
  // the → glyph.
  static const message = 'Campfire ahead';

  /// How much of each side of the tile doesn't count as being at the sign.
  static const _inset = 4.0;

  /// The bubble above the sign. It is always there, just hidden until the
  /// hero walks up.
  final bubble = SignBubble(message);

  /// Creates the sign at [position] (in pixels from the map's top-left).
  Sign(Vector2 position)
      : super.withSprite(
          sprite: Sprite.load(SIGN),
          position: position,
          // One 32x32 tile, like the characters.
          size: Vector2.all(TILE_SIZE),
        );

  /// Whether the sign's message is showing.
  bool get isShowingMessage => bubble.isVisible;

  /// Runs once when the sign is added to the game.
  @override
  Future<void> onLoad() async {
    // Centred above the sign, with a small gap. The bubble goes in the world
    // beside the sign rather than inside it: as the sign's child it would be
    // drawn behind the characters too, and a hero on the block next door
    // would cover it. The sign never moves, so neither does the bubble.
    bubble.position = position +
        Vector2(
          (size.x - bubble.size.x) / 2,
          -bubble.size.y - SignBubble.gap,
        );
    parent!.add(bubble);

    // The part of the tile that counts as "at the sign": its post, with a
    // few pixels left clear on each side. A hitbox the size of the whole
    // tile (what WithSensor adds when there's none) would also notice a hero
    // standing on the next tile, touching its edge. Passive and solid, like
    // WithSensor's own, so it never blocks anyone but still notices a hero
    // that covers it completely.
    add(
      RectangleHitbox(
        position: Vector2(_inset, 0),
        size: Vector2(size.x - _inset * 2, size.y),
        isSolid: true,
        collisionType: CollisionType.passive,
      ),
    );

    // The first listener runs while the hero overlaps the sign (checked
    // every 100 ms), and the second once the hero walks off, so the message
    // only shows while they're there. Neither pauses the game.
    sensor.onContactListener((_) => bubble.isVisible = true);
    sensor.onContactEndListener((_) => bubble.isVisible = false);
    return super.onLoad();
  }

  /// Takes the bubble away with the sign.
  @override
  void onRemove() {
    bubble.removeFromParent();
    super.onRemove();
  }
}

/// A small speech bubble with one line of [text], and a tail pointing down
/// at whatever it sits above.
class SignBubble extends PositionComponent with HasVisibility {
  /// Space between the bubble's tail and the thing below it.
  static const gap = 3.0;

  /// Space around the text inside the bubble.
  static const _padding = 3.0;

  /// How far the tail sticks out below the bubble.
  static const _tail = 3.0;

  static const _fill = Color(0xFFECDCC4);
  static const _ink = Color(0xFF1B1F2E);

  static final _fillPaint = Paint()..color = _fill;
  static final _inkPaint = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  /// The line of text in the bubble.
  final String text;

  final _textPaint = TextPaint(
    style: const TextStyle(fontSize: 8, color: _ink, height: 1),
  );

  /// Creates a bubble for [text]. It starts hidden.
  ///
  /// Bonfire draws each character at priority 30 plus its bottom edge in
  /// pixels, so this is far above any of them.
  SignBubble(this.text)
      : super(priority: LayerPriority.getComponentPriority(1000000)) {
    isVisible = false;
    final metrics = _textPaint.getLineMetrics(text);
    size = Vector2(
      metrics.width + _padding * 2,
      metrics.height + _padding * 2 + _tail,
    );
  }

  @override
  void render(Canvas canvas) {
    final body = Rect.fromLTWH(0, 0, size.x, size.y - _tail);
    final tail = Path()
      ..addPolygon(
        [
          Offset(size.x / 2 - _tail, body.bottom - 1),
          Offset(size.x / 2, size.y),
          Offset(size.x / 2 + _tail, body.bottom - 1),
        ],
        true,
      );
    // One outline around box and tail together, with no line between them.
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(2))),
      tail,
    );
    canvas.drawPath(shape, _fillPaint);
    canvas.drawPath(shape, _inkPaint);
    _textPaint.render(
      canvas,
      text,
      Vector2(size.x / 2, body.height / 2),
      anchor: Anchor.center,
    );
  }
}
