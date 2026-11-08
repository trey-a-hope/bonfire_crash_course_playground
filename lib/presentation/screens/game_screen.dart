import 'package:bonfire/bonfire.dart';
import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:bonfire_crash_course_playground/presentation/backgrounds/parallax_background.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/companion.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/foe.dart';
import 'package:bonfire_crash_course_playground/presentation/characters/hero.dart';
import 'package:bonfire_crash_course_playground/presentation/debug/collision_boxes.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/brass_key.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/campfire.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/chest.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/map_exit.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/mushrooms.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/sign.dart';
import 'package:bonfire_crash_course_playground/presentation/decorations/spikes.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';

/// The game itself: two maps, each a [BonfireWidget], inside Bonfire's
/// [MapNavigator].
///
/// [MapNavigator] works like Flutter's own navigator, but for maps. Each
/// route ('/map1', '/map2') builds a [MapItem] holding that map, and
/// `MapNavigator.of(context).toNamed(route, arguments: ...)` switches to
/// another one with a short fade. The [MapNavigator.builder] then builds a
/// whole new game for that map: a new hero, new decorations and new
/// characters. Nothing carries over except what is passed in `arguments`,
/// which here is where the hero arrives.
///
/// Each game is a [BonfireWidget] configuring:
/// - `player`: The controllable character
/// - `playerControllers`: Keyboard listeners
/// - `map`: The world map, from the current [MapItem]
/// - `cameraConfig`: Camera zoom and target follow behaviors
class GameScreen extends StatefulWidget {
  /// Whether collision boxes are outlined when the game starts. Defaults to
  /// [SHOW_COLLISION_AREA], so they are off unless the game is run with
  /// `--dart-define=SHOW_COLLISION_AREA=true`.
  final bool showCollisionArea;

  /// Whether the on-screen "Collision boxes" toggle is shown. It is a
  /// developer tool, so release builds leave it out.
  final bool showCollisionToggle;

  const GameScreen({
    super.key,
    this.showCollisionArea = SHOW_COLLISION_AREA,
    this.showCollisionToggle = !kReleaseMode,
  });

  /// The route name of map 01, where the game starts.
  static const mapOneRoute = '/map1';

  /// The route name of map 02, through the exit at map 01's right edge.
  static const mapTwoRoute = '/map2';

  /// Where the hero starts when the game opens on map 01, in pixels.
  static Vector2 heroStart() => Vector2(100, 100);

  /// Where the hero arrives on map 01 when coming back from map 02: tile
  /// (23, 7), on the ground six tiles left of map 01's exit, so they don't
  /// land in it and get sent straight back.
  static Vector2 mapOneArrival() => Vector2(23, 7) * TILE_SIZE;

  /// Where the hero arrives on map 02 from map 01: tile (2, 7), on the
  /// ground one tile right of map 02's exit, for the same reason.
  static Vector2 mapTwoArrival() => Vector2(2, 7) * TILE_SIZE;

  /// Map 01's exit to map 02: column 29 (the right edge), rows 4-8. Tile
  /// (29, 5) is the end of a solid ledge, so the exit starts a row higher,
  /// where a hero walking along the top of the ledge passes.
  static Vector2 mapOneExitPosition() => Vector2(29, 4) * TILE_SIZE;

  /// Size of map 01's exit: one tile wide and five tall.
  static Vector2 mapOneExitSize() => Vector2(TILE_SIZE, 5 * TILE_SIZE);

  /// Map 02's exit back to map 01: column 0 (the left edge), rows 5-8.
  static Vector2 mapTwoExitPosition() => Vector2(0, 5) * TILE_SIZE;

  /// Size of map 02's exit: one tile wide and four tall, so the hero walks
  /// into it on the ground or mid-jump.
  static Vector2 mapTwoExitSize() => Vector2(TILE_SIZE, 4 * TILE_SIZE);

  /// Each route and the Sprite Fusion map it loads.
  static const mapAssets = {
    mapOneRoute: MAP_ONE,
    mapTwoRoute: MAP_TWO,
  };

  /// Camera settings for the game. A function, not a field, so every game
  /// (and every test) gets its own [CameraConfig].
  static CameraConfig cameraConfig() => CameraConfig(
        // Automatic zoom with base some configurations.
        initialMapZoomFit: InitialMapZoomFitEnum.fitHeight,
        // When this true the camera remains within the map area
        moveOnlyMapArea: true,
        // A box around the middle of the screen, one tile out from the
        // centre each way. The hero can move inside it without the camera
        // moving, so small steps and hops don't jiggle the view.
        movementWindow: Vector2.all(TILE_SIZE),
        // How quickly the camera catches up once the hero leaves the box.
        // Lower is lazier: at 3 it trails the walking hero by about another
        // tile, which still keeps them on screen on a small phone held
        // upright. `double.infinity` snaps with no easing at all.
        speed: 3,
      );

  /// The dusk tint over the whole game: a dark navy at 60% opacity. Only
  /// lights, like the campfire's, cut through it.
  static const duskColor = Color(0x990B1026);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Holds what outlives a single map: the collision boxes switch, and
/// whether the hero has met the companion and beaten the foe.
class _GameScreenState extends State<GameScreen> {
  /// Whether the companion's first talk has happened. Map 01 is built again
  /// every time the hero comes back from map 02, so once this is true its
  /// new companion starts out following, instead of replaying the talk.
  bool _metCompanion = false;

  /// Whether the foe has been defeated. Once true, map 01 is built without
  /// it. (A plain field, not state for setState: it is only read when
  /// MapNavigator builds the next map.)
  bool _foeDefeated = false;

  /// Whether the lizardfolk warrior on map 02 has been defeated. Once true,
  /// map 02 is built without it.
  bool _lizardfolkDefeated = false;

  /// Whether the collision boxes are drawn. Every map gets new
  /// [CollisionBoxes], but they all share this switch, so the toggle keeps
  /// its setting when the hero changes maps.
  late final _collisionBoxesVisible =
      ValueNotifier<bool>(widget.showCollisionArea);

  @override
  void dispose() {
    _collisionBoxesVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapNavigator(
      // The game opens on map 01. (Without this, MapNavigator would start
      // on the first route in [maps].)
      initialMap: GameScreen.mapOneRoute,
      // Each route builds its map. The id is what MapNavigator uses to tell
      // the maps apart, so it is the route name too.
      maps: {
        for (final MapEntry(key: route, value: asset)
            in GameScreen.mapAssets.entries)
          route: (context, arguments) => MapItem(
                id: route,
                map: WorldMapBySpritefusion(WorldMapReader.fromAsset(asset)),
              ),
      },
      // Builds the game for whichever map is current. It runs again, with a
      // fresh game, every time an exit calls toNamed.
      builder: (context, arguments, map) {
        // Under MapNavigator, so this finds its controller. The exits get
        // a plain callback that uses it, rather than a BuildContext.
        final navigator = MapNavigator.of(context);
        return BonfireWidget(
          // An exit passes the hero's arrival spot as `arguments`. There are
          // none when the game first opens, so the hero starts at the usual
          // spot on map 01.
          player: Hero(
            arguments is Vector2 ? arguments.clone() : GameScreen.heroStart(),
          ),
          components: [
            if (map.id == GameScreen.mapTwoRoute)
              ..._mapTwoComponents(navigator)
            else
              ..._mapOneComponents(navigator),
            // Outlines the collision boxes while the toggle is on. New for
            // each map, so it outlines that map's hitboxes.
            CollisionBoxes.shared(_collisionBoxesVisible),
          ],
          // The "Collision boxes" switch in the top-right corner.
          overlayBuilderMap: {
            CollisionBoxesToggle.overlayName: (context, game) =>
                CollisionBoxesToggle(visible: _collisionBoxesVisible),
          },
          initialActiveOverlays: [
            if (widget.showCollisionToggle) CollisionBoxesToggle.overlayName,
          ],

          background: ParallaxBackground(),
          // Gravity for the whole game. It pulls on every character with the
          // WithForces mixin (the hero, the companion and the foe).
          globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY)),
          // Setting a lighting color turns on Bonfire's lighting layer, which
          // darkens everything except the lights (see Campfire).
          lightingColorGame: GameScreen.duskColor,
          cameraConfig: GameScreen.cameraConfig(),
          playerControllers: [
            // Here you enable receive keyboard interaction
            Keyboard(
              config: KeyboardConfig(
                enable:
                    true, // Use to enable or disable keyboard events (default is true)
                acceptedKeys: [
                  // You can pass specific Keys accepted. If null accept all keys
                  LogicalKeyboardKey.space,
                ],
                directionalKeys: [
                  KeyboardDirectionalKeys.arrows(),
                  KeyboardDirectionalKeys.wasd(),
                ], // Type of the directional (arrows or wasd)
              ),
            )
          ],
          // Represents the 2D world where game entities interact: the map
          // the current route built.
          map: map.map,
        );
      },
    );
  }

  /// Everything on map 01 besides the map and the hero: decorations, the
  /// friendly companion, a foe, and the exit to map 02.
  List<GameComponent> _mapOneComponents(MapNavigatorController navigator) => [
        // Decorations sit on row 7, right on top of the ground (row 8), so
        // their bottom edge rests on it. They have no hitbox: everyone walks
        // past them, and they draw behind the characters (see
        // BehindCharacters).
        //
        // Tile (1, 7): just left of where the hero lands, pointing the way.
        Sign(Vector2(1, 7) * TILE_SIZE),
        // Tile (12, 7): the open ground between the two raised blocks.
        Campfire(Vector2(12, 7) * TILE_SIZE),
        // Tile (16, 7): the flat stretch before the wall at columns 19-22.
        Mushrooms(Vector2(16, 7) * TILE_SIZE),
        // Tile (18, 7): against the wall, so the hero walks into it on the
        // way across and it opens.
        Chest(Vector2(18, 7) * TILE_SIZE),
        // Tile (10, 5): on top of the raised block at columns 9-11, so the
        // hero jumps up to pick it up.
        BrassKey(Vector2(10, 5) * TILE_SIZE),
        // Tile (7, 7): just past the low block at columns 5-6, so the hero
        // jumps off the block over them, or walks off it onto them.
        Spikes(Vector2(7, 7) * TILE_SIZE),
        // Tile (24, 7): the row just above the ground (row 8) in map 01, so
        // the companion is already standing when the map loads. Columns
        // 23-29 are flat open ground there, so it has room to follow the hero.
        //
        // Once the hero has met it (on an earlier visit to map 01), it is
        // already following, so the talk doesn't play again.
        Companion(
          Vector2(24, 7) * TILE_SIZE,
          alreadyMet: _metCompanion,
          onMet: () => _metCompanion = true,
        ),
        // Tile (28, 7): on the ground, four tiles right of the companion and
        // far from the hero's start, so it only notices the hero after they
        // have met the companion. The wall at columns 19-22 keeps it on the
        // flat stretch at columns 23-29. Until it sees the hero it paces
        // between columns 24 and 29 (the map's right edge). Once defeated,
        // it stays gone when the hero comes back from map 02.
        if (!_foeDefeated)
          Foe(
            Vector2(28, 7) * TILE_SIZE,
            patrolMinX: 24 * TILE_SIZE,
            patrolMaxX: 29 * TILE_SIZE,
            onDefeated: () => _foeDefeated = true,
          ),
        // The right edge: walking into it fades to map 02, where the hero
        // arrives at the left end.
        MapExit(
          position: GameScreen.mapOneExitPosition(),
          size: GameScreen.mapOneExitSize(),
          onEnter: () => navigator.toNamed(
            GameScreen.mapTwoRoute,
            arguments: GameScreen.mapTwoArrival(),
          ),
        ),
      ];

  /// Everything on map 02 besides the map and the hero: a sign, a campfire,
  /// a lizardfolk warrior foe and the exit back to map 01. The companion and
  /// the shark stay on map 01.
  List<GameComponent> _mapTwoComponents(MapNavigatorController navigator) => [
        // Tile (4, 7): on the open ground near where the hero arrives.
        Sign(Vector2(4, 7) * TILE_SIZE),
        // Tile (14, 7): the open ground between the raised block (columns
        // 10-12) and the block at columns 17-20.
        Campfire(Vector2(14, 7) * TILE_SIZE),
        // Tile (23, 7): on the ground past the block at columns 17-20, so
        // the hero meets it after crossing the map. Until it sees the hero
        // it paces between columns 21 and 28, which includes the low gap
        // under the ledge at columns 25-29. Once defeated, it stays gone
        // when the hero comes back from map 01.
        if (!_lizardfolkDefeated)
          Foe(
            Vector2(23, 7) * TILE_SIZE,
            asset: CharacterAsset.lizardfolk,
            patrolMinX: 21 * TILE_SIZE,
            patrolMaxX: 28 * TILE_SIZE,
            onDefeated: () => _lizardfolkDefeated = true,
          ),
        // The left edge: walking into it fades back to map 01, where the
        // hero arrives near its right end.
        MapExit(
          position: GameScreen.mapTwoExitPosition(),
          size: GameScreen.mapTwoExitSize(),
          onEnter: () => navigator.toNamed(
            GameScreen.mapOneRoute,
            arguments: GameScreen.mapOneArrival(),
          ),
        ),
      ];
}
