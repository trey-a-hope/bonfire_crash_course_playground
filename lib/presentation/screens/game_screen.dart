// Material widgets now come from the standalone `material_ui` package
// instead of `package:flutter/material.dart`.
import 'package:material_ui/material_ui.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Placeholder(
      color: Colors.green,
    );
  }
}
