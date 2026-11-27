// Bonfire is the game engine we use to make our game.
import 'package:bonfire/bonfire.dart';

/// Lets you drag the screen to look around the map.
///
/// Bonfire does all the work for us, so there's no code inside.
class CameraDrag extends GameComponent with MoveCameraUsingGesture {}
