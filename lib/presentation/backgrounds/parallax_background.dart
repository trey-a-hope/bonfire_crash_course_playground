import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:flutter/painting.dart';

/// The cave behind both maps: four layers of rock that slide at different
/// speeds as the camera moves, so the nearer rock seems closer.
///
/// `GameScreen` passes it as the `background` of every map's
/// `BonfireWidget`. The layers are drawn by
/// `tool/backgrounds/build_cave_background.py` (see the README). Nothing
/// moves on its own: the cave only slides when the camera does.
class ParallaxBackground extends GameBackground {
  /// How fast the back layer slides, per pixel the camera moves. Bonfire's
  /// camera parallax multiplies this by each layer's multiplier (below) and
  /// by the frame time.
  ///
  /// A getter, so every load gets its own vector: the engine keeps the one
  /// it is given, and a shared one could be changed from under it.
  static Vector2 get baseVelocity => Vector2(9.4, 0);

  /// How much faster each layer slides than the one behind it.
  ///
  /// Bonfire gives the layer at depth `d` (0 at the back) a multiplier of
  /// `velocityMultiplierDelta` to the power `d + 1`, so 1.6 makes the four
  /// layers 1.6, 2.56, 4.1 and 6.55 times [baseVelocity]: speeds of about
  /// 15, 24, 39 and 62, back to front. The y values are 0 and 1, so the
  /// cave never moves up or down: the camera shows the whole map's height
  /// anyway. A getter for the same reason as [baseVelocity].
  static Vector2 get velocityMultiplierDelta => Vector2(1.6, 1);

  /// The cave's layers, back to front.
  static const layers = [CAVE_BACK, CAVE_FAR, CAVE_MID, CAVE_NEAR];

  /// The four cave layers, in one component that follows the camera.
  ParallaxComponent? _cave;

  /// Counts the loads started. A load only adds its parallax if no newer
  /// one has started since, so quick resizes (or a resize while the first
  /// load is still running) can't leave an extra, stale parallax behind.
  int _generation = 0;

  // Load assets for the background.
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _addParallax();
  }

  @override
  // Called whenever the size of the top-level Canvas changes.
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    // Reload the parallax on resize when not in cutscene/scene building, so
    // the layers are scaled to the new screen height.
    if (!gameRef.sceneBuilderStatus.isRunning) {
      _addParallax();
    }
  }

  /// Loads the cave layers and swaps them in for the current ones.
  ///
  /// Loading takes a while and nobody waits for it, so it may finish after
  /// a newer load has started; then its result is simply dropped.
  void _addParallax() async {
    final generation = ++_generation;

    // A camera parallax only moves when the camera does. Each image is
    // scaled to the screen's height and repeats sideways (the art tiles
    // seamlessly every 960 px). FilterQuality.none scales the pixel art
    // with hard edges, like the tiles, instead of blurring it.
    final cave = await util.loadCameraParallaxComponent(
      [for (final layer in layers) ParallaxImageData(layer)],
      baseVelocity: baseVelocity,
      velocityMultiplierDelta: velocityMultiplierDelta,
      filterQuality: FilterQuality.none,
    );

    // A newer load started while this one ran: it will add its own.
    if (generation != _generation) return;

    _cave?.removeFromParent();
    _cave = cave;
    add(cave);
  }
}
