import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
// Material widgets now come from the standalone `material_ui` package
// instead of `package:flutter/material.dart`.
import 'package:material_ui/material_ui.dart';

/// Where the app starts. This is the first code that runs.
void main() {
  runApp(const BonfireCrashCourseApp());
}

/// The whole app. It sets the app's name, colors and first screen.
class BonfireCrashCourseApp extends StatelessWidget {
  const BonfireCrashCourseApp({super.key});

  /// Draws the app.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Hides the red "DEBUG" label in the corner.
      debugShowCheckedModeBanner: false,
      title: 'Bonfire Crash Course Playground',
      // The app's colors, all based on deep purple.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // The first screen you see when the app opens.
      home: const GameScreen(),
    );
  }
}
