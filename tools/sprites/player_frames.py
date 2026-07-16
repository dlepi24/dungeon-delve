#!/usr/bin/env python3
"""Player sprite frames, authored as ASCII.

Run via tools/gen_sprites.py — this module only defines the art.

WHY ASCII: same reason the rooms are ASCII. A PNG is unreviewable in a diff and
uneditable without a paint program; this you can read, tweak and diff. Change a
character, re-run the generator, the sheet rebuilds.

THE CHARACTER: a miner. Helmet with a lamp on the front, work coat, heavy boots,
and a pickaxe — the tool you came down with and the weapon you fight with.
Drawn facing RIGHT; the game flips it for left.

CANVAS: 20 wide x 28 tall, drawn at 2x = 40x56 in game.
FEET SIT ON THE LAST ROW. The player's origin is its feet, so anything else
makes the sprite hover. (The first version ended at row 21 and floated six
pixels off the floor.)

LEGEND
  .  transparent      o  outline (near-black; what makes it read at any size)
  h  helmet           l  lamp (hottest colour on the sheet)
  s  skin             c  coat
  p  trousers         b  boot
  w  pickaxe handle   m  pickaxe head
"""

W, H = 20, 28

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (24, 17, 13, 255),
    "h": (222, 164, 48, 255),
    "l": (255, 246, 198, 255),
    "s": (224, 170, 130, 255),
    "c": (78, 100, 128, 255),
    "p": (58, 48, 44, 255),
    "b": (38, 29, 23, 255),
    "w": (132, 90, 50, 255),
    "m": (182, 188, 202, 255),
}

# Vertical layout, chosen so the boots land exactly on row 27.
HEAD_TOP = 6
TORSO_TOP = 14
LEGS_TOP = 21

HEAD = [
    "........oooo........",
    ".......ohhhhho......",
    "......ohhhhhhho.....",
    "......olhhhhhho.....",
    "......oolhhhhoo.....",
    ".......osssso.......",
    ".......ossoso.......",
    "........oooo........",
]

TORSO = [
    ".....ooccccoo.......",
    "....occcccccco......",
    "....occcccccco......",
    "....occcccccco......",
    "....ooccccccoo......",
    ".....occcccco.......",
    ".....ooccccoo.......",
]

LEGS_STAND = [
    ".....oppppppo.......",
    ".....opp..ppo.......",
    ".....opp..ppo.......",
    ".....opp..ppo.......",
    "....obbbo.obbbo.....",
    "....obbbo.obbbo.....",
    ".....ooo...ooo......",
]
LEGS_STRIDE_A = [
    ".....oppppppo.......",
    "....oppo...oppo.....",
    "...oppo.....oppo....",
    "...opo.......opo....",
    "..obbbo.....obbbo...",
    "..obbbo......obbbo..",
    "...ooo........ooo...",
]
LEGS_STRIDE_B = [
    ".....oppppppo.......",
    ".....opppppo........",
    "......oppppo........",
    "......oppppo........",
    ".....obbbbo.........",
    "....obbbbo..........",
    ".....oooo...........",
]
LEGS_TUCK = [
    "....................",
    "....oppppppppo......",
    "...opp......ppo.....",
    "...obb......bbo.....",
    "....oo......oo......",
    "....................",
    "....................",
]
LEGS_AIR = [
    ".....oppppppo.......",
    "....oppo...oppo.....",
    "...oppo.....oppo....",
    "...opo.......oppo...",
    "..obbbo.......obbo..",
    "..obbbo........ooo..",
    "...ooo..............",
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


def _put(grid, x, y, ch):
    if 0 <= y < H and 0 <= x < W:
        grid[y][x] = ch


def _line(grid, x0, y0, x1, y1, ch):
    """Bresenham. The handle is a line from the hand to the head — drawing it
    rather than hand-placing pixels is what lets the axe swing through poses
    without me redrawing it four times."""
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


def _axe(grid, hand, head, flip=False):
    """Handle from the hand to the head, then the head itself. `hand` is where
    the miner's fist is — keeping the handle anchored there is what stops the
    pickaxe reading as a floating object next to him, which is exactly how the
    first version looked."""
    hx, hy = hand
    ax, ay = head
    _line(grid, hx, hy, ax, ay, "w")
    # Head: a wedge either side of the shaft, outlined so it reads at 2x.
    dirn = -1 if flip else 1
    for i in range(3):
        _put(grid, ax + dirn * i, ay, "m")
        _put(grid, ax + dirn * i, ay - 1, "m" if i < 2 else "o")
    _put(grid, ax - dirn, ay, "m")
    _put(grid, ax - dirn, ay - 1, "o")
    _put(grid, ax + dirn * 3, ay, "o")
    _put(grid, ax, ay + 1, "o")
    _put(grid, ax + dirn, ay + 1, "o")


# The fist, in canvas coordinates. Sits on the right edge of the torso.
HAND = (13, 18)

AXE_POSES = {
    # Shouldered. The classic miner silhouette, and it keeps the axe out of the
    # way of the body while idle.
    "rest": ((15, 8), False),
    # Wound up and back, behind the head.
    "wind": ((17, 7), False),
    # Overhead at the top of the swing.
    "high": ((11, 3), False),
    # Struck down and forward — where the hitbox actually is.
    "down": ((18, 22), False),
    # Braced across the body for a parry.
    "brace": ((16, 12), False),
}


def _frame(legs, axe=None, bob=0):
    # Axe FIRST, so the body draws over it. The handle passes behind the miner
    # rather than through his helmet, which is what it did when the axe was
    # stamped last — an overhead swing sliced the character's face in half.
    g = _blank()
    if axe:
        head, flip = AXE_POSES[axe]
        _axe(g, (HAND[0], HAND[1] + bob), head, flip)
    _stamp(g, HEAD, HEAD_TOP + bob)
    _stamp(g, TORSO, TORSO_TOP + bob)
    _stamp(g, legs, LEGS_TOP)
    return ["".join(r) for r in g]


# --- The animation set -----------------------------------------------------
# Names match the player's FSM state names lowercased, so the sprite can be
# driven straight from the state with no translation table.

FRAMES = {
    # Breathing. One pixel of bob: alive, but never distracting mid-fight.
    "idle": [_frame(LEGS_STAND, "rest", 0), _frame(LEGS_STAND, "rest", 1)],
    # Contact, pass, contact, pass. The bob is what sells the weight.
    "run": [
        _frame(LEGS_STRIDE_A, "rest", 0),
        _frame(LEGS_STRIDE_B, "rest", 1),
        _frame(LEGS_STRIDE_A, "rest", 0),
        _frame(LEGS_STRIDE_B, "rest", 1),
    ],
    "air": [_frame(LEGS_AIR, "rest", 0)],
    # Tucked and axe-less: the body spins during a roll, and a tuck reads at any
    # angle where a standing pose does not.
    "roll": [_frame(LEGS_TUCK, None, 3), _frame(LEGS_TUCK, None, 4)],
    # Wind up, overhead, strike down. Three frames is the fewest that reads as a
    # swing rather than a teleporting pickaxe.
    "attack": [
        _frame(LEGS_STAND, "wind", 0),
        _frame(LEGS_STAND, "high", 0),
        _frame(LEGS_STAND, "down", 1),
    ],
    "parry": [_frame(LEGS_STAND, "brace", 0)],
    "hitstun": [_frame(LEGS_STAND, "rest", 2)],
}
