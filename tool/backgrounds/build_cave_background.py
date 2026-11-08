#!/usr/bin/env python3
"""Draws the four layers of the cave background (ticket BCC-34).

Both maps sit in front of a cave. `ParallaxBackground` stacks four 960 x 320
pixel-art images, back to front, and slides each one a little faster than
the one behind it as the camera moves:

    cave_back.png   the cave's back wall (opaque): three bands of blue-grey
                    rock, a few cracks and some small teal crystals
    cave_far.png    distant rock: a low ceiling, wide stalactites and
                    stalagmites
    cave_mid.png    nearer rock: a ceiling fringe, stalactites, rock columns
                    from floor to ceiling, and rubble on the floor
    cave_near.png   the closest, darkest rock: a jagged ceiling fringe and a
                    line of rubble, with nothing in between (y 100-259), so
                    the middle of the screen, where the characters play,
                    stays uncluttered

Run it from the repo root:

    python3 tool/backgrounds/build_cave_background.py
    python3 tool/backgrounds/build_cave_background.py --preview some/dir/
    python3 tool/backgrounds/build_cave_background.py --check

It writes the four PNGs into `assets/images/background/`. Everything comes
from one fixed seed, so running it again gives the same bytes. `--check`
writes nothing and fails if the committed PNGs aren't exactly what the
script draws, which shows both that they are up to date and that the
drawing is repeatable. `--preview`
also draws `cave_layers.png` (each layer on its own, then all four together)
into the given folder. It needs Pillow and NumPy
(`pip install pillow numpy`).

The art follows the designer's spec: 1x pixel art with hard edges and no
anti-aliasing, a lighter rim on the edges that face the light (up and left),
and checkerboard dither only in thin bands where one tone meets another.
Every image tiles horizontally: shapes are placed modulo 960 and the wavy
ceiling and floor lines are sums of sine waves with a whole number of
cycles across the image, so x = 959 runs straight on into x = 0. The script
checks that, and that the near layer's middle band is empty, and exits with
an error if either check fails.
"""

import argparse
import io
import math
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets/images/background"

# Every layer is this size, like the old sky background. The game scales it
# to the screen's height, which is the map's 320 px at the game's zoom.
W, H = 960, 320

# One seed for the whole cave. Change it for a different (but still
# repeatable) cave.
SEED = 34

# The near layer leaves this band of rows empty (y 100-259). That is where
# the hero, companion and foe play, so keeping the darkest, closest rock out
# of it keeps the action easy to read. (All the layers are drawn behind the
# characters either way.)
NEAR_EMPTY_ROWS = (100, 260)

# How many times the average change between two neighbouring columns the
# seam (x = 959 to x = 0) may change before it counts as a visible seam.
SEAM_FACTOR = 2.0


def rgb(hex_color):
    """Turns '#RRGGBB' into an (r, g, b) tuple."""
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


def brighten(color, factor):
    """Scales a color's channels, for nudging the back wall brighter."""
    return tuple(min(255, round(c * factor)) for c in color)


# How much brighter than the spec the back wall is drawn. Under the game's
# dusk tint the spec's colors went muddy, so they are nudged up 10%.
BACK_BRIGHTNESS = 1.1

# The designer's palette. Each layer is darker than the one behind it.
BACK_BANDS = [  # (first row, color), top to bottom
    (0, brighten(rgb("#262C46"), BACK_BRIGHTNESS)),
    (100, brighten(rgb("#2E3555"), BACK_BRIGHTNESS)),
    (220, brighten(rgb("#373F63"), BACK_BRIGHTNESS)),
]
# Cracks use the next-darker tone; the top band's cracks go a step darker.
BACK_CRACK_TOP = brighten(rgb("#1F2439"), BACK_BRIGHTNESS)
CRYSTAL = rgb("#2F8F8A")
CRYSTAL_LIGHT = rgb("#5FC4B8")
FAR_FILL, FAR_RIM = rgb("#202538"), rgb("#292F4C")
MID_FILL, MID_RIM = rgb("#181C30"), rgb("#222740")
NEAR_FILL, NEAR_RIM = rgb("#101222"), rgb("#1A1D33")


# --------------------------------------------------------------------------
# Drawing helpers. Shapes are drawn into boolean masks (True = rock), and a
# mask is colored at the end. Every x is wrapped modulo W, so a shape that
# runs off the right edge comes back in on the left.
# --------------------------------------------------------------------------


def new_mask():
    """An empty mask, one bool per pixel."""
    return np.zeros((H, W), dtype=bool)


def wave(rng, terms):
    """A wavy line across the image: one value per column.

    `terms` is a list of (cycles, amplitude). Each term is a sine wave with
    a whole number of cycles across the 960 px, at a random phase, so the
    line ends exactly where it began and the image tiles.
    """
    x = np.arange(W)
    line = np.zeros(W)
    for cycles, amplitude in terms:
        phase = rng.uniform(0, 2 * math.pi)
        line += amplitude * np.sin(2 * math.pi * cycles * x / W + phase)
    return line


def jag(rng, low, high, min_run=3, max_run=9):
    """Chunky steps for a rock edge: one offset per column.

    The offset stays the same for a run of 3-9 columns and then jumps, which
    gives pixel-art rock its stepped, hand-placed look. A jump at the seam is
    just one more step, so it still tiles.
    """
    steps = np.zeros(W)
    x = 0
    while x < W:
        run = rng.randint(min_run, max_run)
        steps[x : x + run] = rng.randint(low, high)
        x += run
    return steps


def span(mask, y, left, right):
    """Fills row y from column `left` to `right` (inclusive), wrapping."""
    if 0 <= y < H and right >= left:
        mask[y, np.arange(left, right + 1) % W] = True


def fill_below(mask, line):
    """Fills every column from its `line` value down to the bottom."""
    rows = np.arange(H)[:, None]
    mask |= rows >= np.round(line)[None, :]


def fill_above(mask, line):
    """Fills every column from the top down to its `line` value."""
    rows = np.arange(H)[:, None]
    mask |= rows < np.round(line)[None, :]


def spike(mask, rng, cx, base_y, length, width, down=True, curve=1.4):
    """Draws one stalactite (down=True) or stalagmite (down=False).

    It is built a row at a time, from `width` at the base to a point
    `length` rows away, so the edges step like hand-drawn pixel art. The
    width shrinks as (1 - t) ** curve: above 1 the base flares into the rock
    and the point is long and sharp, below 1 it stays fat and ends blunt.
    It leans a little to one side, each edge bulges out by a pixel now and
    then, like chipped rock, and it ends in a 1 px point.
    """
    lean = rng.uniform(-0.12, 0.12) * width
    left_steps = [rng.choice([0, 0, 0, 1]) for _ in range(length // 4 + 2)]
    right_steps = [rng.choice([0, 0, 0, 1]) for _ in range(length // 4 + 2)]
    # The rows behind the base (t < 0) run 10 px back into the ceiling or
    # floor at full width, so a wide one never floats below a bumpy ceiling.
    for t in range(-10, length + 1):
        frac = max(t, 0) / length
        half = width / 2 * (1 - frac) ** curve
        centre = cx + lean * frac
        left = math.floor(centre - half)
        right = math.ceil(centre + half) - 1
        if half > 4:
            # Chip the edges outward now and then, but leave thin points
            # clean.
            left -= left_steps[max(t, 0) // 4]
            right += right_steps[max(t, 0) // 4]
        if right < left:
            # The last few rows: a single-pixel point.
            left = right = round(centre)
        y = base_y + t if down else base_y - t
        span(mask, y, left, right)


def polygon(mask, points):
    """Fills a polygon with hard edges (Pillow's polygon has no anti-
    aliasing). It is drawn three times, a tile to the left and right too,
    so a polygon crossing the seam wraps."""
    layer = Image.new("1", (W, H), 0)
    draw = ImageDraw.Draw(layer)
    for shift in (-W, 0, W):
        draw.polygon([(x + shift, y) for x, y in points], fill=1)
    mask |= np.array(layer, dtype=bool)


def rock(mask, rng, cx, cy, size):
    """Draws one chunk of rubble: an irregular polygon about `size` px
    across, made from 6-8 points at uneven distances around its centre.
    Rocks are a little wider than tall, so they sit flat."""
    n = rng.randint(6, 8)
    angles = sorted(rng.uniform(0, 2 * math.pi) for _ in range(n))
    points = []
    for angle in angles:
        r = size / 2 * rng.uniform(0.65, 1.0)
        points.append(
            (round(cx + r * math.cos(angle)), round(cy + 0.75 * r * math.sin(angle)))
        )
    polygon(mask, points)


def spread(rng, count, min_gap):
    """Picks `count` x positions around the loop, at least `min_gap` px
    apart (measured around the seam too), for evenly sprinkled shapes."""
    xs = []
    tries = 0
    while len(xs) < count and tries < 5000:
        tries += 1
        x = rng.randrange(W)
        if all(min(abs(x - o), W - abs(x - o)) >= min_gap for o in xs):
            xs.append(x)
    return sorted(xs)


def evenly(rng, count, jitter):
    """Spaces `count` x positions evenly around the loop, each nudged up to
    `jitter` px either way, for big shapes that shouldn't bunch up."""
    offset = rng.randrange(W)
    step = W / count
    return [
        (offset + round(i * step) + rng.randint(-jitter, jitter)) % W
        for i in range(count)
    ]


# --------------------------------------------------------------------------
# Coloring a mask: fill, a lit rim on the edges facing up and left, and a
# thin dithered band inside the rim to soften it.
# --------------------------------------------------------------------------


def edge(mask, dx, dy):
    """Pixels of `mask` whose neighbour at (x - dx, y - dy) is empty.

    Sideways the image wraps, so the seam has no false edge. Above the top
    row and below the bottom row count as rock, so the ceiling's top and
    the floor's bottom don't get a rim."""
    shifted = np.roll(mask, dx, axis=1)
    if dy > 0:
        shifted = np.vstack([np.ones((dy, W), dtype=bool), shifted[:-dy]])
    return mask & ~shifted


def paint(mask, fill, rim, left_rim=2, top_rim=1, dither=3):
    """Colors a mask as an RGBA layer.

    The rim is `left_rim` px on the left side of every shape and `top_rim`
    px on its top (0 turns it off); light comes from the upper left. Inside
    the left rim, a `dither`-px band of 1 px checkerboard mixes the rim
    color into the fill.
    """
    image = np.zeros((H, W, 4), dtype=np.uint8)
    image[mask] = (*fill, 255)
    rim_px = np.zeros_like(mask)
    for d in range(1, left_rim + 1):
        rim_px |= edge(mask, d, 0)
    for d in range(1, top_rim + 1):
        rim_px |= edge(mask, 0, d)
    band = np.zeros_like(mask)
    for d in range(left_rim + 1, left_rim + dither + 1):
        band |= edge(mask, d, 0)
    ys, xs = np.indices((H, W))
    checker = (xs + ys) % 2 == 0
    image[band & ~rim_px & checker] = (*rim, 255)
    image[rim_px] = (*rim, 255)
    return image


# --------------------------------------------------------------------------
# The four layers.
# --------------------------------------------------------------------------


def draw_back(rng):
    """The back wall: three flat bands of rock with a 4 px checkerboard
    where they meet, a few dark cracks, and small teal crystals."""
    image = np.zeros((H, W, 4), dtype=np.uint8)
    image[..., 3] = 255
    ys, xs = np.indices((H, W))
    for i, (top, color) in enumerate(BACK_BANDS):
        image[ys >= top] = (*color, 255)
        if i > 0:
            # Rows top-2 .. top+1: every other pixel takes the band above.
            above = BACK_BANDS[i - 1][1]
            dither = (ys >= top - 2) & (ys < top + 2) & ((xs + ys) % 2 == 0)
            image[dither] = (*above, 255)

    def band_at(y):
        return max(i for i, (top, _) in enumerate(BACK_BANDS) if y >= top)

    # ~25 cracks: short, mostly flat zig-zags, 1 px thick, that step up or
    # down a pixel now and then. Each is drawn in the next-darker tone.
    for _ in range(25):
        x = rng.randrange(W)
        y = rng.randint(12, H - 12)
        b = band_at(y)
        color = BACK_BANDS[b - 1][1] if b > 0 else BACK_CRACK_TOP
        for _ in range(rng.randint(2, 4)):
            run = rng.randint(3, 9)
            for i in range(run):
                image[y, (x + i) % W] = (*color, 255)
            x += run
            y += rng.choice([-1, 1])
            image[y, x % W] = (*color, 255)

    # 5 crystal clusters low on the wall. Each is 3-4 thin shards side by
    # side, 2-5 px tall with the tallest in the middle, with a light pixel
    # on each point and down the tallest one's left side.
    for cx in spread(rng, 5, 120):
        cy = rng.randint(185, 298)
        heights = rng.choice([[2, 4, 3], [3, 5, 3], [2, 3, 5, 3], [3, 5, 4, 2]])
        tallest = heights.index(max(heights))
        for i, h in enumerate(heights):
            x = (cx + 2 * i) % W
            for t in range(h):
                image[cy - t, x] = (*CRYSTAL, 255)
            image[cy - h + 1, x] = (*CRYSTAL_LIGHT, 255)
            if i == tallest:
                # The big shard is 2 px wide below its point.
                for t in range(h - 1):
                    image[cy - t, (x + 1) % W] = (*CRYSTAL, 255)
                image[cy - h + 2, x] = (*CRYSTAL_LIGHT, 255)
    return image


def draw_far(rng):
    """Distant rock: a low ceiling with wide stalactites and a floor with
    wide stalagmites, covering a bit over half the width."""
    mask = new_mask()
    ceiling = 47 + wave(rng, [(2, 4), (5, 2)]) + jag(rng, -2, 2, 4, 12)
    fill_above(mask, ceiling)
    floor = 290 + wave(rng, [(3, 4), (7, 2)]) + jag(rng, -2, 2, 4, 12)
    fill_below(mask, floor)

    for cx in evenly(rng, 10, 30):
        width = rng.randint(30, 60)
        base = int(ceiling[cx % W]) - 3
        spike(mask, rng, cx, base, rng.randint(78, 96) - base, width,
              curve=rng.uniform(1.3, 1.9))
        # A smaller one beside some of them, so they read as a cluster.
        if rng.random() < 0.6:
            side = cx + rng.choice([-1, 1]) * (width // 2 + rng.randint(2, 8))
            spike(mask, rng, side, int(ceiling[side % W]) - 2,
                  rng.randint(14, 28), rng.randint(10, 18), curve=1.5)

    for cx in evenly(rng, 9, 35):
        width = rng.randint(34, 64)
        base = int(floor[cx % W]) + 3
        tip = rng.randint(230, 250)
        spike(mask, rng, cx, base, base - tip, width, down=False,
              curve=rng.uniform(1.1, 1.6))
        if rng.random() < 0.6:
            side = cx + rng.choice([-1, 1]) * (width // 2 + rng.randint(2, 8))
            spike(mask, rng, side, int(floor[side % W]) + 2,
                  rng.randint(14, 30), rng.randint(12, 20), down=False,
                  curve=1.3)
    # The spec lights only the left side of the far rock.
    return paint(mask, FAR_FILL, FAR_RIM, left_rim=2, top_rim=0, dither=3)


def draw_column(mask, rng, cx, top, bottom, width):
    """Draws one whole rock column from `top` to `bottom`.

    It flares out where it meets the ceiling and the floor, like a
    stalactite and stalagmite that grew together, and its width wanders by
    a pixel or two along the way. Each side steps on its own, so the two
    edges aren't mirror images.
    """
    wobble = wave(rng, [(rng.randint(2, 4), 1.5), (rng.randint(7, 11), 1)])
    left_steps = jag(rng, -1, 1, 5, 14)
    right_steps = jag(rng, -1, 1, 5, 14)
    lean = rng.uniform(-4, 4)
    for y in range(top, bottom + 1):
        frac = (y - top) / (bottom - top)
        near_top = max(0, 1 - (y - top) / 24)
        near_bottom = max(0, 1 - (bottom - y) / 28)
        half = width / 2 + 8 * near_top**2 + 10 * near_bottom**2
        # Waisted a little in the middle, as columns usually are.
        half -= 2 * math.sin(math.pi * frac)
        centre = cx + lean * math.sin(math.pi * frac)
        left = math.floor(centre - half - wobble[y] + left_steps[y])
        right = math.ceil(centre + half + wobble[y] + right_steps[y]) - 1
        span(mask, y, left, right)


def draw_mid(rng):
    """Nearer rock: a ceiling fringe with stalactites, 5 rock columns from
    floor to ceiling (two of them broken), and rubble on the floor."""
    mask = new_mask()
    ceiling = 64 + wave(rng, [(3, 5), (8, 2)]) + jag(rng, -3, 3)
    fill_above(mask, ceiling)
    floor = 282 + wave(rng, [(4, 4), (9, 2)]) + jag(rng, -3, 2)
    fill_below(mask, floor)

    columns = evenly(rng, 5, 40)
    broken = set(rng.sample(columns, 2))
    for cx in columns:
        width = rng.randint(24, 40)
        top = int(ceiling[cx % W]) - 4
        bottom = int(floor[cx % W]) + 4
        if cx not in broken:
            draw_column(mask, rng, cx, top, bottom, width)
            continue
        # A broken column: a stalactite above and a stalagmite below, as
        # wide as a column, almost meeting across a gap.
        gap_top = rng.randint(135, 165)
        gap_bottom = gap_top + rng.randint(26, 44)
        spike(mask, rng, cx, top, gap_top - top, width + 14, curve=1.6)
        spike(mask, rng, cx + rng.randint(-4, 4), bottom, bottom - gap_bottom,
              width + 18, down=False, curve=1.4)

    # Stalactites of mixed lengths between the columns, some short and a few
    # reaching y~130.
    for cx in spread(rng, 24, 20):
        if any(min(abs(cx - c), W - abs(cx - c)) < 30 for c in columns):
            continue
        base = int(ceiling[cx % W]) - 3
        tip = rng.choice([rng.randint(82, 100), rng.randint(95, 112),
                          rng.randint(112, 132)])
        spike(mask, rng, cx, base, tip - base, rng.randint(8, 20),
              curve=rng.uniform(1.2, 1.8))

    # Stalagmites and rubble along the floor, up to y~250.
    for cx in spread(rng, 9, 50):
        base = int(floor[cx % W]) + 3
        spike(mask, rng, cx, base, base - rng.randint(250, 268),
              rng.randint(12, 24), down=False, curve=1.3)
    for _ in range(24):
        cx = rng.randrange(W)
        size = rng.randint(6, 14)
        rock(mask, rng, cx, int(floor[cx % W]) - size // 4, size)
    return paint(mask, MID_FILL, MID_RIM, left_rim=2, top_rim=1, dither=3)


def draw_near(rng):
    """The closest rock: a jagged ceiling fringe with a few long
    stalactites, and a line of chunky rubble along the floor. Rows 100-259
    stay empty."""
    mask = new_mask()
    ceiling = 37 + wave(rng, [(4, 3), (11, 2)]) + jag(rng, -3, 3, 2, 6)
    fill_above(mask, ceiling)
    # Short teeth all along the fringe.
    for cx in range(0, W, 7):
        x = cx + rng.randint(0, 4)
        spike(mask, rng, x, int(ceiling[x % W]) - 1, rng.randint(3, 9),
              rng.randint(4, 8), curve=1.0)
    # A few long ones. Their points stop by y 99, above the empty band.
    for cx in evenly(rng, 5, 50):
        base = int(ceiling[cx % W]) - 4
        spike(mask, rng, cx, base, rng.randint(80, 99) - base,
              rng.randint(16, 26), curve=rng.uniform(1.3, 1.7))

    floor = 304 + wave(rng, [(5, 3), (12, 2)]) + jag(rng, -2, 2, 3, 8)
    fill_below(mask, floor)
    # Chunky rocks, 6-14 px, sitting on the floor line from about y 285.
    x = 0
    while x < W:
        size = rng.randint(6, 14)
        rock(mask, rng, x, int(floor[x % W]) - size // 3, size)
        x += rng.randint(size // 2 + 2, size + 10)
    return paint(mask, NEAR_FILL, NEAR_RIM, left_rim=2, top_rim=1, dither=3)


# Back to front, in the order ParallaxBackground stacks them.
LAYERS = [
    ("cave_back.png", draw_back),
    ("cave_far.png", draw_far),
    ("cave_mid.png", draw_mid),
    ("cave_near.png", draw_near),
]


def build():
    """Draws every layer. Each gets its own seeded random generator, so
    changing one layer's drawing code doesn't reshuffle the others."""
    return {
        name: draw(random.Random(f"{SEED}-{name}")) for name, draw in LAYERS
    }


def png_bytes(image):
    """Encodes an RGBA array as PNG bytes."""
    buffer = io.BytesIO()
    Image.fromarray(image, "RGBA").save(buffer, format="PNG", optimize=False)
    return buffer.getvalue()


# --------------------------------------------------------------------------
# Checks.
# --------------------------------------------------------------------------


def column_change(image, x):
    """How many pixels differ between column x and column x + 1."""
    a = image[:, x % W].astype(int)
    b = image[:, (x + 1) % W].astype(int)
    return int(np.any(a != b, axis=1).sum())


def check(images):
    """Returns a list of problems (empty when all is well)."""
    problems = []
    for name, image in images.items():
        if image.shape != (H, W, 4):
            problems.append(f"{name} is {image.shape}, not {H}x{W} RGBA")
        # Seamless: going from x = 959 to x = 0 should change no more pixels
        # than SEAM_FACTOR times the average change between two neighbouring
        # columns inside the image. A seam (the ceiling or floor jumping a
        # few pixels, a shape cut off) changes many more rows than that.
        # The rock's own chunky edges step 1-3 px all the time, so a 1 px
        # step at the seam would look like any other and isn't caught.
        seam = column_change(image, W - 1)
        mean = sum(column_change(image, x) for x in range(W - 1)) / (W - 1)
        if seam > SEAM_FACTOR * mean:
            problems.append(
                f"{name} has a seam: {seam} px change at x=959->0, but "
                f"{mean:.1f} on average between neighbouring columns"
            )
        # Hard edges: every pixel is fully see-through or fully solid.
        alpha = np.unique(image[..., 3])
        if not set(alpha.tolist()) <= {0, 255}:
            problems.append(f"{name} has partly transparent pixels")
    back = images["cave_back.png"]
    if not np.all(back[..., 3] == 255):
        problems.append("cave_back.png must be opaque")
    near = images["cave_near.png"]
    top, bottom = NEAR_EMPTY_ROWS
    if np.any(near[top:bottom, :, 3]):
        problems.append(f"cave_near.png has rock in rows {top}-{bottom - 1}")
    return problems


def stale_files(images):
    """Names the layers whose committed PNG is missing or differs from
    what the script draws now."""
    return [
        name
        for name, image in images.items()
        if not (OUT_DIR / name).exists()
        or (OUT_DIR / name).read_bytes() != png_bytes(image)
    ]


# --------------------------------------------------------------------------
# Preview.
# --------------------------------------------------------------------------


def composite(images, names):
    """Stacks the named layers, back to front, over a dark backdrop."""
    out = Image.new("RGBA", (W, H), (60, 60, 60, 255))
    for name in names:
        out.alpha_composite(Image.fromarray(images[name], "RGBA"))
    return out


def preview(images, folder):
    """Draws cave_layers.png: each layer on a light grey checker (so the
    see-through parts show), then all four together, then the same with the
    game's dusk tint over it and shifted half a tile so the seam is in the
    middle."""
    folder.mkdir(parents=True, exist_ok=True)
    label_h = 14
    panels = []
    ys, xs = np.indices((H, W))
    checker = (xs // 8 + ys // 8) % 2
    grey = np.where(checker[..., None] == 0, 170, 200).astype(np.uint8)
    for name, _ in LAYERS:
        base = Image.fromarray(
            np.dstack([grey, grey, grey, np.full((H, W, 1), 255, np.uint8)]),
            "RGBA",
        )
        base.alpha_composite(Image.fromarray(images[name], "RGBA"))
        panels.append((name, base))
    names = [n for n, _ in LAYERS]
    full = composite(images, names)
    panels.append(("all four layers", full))
    # GameScreen.duskColor is 0x990B1026: navy at 60%.
    dusk = full.copy()
    dusk.alpha_composite(Image.new("RGBA", (W, H), (0x0B, 0x10, 0x26, 0x99)))
    shifted = Image.new("RGBA", (W, H))
    shifted.paste(dusk.crop((W // 2, 0, W, H)), (0, 0))
    shifted.paste(dusk.crop((0, 0, W // 2, H)), (W // 2, 0))
    panels.append(("with the dusk tint, seam (x=0) in the middle", shifted))

    sheet = Image.new("RGBA", (W, len(panels) * (H + label_h)), (20, 20, 20, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (label, panel) in enumerate(panels):
        y = i * (H + label_h)
        draw.text((4, y + 1), label, fill=(230, 230, 230, 255))
        sheet.paste(panel, (0, y + label_h))
    path = folder / "cave_layers.png"
    sheet.save(path)
    print(f"wrote {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--preview", metavar="DIR", type=pathlib.Path,
        help="also draw cave_layers.png into this folder",
    )
    parser.add_argument(
        "--check", action="store_true",
        help="write nothing; fail if the committed PNGs differ from what "
        "the script draws (they are out of date, or it isn't repeatable)",
    )
    args = parser.parse_args()

    images = build()
    problems = check(images)
    if args.check:
        problems += [
            f"{name} on disk differs from what the script draws"
            for name in stale_files(images)
        ]
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1
    if args.check:
        print("all cave layers match the committed files")
        return 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, image in images.items():
        (OUT_DIR / name).write_bytes(png_bytes(image))
        print(f"wrote {OUT_DIR / name}")
    if args.preview:
        preview(images, args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
