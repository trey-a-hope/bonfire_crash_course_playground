import 'package:bonfire/bonfire.dart';
import 'package:flutter/services.dart';

/// The game's default keyboard input setup.
///
/// Arrow keys move the player, and Space, A and D are passed through as
/// action keys (e.g. for attacking or interacting).
class DefaultKeyboard extends Keyboard {
  DefaultKeyboard()
      : super(
          config: KeyboardConfig(
            acceptedKeys: [
              LogicalKeyboardKey.space,
              LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.keyD
            ],
            directionalKeys: [
              KeyboardDirectionalKeys.arrows(),
            ],
          ),
        );
}
