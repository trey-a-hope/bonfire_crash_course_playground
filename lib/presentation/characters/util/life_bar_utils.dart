import 'package:bonfire/bonfire.dart';
import 'package:flutter/painting.dart';

/// Life bar helpers for characters that use [WithLifeBar].
extension LifeBarStyle on LifeBarApi {
  /// The dark outline every decoration uses. The bar's empty part and border
  /// use it too, so the bar keeps its shape on any background.
  static const outlineColor = Color(0xFF1B1F2E);

  /// The bar's size in pixels: three quarters of a tile wide, 4 px tall.
  static final size = Vector2(24, 4);

  /// Draws the bar centred above the character's head, 2 px above it,
  /// always in one [fill] color (no green-yellow-red fade) and without the
  /// life number, which can't be read at 4 px.
  void setUpBar(Color fill) {
    setup(
      size: size,
      // One color for the whole bar, however full it is.
      colors: [fill],
      backgroundColor: outlineColor,
      borderColor: outlineColor,
      borderWidth: 1,
      borderRadius: BorderRadius.circular(1),
      drawPosition: BarLifeDrawPosition.top,
      // Bonfire draws a top bar just above this point, so moving it up 2 px
      // leaves a 2 px gap over the head.
      offset: Vector2(0, -2),
      showLifeText: false,
    );
  }
}
