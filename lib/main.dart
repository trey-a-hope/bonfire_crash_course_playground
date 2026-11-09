import 'package:bonfire_crash_course_playground/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';

/// The entry point of the Flutter application.
void main() {
  runApp(const BonfireCrashCourseApp());
}

/// Root widget of the application configuring the theme and initial route.
class BonfireCrashCourseApp extends StatelessWidget {
  const BonfireCrashCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bonfire Crash Course Playground',
      // Configure global visual styling and Material 3 design system
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Entry screen displaying the Bonfire game view
      home: const GameScreen(),
    );
  }
}
