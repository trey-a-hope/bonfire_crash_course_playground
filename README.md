# Bonfire Crash Course Playground

A small side-scrolling platformer built with Flutter and [Bonfire](https://pub.dev/packages/bonfire) 4.0. You play a wizard hero. You start on map 01, meet a friendly strawberry companion, fight a shark foe, and walk on to map 02.

## Run the game

In a GitHub Codespace, the dev container runs `flutter config --enable-web && flutter pub get` for you. Then start the **Codespaces** launch configuration in VS Code, which serves the game on port 8080.

On your own machine:

```sh
flutter pub get
flutter run -d chrome
```

To build for the web (also the `flutter: build web` VS Code task):

```sh
flutter build web
```

### Show the collision boxes

While you develop, a **Collision boxes** toggle sits in the top-right corner of the game. Tap it to outline every collision box, and tap it again to hide them, without restarting the game. It outlines the hitboxes for the hero, companion and foe, and the solid ground tiles, in green, and draws an attack's hitbox in red while it is active. This is useful when something stops where you don't expect it to, or walks through something it shouldn't.

The toggle is only there in debug and profile builds (`flutter run`), so release builds (`flutter build web`) leave it out. To start with the boxes already showing, add `--dart-define=SHOW_COLLISION_AREA=true`:

```sh
flutter run -d chrome --dart-define=SHOW_COLLISION_AREA=true
```

The code is in `lib/presentation/debug/collision_boxes.dart`. Bonfire's own `showCollisionArea` option on `BonfireWidget` can only be set when the game starts, so `CollisionBoxes` does the same drawing itself and can switch it while the game runs.

## Run the tests

```sh
flutter test
```

## Controls

| Key | Action |
| --- | --- |
| A / D | Walk left / right |
| Space | Jump (press again in the air to double jump) |
| S | Melee attack (20 damage) |
| W | Range attack (15 damage) |

## Characters

- **Hero** (`lib/presentation/characters/hero.dart`): the wizard you control.
  - At 0 life (`life.onDieListener`) it plays its death animation once, facing the way it last faced, then holds the last frame (lying down). From then on the keyboard does nothing: no walking, jumping or attacks. Gravity still applies, so a hero who dies mid-jump falls to the ground.
- **Companion** (`lib/presentation/characters/companion.dart`): a strawberry at tile (24, 7). It talks and waves when you first walk up to it, then follows you.
  - While following, it jumps up a step after you when the step is in its way, using `WithJumper` and `JumperAnimation` (the mixins `PlatformPlayer` uses) and the hero's jump speed. That reaches about 37 px, so it jumps steps up to `Companion.maxStep` (one tile plus 4 px) and waits at the foot of anything higher. It never jumps at a hero who is mid-jump, or before its first talk.
  - While following, it also swipes at the shark when the shark is on screen, on the same ground and within `Companion.attackReach` (40 px, centre to centre): 5 damage, at most once a second, with its attack animation flipped to face the shark. Bonfire 4.0.0 has no `simpleAttackMelee`, so it uses `WithAttack`'s `attack.melee` with `AttackOriginEnum.PLAYER_OR_ALLY`, which never hurts the hero or the companion itself.
  - It has 100 life. As a Bonfire Ally it takes damage from ENEMY attacks, so the shark's bite hurts it when it is caught in the bite (the shark only aims at you). Your own attacks never hurt it.
  - Each hit plays its hurt animation once. At 0 life it stops following, plays its death animation once and disappears.
  - These are the companion's own life listeners, so the hero's screen shake and red flash only play when the hero is hit.
- **Foe** (`lib/presentation/characters/foe.dart`): a shark at tile (28, 7), built on Bonfire's `PlatformEnemy`.
  - Its AI is a list of Bonfire [behaviors](https://bonfire-engine.github.io/#/doc/behaviors) (`UseBehavior`), not code in `update()`. It only acts while it is on screen, and stands still while a scene (like the companion's first talk) runs.
  - Until it sees you, it patrols: it paces between columns 24 and 29 at half speed, pausing a second at each end.
  - Once you are within 5 tiles and in its line of sight, it walks towards you. It only moves sideways and never jumps, and it ignores a hero who has been defeated.
  - Next to you, it bites for 10 damage, at most once a second. Each bite knocks you about a tile back and a little up: the hero adds a named custom force (`forces.addForce('knockback', ...)`) for 250 ms, can't be steered or jump while it lasts, then turns back to face the shark. Spikes hurt without a knockback.
  - It has 100 life. Each of your hits plays its hurt animation; at 0 it plays its death animation and disappears.

The hero and the foe each show their life in a thin bar over their head, with Bonfire's `WithLifeBar` mixin: green (`Hero.lifeBarColor`, `0xFF69F0AE`) for the hero and red (`Foe.lifeBarColor`, `0xFFFF5252`) for the shark. Both are styled by one helper, `lifeBar.setUpBar(color)` in `lib/presentation/characters/util/life_bar_utils.dart`: 24 x 4 px, 2 px above the head, with the decorations' dark outline and no life number. A bar gets shorter as `life.value` drops. The shark removes its bar (`lifeBar.dispose()`) as soon as it dies, before its death animation plays; the hero's bar stays, empty.

The characters are placed in `lib/presentation/screens/game_screen.dart`.

Gravity is set once for the whole game, not per character: `GameScreen` passes `globalForces: GlobalForcesSettings(gravity: Vector2(0, GRAVITY))` to `BonfireWidget`, with `GRAVITY` (300 px/s²) in `lib/core/constants/globals.dart`. It pulls on every character with the `WithForces` mixin. Don't also call `forces.setGravity` on a character, because the two add up and that character falls twice as fast. Bonfire's docs show `gameRef.globalForces.gravity = ...`, but in Bonfire 4.0.0 those settings are `final`, so they can only be set on `BonfireWidget`.

The foe uses two small custom behaviors from `lib/presentation/characters/behaviors/`, because two of Bonfire 4.0.0's built-ins don't suit a platformer:

- `BPatrol` paces between two x positions. Bonfire's `BRandomMovement` never starts moving in 4.0.0: it rebuilds its wait timer every frame, so the wait never ends.
- `BKeepFallSpeed` wraps the chase (`BSeeAndMoveToTarget`) and puts the vertical speed back after it runs. That chase calls `stop()` and moves with `resetCrossAxis`, which would otherwise cancel gravity every tick.

`BSeeAndMoveToTarget` also passes the foe itself to `onClose`, not the target, so the foe bites the hero it already has rather than the callback's argument.

## Decorations

Decorations are things in the world that aren't characters, built on Bonfire's [`GameDecoration`](https://bonfire-engine.github.io/#/doc/decoration?id=decoration). Each one is in `lib/presentation/decorations/` and placed in `game_screen.dart` (the tiles below are on map 01; map 02 has only a sign and a campfire, and the exit is described under [Map navigation](#map-navigation)), on row 7 so it rests on the ground (row 8), apart from the key, which sits on a raised block.

| Decoration | Tile | What it shows |
| --- | --- | --- |
| **Sign** (`sign.dart`) | (1, 7) | One sprite, with `GameDecoration.withSprite`. `WithSensor<Player>` shows a speech bubble ("Campfire ahead") above it while the hero stands at it: `onContactListener` shows it and `onContactEndListener` hides it once they walk off. The game keeps running. |
| **Campfire** (`campfire.dart`) | (12, 7) | A looping 4-frame animation, with `GameDecoration.withAnimation`. It also gives off a flickering light (see [Lighting](#lighting)). |
| **Mushrooms** (`mushrooms.dart`) | (16, 7) | Another single sprite. |
| **Chest** (`chest.dart`) | (18, 7) | Reacting to the player with a sensor (`WithSensor<Player>`): it opens the first time the hero touches it, and stays open. The companion and foe can't open it. |
| **Brass key** (`brass_key.dart`) | (10, 5) | The first item to pick up, on top of the raised block at columns 9-11. It uses a `WithSensor<Player>` sensor like the chest: when the hero touches it, it disappears. It's drawn at half a tile (16px), centred at the bottom of its tile. Two [Flame effects](https://docs.flame-engine.org/latest/flame/effects/effects.html) bring it to life: a `MoveByEffect` with an endless, alternating `EffectController` floats it up 3 px and back (0.6 s each way), and on pickup a `SequenceEffect` runs a `CombinedEffect` (rise half a tile, `ScaleEffect.to` 1.5x, `OpacityEffect.fadeOut`, 0.3 s) and then a `RemoveEffect`. |
| **Spikes** (`spikes.dart`) | (7, 7) | A hazard, as in the [sensor doc](https://bonfire-engine.github.io/#/doc/sensor?id=sensor)'s example. It sits in the dip just past the low block at columns 5-6. Touching the spikes takes 10 life, with the shake and red flash, and standing on them takes 10 more each second. Hop off the low block to clear them. |

The chest and key follow Bonfire's [sensor doc](https://bonfire-engine.github.io/#/doc/sensor?id=sensor). `WithSensor<Player>` gives each one a hitbox that notices only the player, and `sensor.onContactListener` runs while the hero overlaps it (checked every 100 ms). Once a sensor has done its job, the chest or key switches it off with `sensor.enabled = false`, so it stops checking and its listener never runs again. The key does this before its pop starts, so it is marked picked up (`isPickedUp`) at once and can't be picked up twice while it pops. The spikes keep theirs on, and only the spikes and their plank (the bottom 15 px of the tile) count as touching. They hurt the hero through `life.handleAttack`, like the foe's bite, so the shake and flash play, and wait a second before they can hurt again. They don't use `sensor.setup(interval: 1000)`, because Bonfire only counts that interval while the hero is touching, and waits a full one before the first callback, so a hero walking across would never be hurt.

The campfire and mushrooms have no hitbox, and the sign's, chest's, key's and spikes' sensor hitboxes never block anyone, so the hero, companion and foe walk past them all. Each one uses the `BehindCharacters` mixin (`behind_characters.dart`) so it is drawn behind the characters. Without it, Bonfire's draw order (by bottom edge) would put a decoration a pixel lower than the hero, and draw it on top.

## Background

Both maps are in a cave. `ParallaxBackground` (`lib/presentation/backgrounds/parallax_background.dart`) is the `background` of every map's `BonfireWidget`, and stacks four 960 x 320 pixel-art layers from `assets/images/background/`, back to front:

| Layer | File | What it shows |
| --- | --- | --- |
| Back (`CAVE_BACK`) | `cave_back.png` | The back wall, opaque: three bands of blue-grey rock, a few cracks and small teal crystals. |
| Far (`CAVE_FAR`) | `cave_far.png` | Distant rock: a low ceiling, wide stalactites and stalagmites. |
| Mid (`CAVE_MID`) | `cave_mid.png` | Nearer rock: stalactites, five rock columns (two broken) and rubble. |
| Near (`CAVE_NEAR`) | `cave_near.png` | The closest, darkest rock: a ceiling fringe and a line of rubble. Rows 100-259 are empty, which keeps the middle of the screen, where the characters play, uncluttered and easy to read. (Every layer is drawn behind the characters.) |

All four are one camera parallax, from `util.loadCameraParallaxComponent`, so nothing moves on its own: the cave only slides when the camera does, and each layer slides faster than the one behind it, which makes the nearer rock look closer. Bonfire gives layer `d` (0 at the back) a speed of `baseVelocity` times `velocityMultiplierDelta` to the power `d + 1`. With `baseVelocity` 9.4 and a delta of 1.6, the layers move at about 15, 24, 39 and 62, from back to front. Each image is scaled to the screen's height (the map's height, at the game's zoom), repeats sideways, and is drawn with `FilterQuality.none` so the pixels stay sharp like the tiles.

### Redraw the cave

The layers are drawn in code by `tool/backgrounds/build_cave_background.py`. Run it from the repo root to rebuild them (it needs Pillow and NumPy: `pip install pillow numpy`):

```sh
python3 tool/backgrounds/build_cave_background.py
python3 tool/backgrounds/build_cave_background.py --preview some/dir/   # also draws cave_layers.png
python3 tool/backgrounds/build_cave_background.py --check   # writes nothing; checks the PNGs are up to date
```

It uses a fixed seed (`SEED`), so running it again gives the same files, and `--check` fails if the committed PNGs differ from what it draws. The palette is at the top of the script, and each layer has its own `draw_*` function (`draw_back`, `draw_far`, `draw_mid`, `draw_near`). The script checks that every layer tiles seamlessly (x = 959 runs on into x = 0), that the back wall is opaque and the near layer's middle band is empty, and exits with an error if not. `--preview` draws each layer on its own, all four together, and the whole cave under the dusk tint with the seam in the middle.

## Lighting

Both maps play at dusk, using Bonfire's [lighting](https://bonfire-engine.github.io/#/doc/lighting?id=lighting).

- **Dusk tint:** `GameScreen` sets `lightingColorGame` on the `BonfireWidget` to `GameScreen.duskColor`, a dark navy at 60% opacity (`0x990B1026`). Setting a lighting color is what turns Bonfire's lighting layer on. It darkens the whole game, cave background included, except where a light cuts through.
- **Campfire light:** the campfire passes a `LightingConfig` to its constructor: a radius of 3 tiles, a warm orange (`Campfire.lightColor`, `0x40FF8C1A`) and `withPulse: true`, so the light shrinks by about 10% and grows back about twice a second, flickering with the flames. Every `GameDecoration` already has Bonfire's `WithLighting` mixin, so a decoration only needs the config. Other components can add `WithLighting` and call `lighting.setup(...)`, as the doc shows.
- **Magic bolt light:** the hero's range attack (W) passes `lightingConfig:` to `attack.range(...)`, so each bolt carries a small, steady light: 1 tile wide, in the bolt's cyan (`Hero.projectileLightColor`, `0x404FD6FF`). It travels with the bolt and goes out when the bolt hits something or leaves the screen. The melee attack (S) has no light.

`withPulse`, `pulseVariation` and `pulseSpeed` are in Bonfire 4's `LightingConfig`, and `attack.range(...)` takes a `lightingConfig:`, but neither is on the doc page. Bonfire eases the pulse, so `pulseVariation: 0.05` shrinks the light by about 10%.

- **Hurt flash:** when an attack hurts the hero (like the foe's bite), the whole game view flashes red while the screen shakes. `Hero` uses Bonfire's game color filter (`gameRef.colorFilter.animateTo(...)`, from the doc's GameColorFilter section) to fade to `Hero.hurtFlashColor` (`0x59E53935`, a red at 35%) over 60 ms and back over 190 ms, the same 250 ms as the shake. It uses `BlendMode.srcOver`, so the red lies over the picture; the filter's default, `BlendMode.color`, would turn the whole scene a flat red. When the flash ends, the filter's color is set back to `null`, which switches it off. A hit during a flash or shake adds nothing, and the hero hitting the foe never flashes. The color filter is drawn above the lighting layer, so the red shows over the dusk too.

The Collision boxes toggle and the companion's dialogue are Flutter overlays above the game, so neither the tint nor the flash reaches them.

## Map navigation

The game has two maps, and walking off the edge of one takes you to the other. `GameScreen` (`lib/presentation/screens/game_screen.dart`) wraps the game in Bonfire's `MapNavigator`, which works like Flutter's navigator, but for maps:

- **Routes:** `maps` names each map. `'/map1'` builds map 01 (`MAP_ONE`) and `'/map2'` builds map 02 (`MAP_TWO`), each as a `MapItem` with a `WorldMapBySpritefusion`. The map paths are in `lib/core/constants/globals.dart`. The game starts on `initialMap: '/map1'`, with the hero at the same spot as before.
- **Builder:** `builder` builds a whole new `BonfireWidget` for the current map. Map 01 gets its decorations, the companion and the foe, and map 02 gets a sign at tile (4, 7) and a campfire at (14, 7). The camera, keyboard, gravity, cave background, dusk lighting and Collision boxes toggle are the same on both maps.
- **Changing maps:** `MapNavigator.of(context).toNamed(route, arguments: ...)` switches maps with the default 300 ms fade. `arguments` is how you hand something to the next map. Here it is the hero's arrival position (a `Vector2`), and the builder passes it to `Hero(...)`. With no arguments (when the game first opens), the hero starts at the usual spot on map 01.

Each map is built fresh, so only what `GameScreen` remembers carries over. It keeps two flags for map 01: once you have met the companion (`onMet`, when its first talk closes), a rebuilt map 01 starts it already following (`Companion(..., alreadyMet: true)`) so the talk doesn't replay; and once the shark is defeated (`Foe.onDefeated`), map 01 is built without it. The Collision boxes toggle keeps its setting too, because all the maps' `CollisionBoxes` share one switch that `GameScreen` keeps (`CollisionBoxes.shared`). Everything else starts over (out of scope for now): the hero's life is full again on each map, map 01's chest is closed and its key back in place, and a companion that died comes back (following, if you had met it).

### The exits

An exit is a `MapExit` (`lib/presentation/decorations/map_exit.dart`): an invisible sensor that only notices the hero (`WithSensor<Player>`, so the companion and shark can walk through it) and calls its `onEnter` callback. `GameScreen` passes in a callback that calls `toNamed`, so the exit needs no `BuildContext` and can go on any edge of any map.

| Exit | Where | Goes to | Hero arrives at |
| --- | --- | --- | --- |
| Map 01, right edge | column 29, rows 4-8 (pixel (928, 128), 32 x 160) | `'/map2'` | tile (2, 7) on map 02 |
| Map 02, left edge | column 0, rows 5-8 (pixel (0, 160), 32 x 128) | `'/map1'` | tile (23, 7) on map 01 |

Map 01's exit starts at row 4 because tile (29, 5) is the end of a solid ledge: a hero walking along the top of it passes through row 4.

The hero never bounces straight back. Each arrival tile is clear of that map's exit, and an exit fires once when the hero walks in, then waits until they walk back out before it can fire again. It ignores a defeated hero, so a knockback can't push the body to the next map. Map 01's shark paces in front of its exit, so you have to get past it first.

### Add a map

1. Export the map from Sprite Fusion into `assets/images/maps/<NN>/map/` (`map.json` and `spritesheet.png`), and add that folder to the `assets:` list in `pubspec.yaml`.
2. Add its path to `globals.dart`, like `const MAP_THREE = 'maps/03/map/map.json';`.
3. Add a route to `maps` in `GameScreen`, and its components (decorations, characters, exits) to the builder.
4. Put a `MapExit` on each map that leads to it, with `onEnter: () => navigator.toNamed('/map3', arguments: <arrival position>)`. Keep the arrival spot clear of the new map's own exits.

### Redraw map 02

Map 02 is built from columns of map 01 by `tool/maps/build_map_02.py`, so it uses map 01's tiles. Run `python3 tool/maps/build_map_02.py` from the repo root to rebuild it. The script checks that the solid tiles match the planned layout, and `--preview <dir>` draws both maps as PNGs (this needs Pillow).

To draw map 02 by hand instead, open [Sprite Fusion](https://www.spritefusion.com/), make a 30 x 10 map of 32 px tiles with `assets/images/maps/01/map/spritesheet.png` as the tileset, and tick **Collider** on the layers the hero stands on. Export it as JSON and drop the export's `map.json` and `spritesheet.png` into `assets/images/maps/02/map/`, replacing what's there (running the script again would overwrite it). If you move the ground, check that the hero can still walk into map 02's exit (column 0, rows 5-8) and that its arrival tile (2, 7) is open, or move the exit and arrival tiles (`mapTwoExitPosition()`, `mapTwoArrival()` and the other static helpers at the top of `GameScreen`) to match. Keep map 01's arrival tile (23, 7) clear too, since it is where the hero lands coming back. Only the rows the hero walks through need to be open: row 8 is ground.

## Project structure

```
lib/
  main.dart                          App entry point
  core/constants/globals.dart        Asset paths, animation keys, TILE_SIZE (32)
  core/constants/character_asset.dart  Sprite sheets and frame counts per character
  presentation/screens/game_screen.dart  MapNavigator and each map's BonfireWidget
  presentation/characters/           Hero, Companion, Foe
  presentation/decorations/          Sign, Campfire, Mushrooms, Chest, BrassKey, Spikes, MapExit
  presentation/backgrounds/          ParallaxBackground, the cave behind both maps
  presentation/debug/                Collision boxes toggle
assets/images/
  background/                        The cave's four parallax layers
  characters/shark/                  Shark sheets, used by the foe
  characters/wizard/                 Wizard sheets, used by the hero
  characters/strawberry/             Companion sheets
  decorations/                       Decoration sprites
  maps/01/map/map.json               Map 01 (Sprite Fusion)
  maps/02/map/map.json               Map 02 (Sprite Fusion format, built by tool/maps/)
tool/maps/build_map_02.py            Builds map 02 from map 01's columns
tool/backgrounds/build_cave_background.py  Draws the cave layers
```

## Sprites

Each character's sheets are listed once in `CharacterAsset` (`lib/core/constants/character_asset.dart`), with paths defined in `globals.dart`. Frames are 32x32. The shark uses these files in `assets/images/characters/shark/`:

| Animation | Files | Frames |
| --- | --- | --- |
| Idle | `shark_idle_left.png`, `shark_idle_right.png` | 4 |
| Walk | `shark_walk_left.png`, `shark_walk_right.png` | 4 |
| Jump | `shark_jump_left.png`, `shark_jump_right.png` | 6 |
| Bite | `shark_attack_bite_left.png`, `shark_attack_bite_right.png` | 5 (`attackMeleeFrames`) |
| Hurt | `shark_hurt_left.png`, `shark_hurt_right.png` | 5 (`hurtFrames`) |
| Death | `shark_death_left.png`, `shark_death_right.png` | 4 (`deathFrames`) |

The wizard has the same set in `assets/images/characters/wizard/`, with a 4-frame death sheet each way (`wizard_death_left.png`, `wizard_death_right.png`): it reddens, topples backwards and lands on its back.

The strawberry faces the camera, so each of its animations is one sheet used for both directions, in `assets/images/characters/strawberry/`:

| Animation | File | Frames |
| --- | --- | --- |
| Idle | `strawberry_idle_sheet.png` | 8 |
| Walk | `strawberry_walk_sheet.png` | 4 |
| Talk | `strawberry_talk_sheet.png` | 2 |
| Wave | `strawberry_wave_sheet.png` | 6 |
| Jump | `strawberry_jump_sheet.png` | 4 (crouch, rising, top, falling) |
| Attack | `strawberry_attack_sheet.png` | 5 (faces right; flipped for left) |
| Hurt | `strawberry_hurt_sheet.png` | 5 |
| Death | `strawberry_death_sheet.png` | 4 |

The wizard's death sheets and the strawberry's jump, attack, hurt and death sheets were drawn in code from each character's own frames and palette, not generated with Sprite Fusion.

The decorations are 32x32 too, in `assets/images/decorations/`: `sign.png`, `mushrooms.png`, `chest_closed.png`, `chest_open.png`, `spikes.png`, and `campfire_sheet.png` (4 frames in a row).
