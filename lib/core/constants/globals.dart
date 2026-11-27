// This file holds values the whole game shares, so we only have to write
// them once.

// Names for the animations that play one time, like attacks.
const MELEE_ATTACK_LEFT = 'melee_attack_left';
const MELEE_ATTACK_RIGHT = 'melee_attack_right';
const RANGE_ATTACK_LEFT = 'range_attack_left';
const RANGE_ATTACK_RIGHT = 'range_attack_right';
const HURT_LEFT = 'hurt_left';
const HURT_RIGHT = 'hurt_right';
const DEATH_LEFT = 'death_left';
const DEATH_RIGHT = 'death_right';
const DEAD_LEFT = 'dead_left';
const DEAD_RIGHT = 'dead_right';

// How many seconds each frame of an attack stays on screen.
const ATTACK_STEP_TIME = 0.08;

// The cave background, in four layers from back to front. The layers move
// at different speeds, which makes the cave look deep.
const CAVE_BACK = 'background/cave_back.png';
const CAVE_FAR = 'background/cave_far.png';
const CAVE_MID = 'background/cave_mid.png';
const CAVE_NEAR = 'background/cave_near.png';

// Pictures for the shark.
const SHARK_IDLE_LEFT = 'characters/shark/shark_idle_left.png';
const SHARK_IDLE_RIGHT = 'characters/shark/shark_idle_right.png';
const SHARK_WALK_LEFT = 'characters/shark/shark_walk_left.png';
const SHARK_WALK_RIGHT = 'characters/shark/shark_walk_right.png';
const SHARK_JUMP_LEFT = 'characters/shark/shark_jump_left.png';
const SHARK_JUMP_RIGHT = 'characters/shark/shark_jump_right.png';
const SHARK_ATTACK_MELEE_LEFT = 'characters/shark/shark_attack_bite_left.png';
const SHARK_ATTACK_MELEE_RIGHT = 'characters/shark/shark_attack_bite_right.png';
const SHARK_ATTACK_RANGE_LEFT = 'characters/shark/shark_attack_range_left.png';
const SHARK_ATTACK_RANGE_RIGHT =
    'characters/shark/shark_attack_range_right.png';
const SHARK_HURT_LEFT = 'characters/shark/shark_hurt_left.png';
const SHARK_HURT_RIGHT = 'characters/shark/shark_hurt_right.png';
const SHARK_DEATH_LEFT = 'characters/shark/shark_death_left.png';
const SHARK_DEATH_RIGHT = 'characters/shark/shark_death_right.png';
const SHARK_PROJECTILE_LEFT = 'characters/shark/shark_water_ball_left.png';
const SHARK_PROJECTILE_RIGHT = 'characters/shark/shark_water_ball_right.png';

// Pictures for the wizard.
const WIZARD_IDLE_LEFT = 'characters/wizard/wizard_idle_left.png';
const WIZARD_IDLE_RIGHT = 'characters/wizard/wizard_idle_right.png';
const WIZARD_WALK_LEFT = 'characters/wizard/wizard_walk_left.png';
const WIZARD_WALK_RIGHT = 'characters/wizard/wizard_walk_right.png';
const WIZARD_JUMP_LEFT = 'characters/wizard/wizard_jump_left.png';
const WIZARD_JUMP_RIGHT = 'characters/wizard/wizard_jump_right.png';
const WIZARD_ATTACK_MELEE_LEFT =
    'characters/wizard/wizard_attack_melee_left.png';
const WIZARD_ATTACK_MELEE_RIGHT =
    'characters/wizard/wizard_attack_melee_right.png';
const WIZARD_ATTACK_RANGE_LEFT =
    'characters/wizard/wizard_attack_range_left.png';
const WIZARD_ATTACK_RANGE_RIGHT =
    'characters/wizard/wizard_attack_range_right.png';
const WIZARD_HURT_LEFT = 'characters/wizard/wizard_hurt_left.png';
const WIZARD_HURT_RIGHT = 'characters/wizard/wizard_hurt_right.png';
const WIZARD_DEATH_LEFT = 'characters/wizard/wizard_death_left.png';
const WIZARD_DEATH_RIGHT = 'characters/wizard/wizard_death_right.png';
const WIZARD_PROJECTILE_LEFT = 'characters/wizard/wizard_magic_bolt_left.png';
const WIZARD_PROJECTILE_RIGHT = 'characters/wizard/wizard_magic_bolt_right.png';

// Pictures for the lizardfolk warrior.
const LIZARDFOLK_IDLE_LEFT = 'characters/lizardfolk/lizardfolk_idle_left.png';
const LIZARDFOLK_IDLE_RIGHT = 'characters/lizardfolk/lizardfolk_idle_right.png';
const LIZARDFOLK_WALK_LEFT = 'characters/lizardfolk/lizardfolk_walk_left.png';
const LIZARDFOLK_WALK_RIGHT = 'characters/lizardfolk/lizardfolk_walk_right.png';
const LIZARDFOLK_JUMP_LEFT = 'characters/lizardfolk/lizardfolk_jump_left.png';
const LIZARDFOLK_JUMP_RIGHT = 'characters/lizardfolk/lizardfolk_jump_right.png';
const LIZARDFOLK_ATTACK_MELEE_LEFT =
    'characters/lizardfolk/lizardfolk_attack_melee_left.png';
const LIZARDFOLK_ATTACK_MELEE_RIGHT =
    'characters/lizardfolk/lizardfolk_attack_melee_right.png';
const LIZARDFOLK_ATTACK_RANGE_LEFT =
    'characters/lizardfolk/lizardfolk_attack_range_left.png';
const LIZARDFOLK_ATTACK_RANGE_RIGHT =
    'characters/lizardfolk/lizardfolk_attack_range_right.png';
const LIZARDFOLK_HURT_LEFT = 'characters/lizardfolk/lizardfolk_hurt_left.png';
const LIZARDFOLK_HURT_RIGHT = 'characters/lizardfolk/lizardfolk_hurt_right.png';
const LIZARDFOLK_DEATH_LEFT = 'characters/lizardfolk/lizardfolk_death_left.png';
const LIZARDFOLK_DEATH_RIGHT =
    'characters/lizardfolk/lizardfolk_death_right.png';
const LIZARDFOLK_PROJECTILE_LEFT =
    'characters/lizardfolk/lizardfolk_acid_spit_left.png';
const LIZARDFOLK_PROJECTILE_RIGHT =
    'characters/lizardfolk/lizardfolk_acid_spit_right.png';

// Pictures for Strawberry, the friendly character.
const STRAWBERRY_IDLE = 'characters/strawberry/strawberry_idle_sheet.png';
const STRAWBERRY_WALK = 'characters/strawberry/strawberry_walk_sheet.png';
const STRAWBERRY_TALK = 'characters/strawberry/strawberry_talk_sheet.png';
const STRAWBERRY_WAVE = 'characters/strawberry/strawberry_wave_sheet.png';
const STRAWBERRY_JUMP = 'characters/strawberry/strawberry_jump_sheet.png';
const STRAWBERRY_ATTACK = 'characters/strawberry/strawberry_attack_sheet.png';
const STRAWBERRY_HURT = 'characters/strawberry/strawberry_hurt_sheet.png';
const STRAWBERRY_DEATH = 'characters/strawberry/strawberry_death_sheet.png';

// Things placed around the map.
const SIGN = 'decorations/sign.png';
const CAMPFIRE = 'decorations/campfire_sheet.png';
const CHEST_CLOSED = 'decorations/chest_closed.png';
const CHEST_OPEN = 'decorations/chest_open.png';
const MUSHROOMS = 'decorations/mushrooms.png';
const SPIKES = 'decorations/spikes.png';

// Things the player can pick up.
const BRASS_KEY = 'brass_key.png';

// The game's two maps.
const MAP_ONE = 'maps/01/map/map.json';
const MAP_TWO = 'maps/02/map/map.json';

/// How big one square of the map is, in pixels.
const TILE_SIZE = 32.0;

/// How hard gravity pulls everything down. A bigger number makes things
/// fall faster.
const GRAVITY = 300.0;

/// If true, the game draws a box around everything that can bump into
/// something. Handy for finding out why something gets stuck.
///
/// To turn it on, run the game with
/// `--dart-define=SHOW_COLLISION_AREA=true`.
const SHOW_COLLISION_AREA = bool.fromEnvironment('SHOW_COLLISION_AREA');
