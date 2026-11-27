// Bonfire is the game engine we use to make our game.
import 'package:bonfire/bonfire.dart';
// Gives us the names of the keys on the keyboard.
import 'package:flutter/services.dart';

/// The keys you use to play the game.
///
/// The arrow keys move the player. Space, A and D are for actions, like
/// attacking.
class DefaultKeyboard extends Keyboard {
  DefaultKeyboard()
      : super(
          config: KeyboardConfig(
            // Keys the game listens for, besides the arrow keys.
            acceptedKeys: [
              LogicalKeyboardKey.space,
              LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.keyD
            ],
            // Keys that move the player.
            directionalKeys: [
              KeyboardDirectionalKeys.arrows(),
            ],
          ),
        );
}
