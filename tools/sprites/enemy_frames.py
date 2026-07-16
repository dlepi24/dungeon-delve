#!/usr/bin/env python3
"""Enemy sprite frames, authored as ASCII. Run via tools/gen_sprites.py.

DRAWN IN GREYSCALE ON PURPOSE. The enemies' colour is their telegraph: BodyJuice
tints them from their EnemyStats — idle colour, yellow on wind-up, red on the
swing, blue when staggered, white when hit. That tint multiplies over these
pixels, so pale grey art takes the colour cleanly while pre-coloured art would
fight it and turn to mud.

It also keeps identity in the `.tres`: the Grunt is red, the Brute purple, the
Dart green, and changing that is a data edit rather than a redraw. And the GDD's
"telegraph everything, readability over surprise" survives having real art —
which it would not if each sprite hard-coded its own colours.

The poses telegraph too, not just the colour: reared back, arm overhead, coiled.
A player who cannot separate red from yellow still gets the warning.

LAYOUT RULE, learned the hard way: the parts must ADD UP to the canvas height and
the feet must land on the last row. The first version had heads, bodies and legs
that summed to about half the sprite, so the creatures wore their legs like
detached stilts with a gap of empty pixels in the middle.

LEGEND
  .  transparent   o  outline (near-black)
  b  body (mid)    l  highlight (lamp-lit top)
  d  shadow        e  eye / accent (brightest — reads as the thing looking at you)
"""

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (20, 16, 14, 255),
    "d": (104, 98, 94, 255),
    "b": (172, 166, 160, 255),
    "l": (228, 224, 218, 255),
    "e": (255, 255, 255, 255),
}


def _grid(w, h):
    return [["." for _ in range(w)] for _ in range(h)]


def _stamp(g, rows, top, w, h, dx=0):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            gy, gx = top + y, x + dx
            if 0 <= gy < h and 0 <= gx < w:
                g[gy][gx] = ch


def _pixels(g, spec, w, h):
    for top, left, chunk in spec:
        for i, ch in enumerate(chunk):
            if ch == "." or not (0 <= top < h and 0 <= left + i < w):
                continue
            g[top][left + i] = ch


def _out(g):
    return ["".join(r) for r in g]


# =========================================================================
# GRUNT — 18 x 32. A hunched scavenger: low head, long arms, splayed claws.
# head 8 (4..11) + body 12 (12..23) + legs 8 (24..31) = fills the canvas.
# =========================================================================
GRUNT_W, GRUNT_H = 18, 32
_G_HEAD_TOP, _G_BODY_TOP, _G_LEGS_TOP = 4, 12, 24

_G_HEAD = [
    "...oooooo...",
    "..obbbbbbo..",
    ".obbbbbbbbo.",
    ".obeobbeobo.",
    ".obbbbbbbbo.",
    "..obdddddo..",
    "..oobbbboo..",
    "...oobboo...",
]
_G_BODY = [
    "..oobbbboo..",
    ".obllbbllbo.",
    "obbbbbbbbbbo",
    "obbbbbbbbbbo",
    "obdbbbbbbdbo",
    "obdbbbbbbdbo",
    "obbbbbbbbbbo",
    ".obbbbbbbbo.",
    ".obbbbbbbbo.",
    "..obbbbbbo..",
    "..oobbbboo..",
    "...obbbbo...",
]
_G_LEGS_STAND = [
    "...obbbbo...",
    "...obbbbo...",
    "..obbo.obbo.",
    "..obbo.obbo.",
    "..obbo.obbo.",
    ".obbbo.obbbo",
    ".obbbo.obbbo",
    ".ooooo.ooooo",
]
_G_LEGS_A = [
    "...obbbbo...",
    "...obbbbo...",
    "..obbo..obbo",
    ".obbo....obb",
    ".obbo.....ob",
    "obbbo.....ob",
    "obbbo......o",
    "ooooo.......",
]
_G_LEGS_B = [
    "...obbbbo...",
    "...obbbbo...",
    "...obbobbo..",
    "...obbobbo..",
    "....obbbo...",
    "...obbbbbo..",
    "...obbbbbo..",
    "...ooooooo..",
]
_G_ARM_REST = [(15, 0, "ood"), (16, 0, "obbd"), (17, 0, "obbd"), (18, 0, "obbd"), (19, 1, "ooo")]
_G_ARM_BACK = [(11, 0, "ood"), (12, 0, "obbd"), (13, 0, "obbd"), (14, 1, "ooo")]
_G_ARM_SWING = [(15, 12, "doo"), (16, 11, "dbbo"), (17, 11, "dbbo"), (18, 12, "doo")]


def _grunt(legs, arm, bob=0, hunch=0):
    g = _grid(GRUNT_W, GRUNT_H)
    _pixels(g, arm, GRUNT_W, GRUNT_H)
    _stamp(g, _G_HEAD, _G_HEAD_TOP + bob + hunch, GRUNT_W, GRUNT_H, 3)
    _stamp(g, _G_BODY, _G_BODY_TOP + bob, GRUNT_W, GRUNT_H, 3)
    _stamp(g, legs, _G_LEGS_TOP, GRUNT_W, GRUNT_H, 3)
    return _out(g)


# =========================================================================
# BRUTE — 26 x 44. A slab. Tiny head on a huge armoured torso, thick legs.
# head 8 (2..9) + body 22 (10..31) + legs 12 (32..43).
# =========================================================================
BRUTE_W, BRUTE_H = 26, 44
_B_HEAD_TOP, _B_BODY_TOP, _B_LEGS_TOP = 2, 10, 32

_B_HEAD = [
    "....oooooo....",
    "...obbbbbbo...",
    "..obbbbbbbbo..",
    "..obeobbeobo..",
    "..obbbbbbbbo..",
    "...obddddbo...",
    "...oobbbboo...",
    "....oobboo....",
]
_B_BODY = [
    "..oooobbbboooo..",
    ".obllbbbbbbllbo.",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    "obdbbbbbbbbbbdbo",
    "obdbbbbbbbbbbdbo",
    "obdbbbbbbbbbbdbo",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    ".obbbbbbbbbbbbo.",
    ".obbbbbbbbbbbbo.",
    ".obdbbbbbbbbdbo.",
    ".obbbbbbbbbbbbo.",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..oobbbbbbbboo..",
    "...obbbbbbbbo...",
    "...obbbbbbbbo...",
    "....obbbbbbo....",
    "....obbbbbbo....",
    "....oobbbboo....",
    ".....oobboo.....",
]
_B_LEGS_STAND = [
    "...obbbo..obbbo...",
    "...obbbo..obbbo...",
    "...obbbo..obbbo...",
    "...obbbo..obbbo...",
    "...obbbo..obbbo...",
    "...obbbo..obbbo...",
    "..obbbbo..obbbbo..",
    "..obbbbo..obbbbo..",
    "..obbbbo..obbbbo..",
    ".obbbbbo..obbbbbo.",
    ".obbbbbo..obbbbbo.",
    ".ooooooo..ooooooo.",
]
_B_LEGS_A = [
    "...obbbo..obbbo...",
    "..obbbo....obbbo..",
    "..obbbo....obbbo..",
    ".obbbo......obbbo.",
    ".obbbo......obbbo.",
    "obbbo........obbbo",
    "obbbo........obbbo",
    "obbbo........obbbo",
    "obbbbo......obbbbo",
    "obbbbo......obbbbo",
    "ooooo........ooooo",
    "..................",
]
_B_ARM_REST = [
    (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 0, "obbd"), (18, 0, "obbd"), (19, 1, "ooo"),
    (14, 21, "doo"), (15, 20, "dbbo"), (16, 20, "dbbo"), (17, 20, "dbbo"), (18, 20, "dbbo"), (19, 21, "ooo"),
]
_B_ARM_HIGH = [
    (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 1, "ooo"),
    (1, 19, "doo"), (2, 18, "dbbo"), (3, 18, "dbbo"), (4, 18, "dbbo"), (5, 19, "dbo"), (6, 19, "doo"),
]
_B_ARM_DOWN = [
    (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 1, "ooo"),
    (26, 19, "doo"), (27, 18, "dbbo"), (28, 18, "dbbo"), (29, 19, "doo"),
]


def _brute(legs, arm, bob=0):
    g = _grid(BRUTE_W, BRUTE_H)
    _pixels(g, arm, BRUTE_W, BRUTE_H)
    _stamp(g, _B_HEAD, _B_HEAD_TOP + bob, BRUTE_W, BRUTE_H, 6)
    _stamp(g, _B_BODY, _B_BODY_TOP + bob, BRUTE_W, BRUTE_H, 5)
    _stamp(g, legs, _B_LEGS_TOP, BRUTE_W, BRUTE_H, 4)
    return _out(g)


# =========================================================================
# DART — 14 x 24. Low and all legs. body 14 (4..17) + legs 6 (18..23).
# =========================================================================
DART_W, DART_H = 14, 24
_D_BODY_TOP, _D_LEGS_TOP = 4, 18

_D_BODY = [
    "..oooooo..",
    ".obbbbbbo.",
    "obbbbbbbbo",
    "obeobbeobo",
    "obbbbbbbbo",
    "obdbbbbdbo",
    "obbbbbbbbo",
    ".obbbbbbo.",
    ".obbbbbbo.",
    "..obbbbo..",
    "..obbbbo..",
    "...oббo...".replace("б", "b"),
    "...oooo...",
    "..........",
]
_D_LEGS_STAND = [
    ".obo.oo.obo.",
    "obo..oo..obo",
    "obo..oo..obo",
    "oo........oo",
    "............",
    "............",
]
_D_LEGS_A = [
    "obo...oo...obo",
    "bo....oo....ob",
    "o.....oo.....o",
    "o.....oo.....o",
    "..............",
    "..............",
]
_D_LEGS_TUCK = [
    "..obooobo...",
    "..obo.obo...",
    "..oo...oo...",
    "............",
    "............",
    "............",
]


def _dart(legs, bob=0, stretch=0):
    g = _grid(DART_W, DART_H)
    _stamp(g, _D_BODY, _D_BODY_TOP + bob - stretch, DART_W, DART_H, 2)
    _stamp(g, legs, _D_LEGS_TOP + bob, DART_W, DART_H, 1)
    return _out(g)


# =========================================================================
# The sets. Names match the Enemy FSM's State enum lowercased, so the sprite
# reads the live state and plays it — no translation table, no second state
# machine to fall out of sync.
# =========================================================================

SHEETS = {
    "grunt": {
        "size": (GRUNT_W, GRUNT_H),
        "palette": PALETTE,
        "frames": {
            "idle": [_grunt(_G_LEGS_STAND, _G_ARM_REST, 0), _grunt(_G_LEGS_STAND, _G_ARM_REST, 1)],
            "chase": [
                _grunt(_G_LEGS_A, _G_ARM_REST, 0),
                _grunt(_G_LEGS_B, _G_ARM_REST, 1),
                _grunt(_G_LEGS_A, _G_ARM_REST, 0),
                _grunt(_G_LEGS_B, _G_ARM_REST, 1),
            ],
            "telegraph": [_grunt(_G_LEGS_STAND, _G_ARM_BACK, 0, -1), _grunt(_G_LEGS_STAND, _G_ARM_BACK, 0, -2)],
            "attack": [_grunt(_G_LEGS_STAND, _G_ARM_SWING, 1), _grunt(_G_LEGS_STAND, _G_ARM_SWING, 2)],
            "recover": [_grunt(_G_LEGS_STAND, _G_ARM_REST, 2)],
            "hurt": [_grunt(_G_LEGS_STAND, _G_ARM_BACK, 2, 1)],
            "stagger": [_grunt(_G_LEGS_B, _G_ARM_BACK, 3, 2)],
            "dead": [_grunt(_G_LEGS_B, _G_ARM_REST, 5, 3)],
        },
    },
    "brute": {
        "size": (BRUTE_W, BRUTE_H),
        "palette": PALETTE,
        "frames": {
            "idle": [_brute(_B_LEGS_STAND, _B_ARM_REST, 0), _brute(_B_LEGS_STAND, _B_ARM_REST, 1)],
            "chase": [
                _brute(_B_LEGS_A, _B_ARM_REST, 0),
                _brute(_B_LEGS_STAND, _B_ARM_REST, 1),
                _brute(_B_LEGS_A, _B_ARM_REST, 0),
                _brute(_B_LEGS_STAND, _B_ARM_REST, 1),
            ],
            # 750 ms of arm in the air. You have ages to read it; that IS the Brute.
            "telegraph": [_brute(_B_LEGS_STAND, _B_ARM_HIGH, 0), _brute(_B_LEGS_STAND, _B_ARM_HIGH, -1)],
            "attack": [_brute(_B_LEGS_STAND, _B_ARM_DOWN, 1), _brute(_B_LEGS_STAND, _B_ARM_DOWN, 2)],
            "recover": [_brute(_B_LEGS_STAND, _B_ARM_REST, 2)],
            "hurt": [_brute(_B_LEGS_STAND, _B_ARM_REST, 2)],
            "stagger": [_brute(_B_LEGS_A, _B_ARM_REST, 4)],
            "dead": [_brute(_B_LEGS_A, _B_ARM_REST, 6)],
        },
    },
    "dart": {
        "size": (DART_W, DART_H),
        "palette": PALETTE,
        "frames": {
            "idle": [_dart(_D_LEGS_STAND, 0), _dart(_D_LEGS_STAND, 1)],
            "chase": [_dart(_D_LEGS_A, 0), _dart(_D_LEGS_STAND, 1), _dart(_D_LEGS_A, 0), _dart(_D_LEGS_STAND, 1)],
            # Coils, then lunges flat. Its window is short, so the pose must shout.
            "telegraph": [_dart(_D_LEGS_TUCK, 2), _dart(_D_LEGS_TUCK, 3)],
            "attack": [_dart(_D_LEGS_TUCK, 0, 2), _dart(_D_LEGS_TUCK, 0, 3)],
            "recover": [_dart(_D_LEGS_STAND, 1)],
            "hurt": [_dart(_D_LEGS_TUCK, 2)],
            "stagger": [_dart(_D_LEGS_TUCK, 3)],
            "dead": [_dart(_D_LEGS_TUCK, 4)],
        },
    },
}
