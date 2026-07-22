#!/usr/bin/env python3
"""Player sprite frames, authored as ASCII. Run via tools/gen_sprites.py.

THE CHARACTER — "the Delver" (round-3 redesign, approved 2026-07-21):
small and quick, athletic-compact. Bronze helmet with a real brim and a
front-mounted lamp, cigarette in his mouth (lit tip flickers on the idle),
oxblood vest over a cream shirt, satchel + rope + belt kit, slate-teal
trousers, heavy boots. Drawn facing RIGHT; the game flips for left.

CANVAS: 40 wide x 56 tall at 1x SCALE (the old sheet was 20x28 at 2x —
same size on screen, four times the pixels). PlayerSprite's scale must be
Vector2(1, 1) with this sheet. FEET SIT ON THE LAST ROW, always.

WEAPON: stage 2 is live — the pickaxe is NO LONGER drawn into the frames.
The module exports ANCHORS — per-frame hand position + weapon angle +
visibility — which gen_sprites writes into the manifest; the WeaponSprite
node reads it and renders the equipped weapon from assets/sprites/
weapons.png (see tools/sprites/weapon_frames.py). The retired _pick()
stays below as the reference for how the stage-1 bake anchored the shaft.
See docs/art-specs/weapon-layer.md.

LEGEND
  .  transparent    o  outline          H  helmet bronze   h  brim/band
  L  lamp lens      l  lamp housing     s  skin            e  eye
  d  skin shadow    c  shirt (cream)    v  vest (oxblood)  u  vest shadow
  g  leather/glove  r  rope/satchel     p  trousers        k  belt/strap
  b  boots          m  steel            w  wood
  x  cigarette      t  cig tip (lit)    E  ember (dark)    S  smoke (pale)
"""
import math

W, H = 40, 56

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (26, 18, 14, 255),
    "H": (134, 108, 72, 255),
    "h": (78, 60, 40, 255),
    "L": (255, 244, 190, 255),
    "l": (70, 62, 58, 255),
    "s": (222, 168, 128, 255),
    "e": (36, 26, 22, 255),
    "d": (150, 108, 84, 255),
    "c": (212, 196, 166, 255),
    "v": (138, 52, 44, 255),
    "u": (96, 38, 34, 255),
    "g": (124, 88, 52, 255),
    "r": (176, 138, 92, 255),
    "p": (56, 74, 78, 255),
    "k": (44, 34, 28, 255),
    "b": (62, 46, 34, 255),
    "m": (196, 202, 214, 255),
    "w": (140, 96, 54, 255),
    "x": (216, 210, 196, 255),
    "t": (255, 84, 36, 255),
    "T": (255, 150, 66, 255),
    "E": (44, 38, 34, 255),
    "S": (208, 202, 194, 255),
}

# gen_sprites reads this: full-colour sheet, lamp glow around the lens,
# warm rim light on the lit silhouette so the Delver reads against the
# dark back wall (feedback round 4).
SHADE = {"lamp": "L", "rim": True}


# ---------------------------------------------------------------- parts
# HEAD: 16 rows. Cigarette juts from the mouth (rows 14-15 of the part).
# `hot` swaps the tip brighter and lifts the smoke pixel — the idle flicker.
def _head(hot=False):
    tip = "T" if hot else "t"
    s_hi = "S" if hot else "."
    s_lo = "." if hot else "S"
    e_ch = "E" if hot else "."
    return [
        ".............ooooooooo..................",
        "...........ooHHHHHHHHHoo................",
        "..........oHHHHHHHHHHHHHo...............",
        ".........oHHHHHHHHHHHHHHHo..............",
        ".........oHHHHHHHHHHHHHollo.............",
        ".........oHHHHHHHHHHHHHolLLo............",
        "........ohhhhhhhhhhhhhhhhhhoo...........",
        ".........oohhhhhhhhhhhhhhooo............",
        "...........ossssssssssso...." + s_hi + "...........",
        "...........osseesssseeso................",
        "...........ossssssssssso.." + s_lo + ".............",
        "...........osssssssssso..." + e_ch + ".............",
        "............ossddddsssoxxx" + tip + ".............",
        ".............ossssssoooooo..............",
        "..............oossoo....................",
        "...............osso.....................",
    ]


HEAD_TOP = 4

# TORSO: 18 rows (canvas rows 20..37 when standing). LEFT (back) glove baked;
# the RIGHT (front) arm is stamped separately per pose so it can move.
TORSO = [
    "............oocccccoo...................",
    "...........occcccccccoo.................",
    "..........ovvcccccccccvo................",
    ".........ovvvccccccccvvvo...............",
    ".........ovvvccccccccvvvo...............",
    ".........ouvvccccccccvvuo...............",
    ".........ouvvvccccccvvvuo...............",
    ".........orovvvccccvvvoro...............",
    ".........orrovvvvvvvvorro...............",
    ".........orrouvvvvvvuorro...............",
    ".........oroouvvvvvvuooro...............",
    "..........o.ouuvvvvuuo.o................",
    "............okkkkkkkko..................",
    "............okkgggkkko..................",
    "...........oggokkkoo....................",
    "..........oggggooo......................",
    "..........ogggo.........................",
    "...........ooo..........................",
]
TORSO_TOP = 20

# Front-arm poses: sparse pixel stamps (row, col, chars) in CANVAS coords,
# ending in the glove. The matching hand anchor/angle lives in _POSES below.
ARM_REST = [
    (33, 17, "kgg"), (34, 17, "oggg"), (35, 18, "ogggg"),
    (36, 18, "oggg"), (37, 19, "oo"),
]
ARM_WIND = [
    (21, 20, "vv"), (19, 22, "ovv"), (17, 24, "ogg"),
    (15, 25, "ogg"), (14, 26, "og"),
]
ARM_HIGH = [
    (18, 19, "vo"), (14, 19, "ov"), (11, 18, "og"),
    (8, 18, "ogg"), (7, 19, "og"),
]
ARM_SWING = [
    (24, 22, "vv"), (26, 24, "ovv"), (28, 26, "ogg"),
    (30, 27, "ogg"), (31, 28, "og"),
]
ARM_CONTACT = [
    (27, 22, "vv"), (30, 24, "ov"), (33, 26, "ogg"),
    (35, 27, "ogg"), (36, 28, "og"),
]
ARM_BRACE = [
    (24, 20, "vvo"), (25, 22, "ogg"), (26, 22, "oggg"), (27, 23, "og"),
]

# LEGS: 18 rows (canvas rows 38..55). Feet always end on the last row.
LEGS_STAND = [
    "............opppppppo...................",
    "...........oppppppppo...................",
    "...........opppppppppo..................",
    "...........opppopppppo..................",
    "...........oppo..oppo...................",
    "...........oppo..oppo...................",
    "..........okppo..oppko..................",
    "..........oppppo.opppo..................",
    "..........oppo....oppo..................",
    "..........oppo....oppo..................",
    ".........obbbo....obbbo.................",
    ".........obbbo....obbbo.................",
    "........obbbbo....obbbbo................",
    "........obbbbo....obbbbo................",
    ".......obbbbbo....obbbbbo...............",
    ".......obbbbbbo..obbbbbbo...............",
    ".......obbbbbbo..obbbbbbo...............",
    "........oooooo....oooooo................",
]
LEGS_STRIDE_A = [
    "............opppppppo...................",
    "...........opppppppppo..................",
    "..........opppppppppppo.................",
    ".........oppppo..oppppo.................",
    "........opppo......opppo................",
    ".......opppo........opppo...............",
    "......okppo..........oppko..............",
    ".....oppppo...........opppo.............",
    "....oppo...............oppo.............",
    "...oppo................oppo.............",
    "...obbo................obbbo............",
    "..obbbo................obbbbo...........",
    "..obbbo................obbbbo...........",
    ".obbbbo................obbbbbo..........",
    ".obbbbo.................obbbbo..........",
    "obbbbbo.................obbbbbo.........",
    "obbbbbo.................obbbbbo.........",
    ".ooooo...................ooooo..........",
]
LEGS_STRIDE_B = [
    "............opppppppo...................",
    "...........oppppppppo...................",
    "...........oppppppppo...................",
    "...........opppppppo....................",
    "............opppppo.....................",
    "............opppppo.....................",
    "...........okpppppo.....................",
    "...........opppppo......................",
    "...........oppppo.oppo..................",
    "..........oppppo...oppo.................",
    "..........obbbo....obbo.................",
    ".........obbbbo....obbo.................",
    ".........obbbbo.....oo..................",
    "........obbbbbo.........................",
    "........obbbbo..........................",
    ".......obbbbbo..........................",
    ".......obbbbbo..........................",
    "........ooooo...........................",
]
LEGS_AIR = [
    "............opppppppo...................",
    "...........opppppppppo..................",
    "..........oppppppppppo..................",
    ".........opppo...opppo..................",
    "........opppo.....opppo.................",
    ".......opppo.......oppo.................",
    "......okppo........oppko................",
    ".....opppo..........opppo...............",
    "....oppo.............opppo..............",
    "....oppo..............oppo..............",
    "...obbbo..............obbbo.............",
    "...obbbo...............obbbo............",
    "..obbbo................obbbo............",
    "..obbbo................obbbbo...........",
    ".obbbo..................obbbo...........",
    ".obbbo..................obbbbo..........",
    ".obbbo..................obbbbo..........",
    "..ooo....................oooo...........",
]
LEGS_TOP = 38

# ROLL: full-frame curl, drawn whole (a tucked ball reads at any angle).
ROLL_A = ["." * 40] * 38 + [
    "..............ooooooooo.................",
    "............ooHHHHHHHHHoo...............",
    "...........oHHHHHHHHHHHHHo..............",
    "..........ohhhhhhhhhhhhhho..............",
    "..........ovvvvccccccvvvvoo.............",
    ".........ovvvvccccccccvvvvo.............",
    ".........ovvvooooooooovvvvo.............",
    ".........ouvvoppppppppovvuo.............",
    ".........orrooppo..oppoorro.............",
    ".........orroobbo..obboorro.............",
    "..........oooobbbooobbboo...............",
    "...........okkobbboobbbo................",
    "...........oggobbboobbbo................",
    "............ooobbbbbbbo.................",
    "..............obbbbbo...................",
    "...............obbbo....................",
    "................ooo.....................",
    "........................................",
]
ROLL_B = ["." * 40] * 40 + [
    "..............ooooooooo.................",
    "...........ooHHHHHHHHHHo................",
    "..........ohhhhhhhhhhhhho...............",
    ".........ovvvvccccccvvvvvo..............",
    ".........ovvvcccccccccvvvo..............",
    ".........ovvoooooooooovvvo..............",
    ".........ouvopppppppppovuo..............",
    ".........orroppo..oppoorro..............",
    ".........orrobbo..obbo.rro..............",
    "..........oo.obboobbbo.o................",
    "...........okobbboobbo..................",
    "...........ogobbbbbbbo..................",
    "............oobbbbbbo...................",
    ".............obbbbbo....................",
    "..............obbbo.....................",
    "...............ooo......................",
]


def _blank():
    return [["." for _ in range(W)] for _ in range(H)]


def _stamp(grid, rows, top):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            gy = top + y
            if 0 <= gy < H and 0 <= x < W:
                grid[gy][x] = ch


def _pixels(grid, spec):
    for top, left, chunk in spec:
        for i, ch in enumerate(chunk):
            if ch != "." and 0 <= top < H and 0 <= left + i < W:
                grid[top][left + i] = ch


def _put(grid, x, y, ch):
    if 0 <= y < H and 0 <= x < W:
        grid[y][x] = ch


def _line(grid, x0, y0, x1, y1, ch):
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        _put(grid, x0, y0, ch)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def _pick(grid, hand, angle_deg, length=16):
    """Pickaxe anchored at the glove: wood shaft along `angle_deg`
    (0 = forward/right, 90 = straight up), steel head perpendicular."""
    a = math.radians(angle_deg)
    hx, hy = hand
    tx = int(round(hx + math.cos(a) * length))
    ty = int(round(hy - math.sin(a) * length))
    _line(grid, hx, hy, tx, ty, "w")
    pa = a + math.pi / 2
    for s in (-1, 1):
        ex = int(round(tx + math.cos(pa) * 5 * s))
        ey = int(round(ty - math.sin(pa) * 5 * s))
        _line(grid, tx, ty, ex, ey, "m")
        _put(grid, ex, ey, "o")
    _put(grid, tx, ty, "m")
    _put(grid, tx, ty + 1, "o")


# Pose table: name -> (arm, hand anchor, weapon angle, shown, shaft length).
# Lengths are tuned so the pick head never clips the canvas edge, and the
# rest pose shoulders the shaft BEHIND the body (75°) instead of across it.
_POSES = {
    "rest":    (ARM_REST,    (20, 35), 75,  True, 18),
    "wind":    (ARM_WIND,    (27, 14), 140, True, 15),
    "high":    (ARM_HIGH,    (20, 8),  85,  True, 9),
    "swing":   (ARM_SWING,   (29, 31), 20,  True, 10),
    "contact": (ARM_CONTACT, (29, 36), -35, True, 12),
    "brace":   (ARM_BRACE,   (26, 26), 95,  True, 13),
    "none":    (None,        (20, 35), 75,  False, 0),
}


def _frame(legs, pose="rest", bob=0, hot=False):
    g = _blank()
    arm, hand, angle, shown, length = _POSES[pose]
    hand = (hand[0], hand[1] + bob)
    # Stage 2: the weapon is no longer baked in — WeaponSprite renders it
    # from the ANCHORS block. The `shown`/`length` fields stay in _POSES
    # because `show` still drives the anchors (holstering on roll).
    _stamp(g, _head(hot), HEAD_TOP + bob)
    _stamp(g, TORSO, TORSO_TOP + bob)
    if arm:
        _pixels(g, [(r + bob, c, s) for r, c, s in arm])
    _stamp(g, legs, LEGS_TOP)
    return ["".join(r) for r in g]


def _whole(rows):
    out = [r.ljust(W, ".")[:W] for r in rows]
    while len(out) < H:
        out.append("." * W)
    return out[:H]


# --- The animation set -----------------------------------------------------
# Names match the player FSM state names lowercased (PlayerSprite contract).

FRAMES = {
    # Breathing + cigarette flicker: tip glows and smoke lifts on the exhale.
    "idle": [_frame(LEGS_STAND, "rest", 0, hot=False),
             _frame(LEGS_STAND, "rest", 1, hot=True)],
    "run": [
        _frame(LEGS_STRIDE_A, "rest", 0),
        _frame(LEGS_STRIDE_B, "rest", 1),
        _frame(LEGS_STRIDE_A, "rest", 0),
        _frame(LEGS_STRIDE_B, "rest", 1),
    ],
    "air": [_frame(LEGS_AIR, "rest", 0)],
    "roll": [_whole(ROLL_A), _whole(ROLL_B)],
    # Five poses: wind, overhead, launch, contact, follow-through. The engine
    # fits one cycle to the weapon's real startup+active+recovery, so heavy
    # weapons play this slow and daggers flick through it.
    "attack": [
        _frame(LEGS_STAND, "wind", 0),
        _frame(LEGS_STAND, "high", 0),
        _frame(LEGS_STAND, "swing", 1),
        _frame(LEGS_STAND, "contact", 2),
        _frame(LEGS_STAND, "rest", 1),
    ],
    "parry": [_frame(LEGS_STAND, "brace", 0)],
    "hitstun": [_frame(LEGS_STAND, "rest", 2)],
}

# Stage-2 contract: per-frame hand anchor + weapon angle + visibility,
# written into the manifest by gen_sprites. See docs/art-specs/weapon-layer.md.
_FRAME_POSES = {
    "idle": [("rest", 0), ("rest", 1)],
    "run": [("rest", 0), ("rest", 1), ("rest", 0), ("rest", 1)],
    "air": [("rest", 0)],
    "roll": [("none", 0), ("none", 0)],
    "attack": [("wind", 0), ("high", 0), ("swing", 1), ("contact", 2), ("rest", 1)],
    "parry": [("brace", 0)],
    "hitstun": [("rest", 2)],
}
ANCHORS = {
    anim: [{"hand": [_POSES[p][1][0], _POSES[p][1][1] + b],
            "angle": _POSES[p][2], "show": _POSES[p][3]}
           for p, b in poses]
    for anim, poses in _FRAME_POSES.items()
}
