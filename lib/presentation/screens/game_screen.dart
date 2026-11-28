// Material widgets now come from the standalone `material_ui` package
// instead of `package:flutter/material.dart`.
import 'package:material_ui/material_ui.dart';

/// The screen where our game will be shown.
///
/// Right now it just shows a green box. Later we'll put the game here.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Holds the data for [GameScreen] that can change while the app runs.
class _GameScreenState extends State<GameScreen> {
  /// Draws what you see on the screen.
  @override
  Widget build(BuildContext context) {
    // A green box that saves space for the game.
    return Placeholder(
      color: Colors.green,
    );
  }

  /// Runs when the screen closes. Like tidying up before you leave a room.
  @override
  void dispose() {
    super.dispose();
  }
}
