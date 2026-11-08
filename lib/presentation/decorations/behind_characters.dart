import 'package:bonfire/bonfire.dart';

/// Draws a decoration just above the map and behind every character.
///
/// Bonfire draws components in order of their bottom edge, lowest first. A
/// decoration stands on the same ground as the characters, and
/// [GameDecoration] pads its size by about a pixel, so it would otherwise
/// come out a pixel lower and be drawn over the hero.
mixin BehindCharacters on GameDecoration {
  @override
  int get priority => LayerPriority.MAP + 1;
}
