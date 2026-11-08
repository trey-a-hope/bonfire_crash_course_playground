#!/usr/bin/env python3
"""Builds map 02 from column slices of map 01 (ticket BCC-33).

Map 02 is a Sprite Fusion export, like map 01: a `map.json` and the
`spritesheet.png` its tile ids point into. Rather than drawing it by hand,
this script copies whole columns of map 01, in every layer, into a new
30 x 10 map, so map 02 reuses map 01's tiles and looks like the same world.

Run it from the repo root:

    python3 tool/maps/build_map_02.py
    python3 tool/maps/build_map_02.py --preview some/dir/   # also draws PNGs

It writes `assets/images/maps/02/map/map.json`, copies map 01's
`spritesheet.png` next to it, and checks the solid tiles match the
designer's layout. `--preview` needs Pillow (`pip install pillow`) and draws
`map01_preview.png` and `map02_preview.png` into the given folder.

To redraw map 02 by hand instead, build it in Sprite Fusion and drop its
export into `assets/images/maps/02/map/` (see the README).
"""

import argparse
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
MAP_ONE_DIR = ROOT / "assets/images/maps/01/map"
MAP_TWO_DIR = ROOT / "assets/images/maps/02/map"

# Size of map 02, in tiles. Tiles are 32 px, like map 01.
WIDTH = 30
HEIGHT = 10

# Which column of map 01 each column of map 02 is copied from, left to
# right. Columns 12 and 13 of map 01 are open ground, so repeating them
# makes the flat stretches between the blocks.
SOURCE_COLUMNS = (
    [0]  # t0: the left edge
    + [12, 13, 12, 13, 12]  # t1-t5: open ground where the hero arrives
    + list(range(5, 12))  # t6-t12: map 01's low block, ledge and raised block
    + [12, 13, 12, 13]  # t13-t16: open ground around the campfire
    + list(range(19, 23))  # t17-t20: map 01's wall
    + [12, 13]  # t21-t22: open ground
    + list(range(23, 30))  # t23-t29: map 01's flat end, with its ledge
)
assert len(SOURCE_COLUMNS) == WIDTH

# Decorative (non-solid) tiles to drop after copying, as (layer, x, y) in
# map 02. Map 01's columns 19-20 are the middle of a big dark rock in the
# background, so copied on their own (map 02's columns 17-18) they make a
# pillar with a straight, cut-off left edge. Dropping that rock leaves the
# solid grass block at columns 17-20 in front of the sky, like map 01's
# other blocks. Add more here if a later change leaves a cut tile at a join.
REMOVED_TILES = {
    ("Terrain - Auto", x, y) for x in (17, 18) for y in range(3, 8)
}

# Decorative tiles to swap for another id after copying, as
# (layer, x, y): new id. Under that rock, row 8 used the rock's dark fill
# (27); the open ground on either side uses the ground's top edge (30).
RETILED = {("Terrain - Auto", x, 8): "30" for x in (17, 18)}

# The designer's solid tiles for map 02, row by row ('#' is solid). The
# script refuses to write a map that doesn't match.
EXPECTED_COLLIDERS = {
    0: "." * WIDTH,
    1: "." * WIDTH,
    2: "." * WIDTH,
    3: "." * WIDTH,
    4: "......###.....................",
    5: ".........................#####",
    6: "..........###....####.........",
    7: "......##..###....####.........",
    8: "#" * WIDTH,
    9: "#" * WIDTH,
}


def build(map_one):
    """Returns map 02 as a Sprite Fusion map, made from [map_one]."""
    layers = []
    for layer in map_one["layers"]:
        tiles = []
        for target, source in enumerate(SOURCE_COLUMNS):
            for tile in layer["tiles"]:
                if tile["x"] != source:
                    continue
                if (layer["name"], target, tile["y"]) in REMOVED_TILES:
                    continue
                tile_id = RETILED.get((layer["name"], target, tile["y"]), tile["id"])
                tiles.append({"id": tile_id, "x": target, "y": tile["y"]})
        # Same name and collider flag as map 01's layer, so Bonfire builds
        # the same solid ground from it.
        layers.append(
            {"name": layer["name"], "tiles": tiles, "collider": layer["collider"]}
        )
    return {
        "tileSize": map_one["tileSize"],
        "mapWidth": WIDTH,
        "mapHeight": HEIGHT,
        "layers": layers,
    }


def collider_rows(sprite_fusion_map):
    """The map's solid tiles as one '#'/'.' string per row."""
    solid = {
        (tile["x"], tile["y"])
        for layer in sprite_fusion_map["layers"]
        if layer["collider"]
        for tile in layer["tiles"]
    }
    width = sprite_fusion_map["mapWidth"]
    return {
        row: "".join("#" if (x, row) in solid else "." for x in range(width))
        for row in range(sprite_fusion_map["mapHeight"])
    }


def render_preview(sprite_fusion_map, spritesheet_path, out_path):
    """Draws the map's layers, in order, from the spritesheet into a PNG.

    A tile's `id` counts the spritesheet's 32 px cells left to right, then
    top to bottom, starting at 0.
    """
    from PIL import Image  # Only needed for previews.

    size = sprite_fusion_map["tileSize"]
    sheet = Image.open(spritesheet_path).convert("RGBA")
    per_row = sheet.width // size
    picture = Image.new(
        "RGBA",
        (sprite_fusion_map["mapWidth"] * size, sprite_fusion_map["mapHeight"] * size),
        (135, 190, 235, 255),  # A plain sky, so the tiles stand out.
    )
    for layer in sprite_fusion_map["layers"]:
        for tile in layer["tiles"]:
            index = int(tile["id"])
            left = (index % per_row) * size
            top = (index // per_row) * size
            cell = sheet.crop((left, top, left + size, top + size))
            picture.alpha_composite(cell, (tile["x"] * size, tile["y"] * size))
    picture.save(out_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--preview",
        metavar="DIR",
        help="also draw map01_preview.png and map02_preview.png into DIR",
    )
    args = parser.parse_args()

    map_one = json.loads((MAP_ONE_DIR / "map.json").read_text())
    map_two = build(map_one)

    rows = collider_rows(map_two)
    mismatches = [r for r in EXPECTED_COLLIDERS if rows[r] != EXPECTED_COLLIDERS[r]]
    if mismatches:
        for r in mismatches:
            print(f"r{r} expected {EXPECTED_COLLIDERS[r]}", file=sys.stderr)
            print(f"r{r} got      {rows[r]}", file=sys.stderr)
        sys.exit("map 02's solid tiles don't match the designer's layout")

    MAP_TWO_DIR.mkdir(parents=True, exist_ok=True)
    # Compact, like Sprite Fusion's own export.
    (MAP_TWO_DIR / "map.json").write_text(
        json.dumps(map_two, separators=(",", ":"))
    )
    shutil.copyfile(MAP_ONE_DIR / "spritesheet.png", MAP_TWO_DIR / "spritesheet.png")
    print(f"wrote {MAP_TWO_DIR.relative_to(ROOT)}/map.json and spritesheet.png")
    for r in range(HEIGHT):
        print(f"r{r} {rows[r]}")

    if args.preview:
        out = pathlib.Path(args.preview)
        out.mkdir(parents=True, exist_ok=True)
        render_preview(map_one, MAP_ONE_DIR / "spritesheet.png", out / "map01_preview.png")
        render_preview(map_two, MAP_TWO_DIR / "spritesheet.png", out / "map02_preview.png")
        print(f"drew previews into {out}")


if __name__ == "__main__":
    main()
