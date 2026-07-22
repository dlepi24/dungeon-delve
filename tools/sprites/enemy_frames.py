#!/usr/bin/env python3
"""Enemy sprite frames, authored as ASCII. Run via tools/gen_sprites.py.

DRAWN IN GREYSCALE ON PURPOSE. The enemies' colour is their telegraph: BodyJuice
tints them from their EnemyStats — idle colour, yellow on wind-up, red on the
swing, blue when staggered, white when hit. That tint multiplies over these
pixels, so pale grey art takes the colour cleanly while pre-coloured art would
fight it and turn to mud. Identity stays in the `.tres`.

v3 art pass (2026-07-21): THE LOST CREWS. The enemies are miners who never
came back up (GDD decision, same date) — hollow, lantern-eyed, still carrying
their tools. Every silhouette now tells the crewman's old job:
  grunt     18x32  the DIGGER: hunched, cap-lamp helmet, hollow lantern eyes,
                   still gripping a broken pick haft
  brute     26x44  the HAULER: yoke beam across the shoulders, harness straps
                   crossing the chest plate, a chain swinging off the belt
  dart      14x24  the PIT RAT: crawls the shafts on all fours, lunges
                   helmet-first, lamp still burning
  gnat      16x20  the CANARY: the cage bird that died down here — skeletal,
                   wings torn through with holes
  slinger   20x36  the POWDER-MONKEY: soft cap, bandolier of blasting charges,
                   winds up a charge that SPARKS white before the throw
  overseer  34x52  VAROK: crested foreman helm, lantern eyes in a visor slit,
                   chain across the chest plates, a lit lantern on the belt
Sheet names, canvas sizes, and frame names are all unchanged — the .tres
wiring from v2 keeps working; only the pixels moved.

The lantern-eye rule: every crewman's `e` pixels sit inside dark sockets or
under a dark brim, so the brightest thing on the sprite is the thing looking
at you — and because `e` bakes near-white, it reads through ANY telegraph tint.

STRUCTURE: everything between the DATA markers is PURE LITERALS — the browser
preview tool parses that block and composes frames identically to the python
below it. Keep it literal: no variables, no expressions, comments only on
their own lines.

Frame = list of layers, drawn in order (first = furthest back).
Layer = (part_or_spec, top, dx): "name" stamps PARTS[name] at row `top`,
column `dx`; "@name" offsets every (row, col, chars) pixel run in
SPECS[name] by (top, dx). Feet land on the last row of every grounded pose.

LEGEND
  .  transparent   o  outline (near-black)
  b  body (mid)    l  highlight (metal / wood / bone)
  d  shadow / rag  e  lantern glow (eyes + lamps — the brightest pixels)
"""

# === DATA (parsed by the preview tool; literals only) ===
DATA = {
    "palette": {
        ".": (0, 0, 0, 0),
        "o": (20, 16, 14, 255),
        "d": (104, 98, 94, 255),
        "b": (172, 166, 160, 255),
        "l": (228, 224, 218, 255),
        "e": (255, 255, 255, 255),
    },
    "parts": {
        # ---- DIGGER (grunt) 18x32: cap-lamp helmet, hollow eyes, ragged coat.
        "g_head": [
            "...oooooo...",
            "..obbbbbbo..",
            ".obbbbbbbbo.",
            "obbbbbbblleo",
            "oddooooooodo",
            ".odbeobbeodo",
            ".oddbbbbddo.",
            "..oobbbboo..",
        ],
        "g_body": [
            "..oobbbboo..",
            ".obldbbbbbo.",
            "obbbbdbbbbbo",
            "obbbbbdbbblo",
            "obbbbbbdbblo",
            "obdbbbbbdbbo",
            "obdbbbbbbdbo",
            ".obbbbbbbbo.",
            ".obbbbbbbbo.",
            "..obdbbdbo..",
            "..odbobbdo..",
            "...obo.obo..",
        ],
        "g_legs_stand": [
            "...obbbbo...",
            "...obbbbo...",
            "..obbo.obbo.",
            "..obbo.obbo.",
            "..obbo.obbo.",
            ".obbbo.obbbo",
            ".obbbo.obbbo",
            ".obobo.obobo",
        ],
        "g_legs_a": [
            "...obbbbo...",
            "...obbbbo...",
            "..obbo..obbo",
            ".obbo....obb",
            ".obbo.....ob",
            "obbbo.....ob",
            "obbbo......o",
            "obobo.......",
        ],
        "g_legs_b": [
            "...obbbbo...",
            "...obbbbo...",
            "...obbobbo..",
            "...obbobbo..",
            "....obbbo...",
            "...obbbbbo..",
            "...obbbbbo..",
            "...obobobo..",
        ],
        # ---- HAULER (brute) 26x44: yoke, harness X, chest plate, belt chain.
        "b_head": [
            "....oooooo....",
            "..oobbbbbboo..",
            ".obbbbbbbbbbo.",
            ".oddddddddddo.",
            ".odbeobbeobdo.",
            ".obbbbbbbbbbo.",
            "..obddddddbo..",
            "...oobbbboo...",
        ],
        "b_body": [
            "..oolllllllloo..",
            ".obllbbbbbbllbo.",
            "obbbbbbbbbbbbbbo",
            "oblbbdbbbbdbblbo",
            "obbbbbdbbdbbbbbo",
            "obbbbbbdlbbbbbbo",
            "obbbbbdbbdbbbbbo",
            "obdbbdbbbbdbbdbo",
            "obbbbdddddbbbbbo",
            ".obbbbbbbbbbbbo.",
            ".obbbbbbbbbbbbo.",
            ".obdbbbbbbbbdbo.",
            ".odddddlldddddo.",
            "..obbbbbbbbbbo..",
            "..obbbbbbbbbbo..",
            "..oobbbbbbbboo..",
            "...obbbbbbbbo...",
            "...obbbbbbbbo...",
            "....obbbbbbo....",
            "....obbbbbbo....",
            "....oobbbboo....",
            ".....oobboo.....",
        ],
        "b_legs_stand": [
            "...obbbo..obbbo...",
            "...oblbo..oblbo...",
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
        ],
        "b_legs_a": [
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
        ],
        # ---- PIT RAT (dart) 14x24: all-fours crawler, helmet-first lunger.
        "d_body": [
            "......oooo..",
            ".....obbbbo.",
            "....obbbbleo",
            "...obbboooo.",
            "..obbbbdeo..",
            ".obbbbbbo...",
            "obbbbbbbo...",
            "obdbbbbo....",
            ".obbbbbo....",
            ".odbbbo.....",
            "..oooo......",
        ],
        "d_legs_stand": [
            ".obo....obo.",
            ".obo....obo.",
            ".obo....obo.",
            ".obo....obo.",
            "obbo...obbo.",
            "oooo...oooo.",
        ],
        "d_legs_a": [
            "obo......obo",
            "obo......obo",
            "obo......obo",
            "obo......obo",
            "bbo......obb",
            "ooo......ooo",
        ],
        "d_legs_tuck": [
            "..obo..obo..",
            "..obo..obo..",
            "..oo....oo..",
            "............",
            "............",
            "............",
        ],
        # ---- CANARY (gnat) 16x20: skeletal cage bird, hole-torn wings.
        "n_body": [
            "..oooo..",
            ".obbbbo.",
            "obbbeblo",
            "obdbbllo",
            "odbbbbo.",
            ".obbbbo.",
            "..o..o..",
            "..o..o..",
        ],
        "n_wings_up": [
            ".oo......oo.",
            "obbo....obbo",
            "ob.bo..ob.bo",
            ".obbo..obbo.",
            "..oo....oo..",
        ],
        "n_wings_down": [
            "oooo....oooo",
            "ob.bo..ob.bo",
            ".ooo....ooo.",
        ],
        "n_wings_back": [
            "ooo.........",
            "ob.o........",
            "obbbo.......",
            ".ooo........",
        ],
        # ---- POWDER-MONKEY (slinger) 20x36: cap, bandolier of charges.
        "s_head": [
            "..oooooo..",
            ".obbbbbblo",
            "obbbbbbleo",
            "oddddddddo",
            ".odeobeodo",
            ".oddbbddo.",
            "..oboo....",
        ],
        "s_body": [
            "..oobbbboo..",
            ".obbbbbbdbo.",
            ".obbbbbldbo.",
            "obbbbbdbbbbo",
            "obbbldbbbbbo",
            "obbbdbbbbbbo",
            "obdlbbbbbbbo",
            ".obbbbbbbbo.",
            ".obbbbbbbbo.",
            ".obbbbbbbo..",
            "oddobbbbbo..",
            "odddobbbbo..",
            "oddobbbbo...",
            ".oobbbbo....",
            "..obbbbo....",
        ],
        "s_legs_stand": [
            "..obbbbo..",
            "..obbbbo..",
            ".obo..obo.",
            ".obo..obo.",
            ".obo..obo.",
            ".obo..obo.",
            ".obo..obo.",
            "obbo..obbo",
            "obbo..obbo",
            "oooo..oooo",
        ],
        "s_legs_a": [
            "..obbbbo..",
            "..obbbbo..",
            ".obo..obo.",
            "obo....obo",
            "obo....obo",
            "obo....obo",
            "obo....obo",
            "obbo..obbo",
            "obbo..obbo",
            "oooo..oooo",
        ],
        # ---- VAROK (overseer) 34x52: crested helm, visor-slit eyes, chain.
        "v_head": [
            "......oooo......",
            ".....odbbdo.....",
            "..ooodbbbbooo...",
            ".obbbbbbbbbbbbo.",
            ".obbbbbbbbbbbbo.",
            ".oddddddddddddo.",
            ".odbeobbbbeobdo.",
            ".obbbbbbbbbbbbo.",
            "..obdddddddbo...",
            "...oobbbbboo....",
        ],
        "v_body": [
            ".ooooobbbbbbbbbbooooo.",
            ".obllbbbbbbbbbbbbllbo.",
            "obbblbbbbbbbbbbbbbbbbo",
            "obdbbblbbbbbbbbbbbbdbo",
            "obdbbdddlddddddbbbbdbo",
            "obdbbdbbbblbbbdbbbbdbo",
            "obdbbdbbbbbblbdbbbbdbo",
            "obdbbdbbbbbbbbldbbbdbo",
            "obdbbdddddddddddlbbdbo",
            ".obbbbbbbbbbbbbbbbbbo.",
            ".obbbbbbbbbbbbbbbbbbo.",
            ".obdbbbbbbbbbbbbbbdbo.",
            ".oddddddddllddddddddo.",
            "..obbbbbbbbbbbbbbbbo..",
            "..obbbbbbbbbbbbbbbbo..",
            "..obdbbbbbbbbbbbbdbo..",
            "...obbbbbbbbbbbbbbo...",
            "...obbbbbbbbbbbbbbo...",
            "....obbbbbbbbbbbbo....",
            "....obbbbbbbbbbbbo....",
            ".....obbbbbbbbbbo.....",
            ".....obbbbbbbbbbo.....",
            "......obbo..obbo......",
            ".......oobo.obo.......",
        ],
        "v_legs_stand": [
            "...obbbbo....obbbbo...",
            "...obbbbo....obbbbo...",
            "...obbbbo....obbbbo...",
            "...obbbbo....obbbbo...",
            "...obbbbo....obbbbo...",
            "...obbbbo....obbbbo...",
            "...oblbbo....oblbbo...",
            "...oblbbo....oblbbo...",
            "..obbbbbo....obbbbbo..",
            "..obbbbbo....obbbbbo..",
            "..obbbbbo....obbbbbo..",
            "..obbbbbo....obbbbbo..",
            ".obbbbbbo....obbbbbbo.",
            ".obbbbbbo....obbbbbbo.",
            ".obbbbbbo....obbbbbbo.",
            ".obbbbbbo....obbbbbbo.",
            ".oooooooo....oooooooo.",
            ".oooooooo....oooooooo.",
        ],
        "v_legs_a": [
            "...obbbbo....obbbbo...",
            "..obbbbo......obbbbo..",
            "..obbbbo......obbbbo..",
            ".obbbbo........obbbbo.",
            ".obbbbo........obbbbo.",
            ".obbbbo........obbbbo.",
            ".oblbbo........oblbbo.",
            ".oblbbo........oblbbo.",
            "obbbbbo........obbbbbo",
            "obbbbbo........obbbbbo",
            "obbbbbo........obbbbbo",
            "obbbbbo........obbbbbo",
            "obbbbbbo......obbbbbbo",
            "obbbbbbo......obbbbbbo",
            "obbbbbbo......obbbbbbo",
            "obbbbbbo......obbbbbbo",
            "oooooooo......oooooooo",
            "......................",
        ],
    },
    "specs": {
        "g_arm_rest": [
            (15, 0, "ood"), (16, 0, "obbd"), (17, 0, "obbd"), (18, 0, "obbd"),
            (19, 0, "obbo"), (20, 1, "oo"),
            (17, 4, "l"), (18, 4, "l"), (19, 4, "l"), (20, 4, "l"),
            (21, 4, "l"), (22, 5, "l"),
        ],
        "g_arm_back": [
            (11, 0, "ood"), (12, 0, "obbd"), (13, 0, "obbd"),
            (14, 0, "obbo"), (15, 1, "oo"),
            (9, 1, "l"), (10, 1, "l"),
        ],
        "g_arm_swing": [
            (15, 12, "doo"), (16, 11, "dbbo"), (17, 11, "dbbo"), (18, 12, "dobo"),
            (15, 15, "ll"), (14, 16, "ll"),
        ],
        "b_arm_rest": [
            (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 0, "obbd"),
            (18, 0, "obbd"), (19, 0, "obbo"), (20, 1, "oo"),
            (14, 23, "doo"), (15, 22, "dbbo"), (16, 22, "dbbo"), (17, 22, "dbbo"),
            (18, 22, "dbbo"), (19, 22, "obbo"), (20, 23, "oo"),
        ],
        "b_arm_high": [
            (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 1, "ooo"),
            (0, 19, "oooo"), (1, 18, "obbbbo"), (2, 18, "obbbbo"), (3, 19, "oooo"),
            (4, 19, "obo"), (5, 19, "obo"), (6, 20, "obo"), (7, 20, "obo"),
            (8, 20, "obo"), (9, 20, "obo"), (10, 20, "obo"), (11, 20, "obo"),
            (12, 20, "obo"), (13, 21, "oo"),
        ],
        "b_arm_down": [
            (14, 0, "ood"), (15, 0, "obbd"), (16, 0, "obbd"), (17, 1, "ooo"),
            (18, 20, "ob"), (19, 20, "obo"), (20, 20, "obo"), (21, 20, "obo"),
            (22, 20, "obo"), (23, 20, "obo"), (24, 20, "obo"), (25, 20, "obo"),
            (26, 20, "obo"), (27, 20, "obo"), (28, 20, "obo"), (29, 20, "obo"),
            (30, 19, "obo"), (31, 19, "obo"), (32, 19, "obo"), (33, 19, "obo"),
            (34, 19, "obo"), (35, 19, "obo"),
            (36, 19, "oooo"), (37, 18, "obbbbo"), (38, 18, "obbbbo"), (39, 19, "oooo"),
        ],
        "b_chain": [
            (23, 18, "l"), (24, 18, "o"), (25, 18, "l"), (26, 18, "o"),
            (27, 17, "l"),
        ],
        "s_arm_rest": [
            (13, 14, "oo"), (14, 14, "obo"), (15, 14, "obo"), (16, 14, "obo"),
            (17, 15, "oo"), (18, 14, "d.d"), (19, 14, "d.d"),
        ],
        "s_arm_wind": [
            (3, 2, "ooo"), (4, 1, "olelo"), (5, 1, "olllo"), (6, 2, "ooo"),
            (7, 3, "obo"), (8, 3, "obo"), (9, 4, "obo"), (10, 5, "obo"),
            (11, 6, "obo"), (12, 7, "obo"),
        ],
        "s_arm_throw": [
            (12, 14, "oo"), (13, 14, "oboo"), (14, 15, "obbo"), (15, 16, "oboo"),
            (16, 17, "oo"), (13, 18, "d"), (14, 18, "d"),
        ],
        "v_arm_rest": [
            (13, 2, "oodd"), (14, 1, "obbdd"), (15, 1, "obbdd"), (16, 1, "obbdd"),
            (17, 1, "obbdd"), (18, 1, "obbdd"), (19, 1, "obbbd"), (20, 1, "obbbo"),
            (21, 1, "obbbo"), (22, 2, "ooo"),
            (13, 28, "ddoo"), (14, 28, "ddbbo"), (15, 28, "ddbbo"), (16, 28, "ddbbo"),
            (17, 28, "ddbbo"), (18, 28, "ddbbo"), (19, 28, "dbbbo"), (20, 28, "obbbo"),
            (21, 28, "obbbo"), (22, 29, "ooo"),
        ],
        "v_arm_high": [
            (0, 3, "oooo"), (1, 2, "obbbbo"), (2, 2, "obbbbo"), (3, 3, "oooo"),
            (4, 4, "obo"), (5, 4, "obo"), (6, 5, "obo"), (7, 5, "obo"), (8, 6, "obo"),
            (9, 6, "obo"), (10, 6, "obo"), (11, 7, "obo"), (12, 7, "oo"),
            (0, 27, "oooo"), (1, 26, "obbbbo"), (2, 26, "obbbbo"), (3, 27, "oooo"),
            (4, 27, "obo"), (5, 27, "obo"), (6, 26, "obo"), (7, 26, "obo"), (8, 25, "obo"),
            (9, 25, "obo"), (10, 25, "obo"), (11, 24, "obo"), (12, 24, "oo"),
        ],
        "v_arm_down": [
            (13, 2, "ood"), (14, 1, "obbd"), (15, 1, "obbd"), (16, 2, "ooo"),
            (18, 26, "obo"), (19, 26, "obo"), (20, 26, "obo"), (21, 26, "obo"),
            (22, 27, "obo"), (23, 27, "obo"), (24, 27, "obo"), (25, 27, "obo"),
            (26, 27, "obo"), (27, 27, "obo"), (28, 27, "obo"), (29, 27, "obo"),
            (30, 27, "obo"), (31, 27, "obo"), (32, 27, "obo"), (33, 27, "obo"),
            (34, 27, "obo"), (35, 27, "obo"), (36, 26, "obo"), (37, 26, "obo"),
            (38, 26, "obo"), (39, 26, "obo"), (40, 27, "obo"), (41, 27, "obo"),
            (42, 27, "obo"), (43, 27, "obo"),
            (44, 28, "oooo"), (45, 27, "obbbbo"), (46, 27, "obbbbo"), (47, 28, "oooo"),
        ],
        "v_lantern": [
            (22, 27, "o"), (23, 27, "o"), (24, 26, "ooo"), (25, 26, "oeo"),
            (26, 26, "ooo"),
        ],
    },
    "sheets": {
        "grunt": {
            "size": (18, 32),
            "frames": {
                "idle": [
                    [("g_head", 4, 3), ("g_body", 12, 3), ("g_legs_stand", 24, 3), ("@g_arm_rest", 0, 0)],
                    [("g_head", 5, 3), ("g_body", 13, 3), ("g_legs_stand", 24, 3), ("@g_arm_rest", 1, 0)],
                ],
                "chase": [
                    [("g_head", 4, 3), ("g_body", 12, 3), ("g_legs_a", 24, 3), ("@g_arm_rest", 0, 0)],
                    [("g_head", 5, 3), ("g_body", 13, 3), ("g_legs_b", 24, 3), ("@g_arm_rest", 1, 0)],
                    [("g_head", 4, 3), ("g_body", 12, 3), ("g_legs_a", 24, 3), ("@g_arm_rest", 0, 0)],
                    [("g_head", 5, 3), ("g_body", 13, 3), ("g_legs_b", 24, 3), ("@g_arm_rest", 1, 0)],
                ],
                "telegraph": [
                    [("g_head", 3, 3), ("g_body", 12, 3), ("g_legs_stand", 24, 3), ("@g_arm_back", 0, 0)],
                    [("g_head", 2, 3), ("g_body", 12, 3), ("g_legs_stand", 24, 3), ("@g_arm_back", -1, 0)],
                ],
                "attack": [
                    [("g_head", 5, 3), ("g_body", 13, 3), ("g_legs_stand", 24, 3), ("@g_arm_swing", 1, 0)],
                    [("g_head", 6, 3), ("g_body", 14, 3), ("g_legs_stand", 24, 3), ("@g_arm_swing", 2, 0)],
                ],
                "recover": [
                    [("g_head", 6, 3), ("g_body", 14, 3), ("g_legs_stand", 24, 3), ("@g_arm_rest", 2, 0)],
                ],
                "hurt": [
                    [("g_head", 7, 3), ("g_body", 14, 3), ("g_legs_stand", 24, 3), ("@g_arm_back", 2, 0)],
                ],
                "stagger": [
                    [("g_head", 9, 3), ("g_body", 15, 3), ("g_legs_b", 24, 3), ("@g_arm_back", 3, 0)],
                ],
                "dead": [
                    [("g_head", 12, 3), ("g_body", 17, 3), ("g_legs_b", 24, 3), ("@g_arm_rest", 5, 0)],
                ],
            },
        },
        "brute": {
            "size": (26, 44),
            "frames": {
                "idle": [
                    [("@b_arm_rest", 0, 0), ("b_head", 2, 6), ("b_body", 10, 5), ("b_legs_stand", 32, 4), ("@b_chain", 0, 0)],
                    [("@b_arm_rest", 1, 0), ("b_head", 3, 6), ("b_body", 11, 5), ("b_legs_stand", 32, 4), ("@b_chain", 1, 0)],
                ],
                "chase": [
                    [("@b_arm_rest", 0, 0), ("b_head", 2, 6), ("b_body", 10, 5), ("b_legs_a", 32, 4), ("@b_chain", 0, 1)],
                    [("@b_arm_rest", 1, 0), ("b_head", 3, 6), ("b_body", 11, 5), ("b_legs_stand", 32, 4), ("@b_chain", 1, 0)],
                    [("@b_arm_rest", 0, 0), ("b_head", 2, 6), ("b_body", 10, 5), ("b_legs_a", 32, 4), ("@b_chain", 0, 1)],
                    [("@b_arm_rest", 1, 0), ("b_head", 3, 6), ("b_body", 11, 5), ("b_legs_stand", 32, 4), ("@b_chain", 1, 0)],
                ],
                "telegraph": [
                    [("@b_arm_high", 0, 0), ("b_head", 2, 6), ("b_body", 10, 5), ("b_legs_stand", 32, 4), ("@b_chain", 0, 0)],
                    [("@b_arm_high", -1, 0), ("b_head", 1, 6), ("b_body", 9, 5), ("b_legs_stand", 32, 4), ("@b_chain", -1, 0)],
                ],
                "attack": [
                    [("b_head", 3, 6), ("b_body", 11, 5), ("b_legs_stand", 32, 4), ("@b_arm_down", 1, 0), ("@b_chain", 1, 1)],
                    [("b_head", 4, 6), ("b_body", 12, 5), ("b_legs_stand", 32, 4), ("@b_arm_down", 2, 0), ("@b_chain", 2, 1)],
                ],
                "recover": [
                    [("@b_arm_rest", 2, 0), ("b_head", 4, 6), ("b_body", 12, 5), ("b_legs_stand", 32, 4), ("@b_chain", 2, 0)],
                ],
                "hurt": [
                    [("@b_arm_rest", 2, 0), ("b_head", 4, 6), ("b_body", 12, 5), ("b_legs_stand", 32, 4), ("@b_chain", 2, 0)],
                ],
                "stagger": [
                    [("@b_arm_rest", 4, 0), ("b_head", 6, 6), ("b_body", 14, 5), ("b_legs_a", 32, 4), ("@b_chain", 4, 0)],
                ],
                "dead": [
                    [("@b_arm_rest", 6, 0), ("b_head", 8, 6), ("b_body", 16, 5), ("b_legs_a", 32, 4), ("@b_chain", 6, 0)],
                ],
            },
        },
        "dart": {
            "size": (14, 24),
            "frames": {
                "idle": [
                    [("d_body", 7, 1), ("d_legs_stand", 18, 1)],
                    [("d_body", 8, 1), ("d_legs_stand", 18, 1)],
                ],
                "chase": [
                    [("d_body", 7, 1), ("d_legs_a", 18, 1)],
                    [("d_body", 8, 1), ("d_legs_stand", 18, 1)],
                    [("d_body", 7, 1), ("d_legs_a", 18, 1)],
                    [("d_body", 8, 1), ("d_legs_stand", 18, 1)],
                ],
                "telegraph": [
                    [("d_body", 9, 1), ("d_legs_tuck", 19, 1)],
                    [("d_body", 10, 1), ("d_legs_tuck", 20, 1)],
                ],
                "attack": [
                    [("d_body", 5, 1), ("d_legs_tuck", 16, 1)],
                    [("d_body", 4, 1), ("d_legs_tuck", 15, 1)],
                ],
                "recover": [
                    [("d_body", 8, 1), ("d_legs_stand", 18, 1)],
                ],
                "hurt": [
                    [("d_body", 9, 1), ("d_legs_tuck", 19, 1)],
                ],
                "stagger": [
                    [("d_body", 10, 1), ("d_legs_tuck", 20, 1)],
                ],
                "dead": [
                    [("d_body", 13, 1), ("d_legs_a", 18, 1)],
                ],
            },
        },
        "gnat": {
            "size": (16, 20),
            "frames": {
                "idle": [
                    [("n_wings_up", 4, 2), ("n_body", 8, 4)],
                    [("n_wings_down", 8, 2), ("n_body", 9, 4)],
                ],
                "chase": [
                    [("n_wings_up", 4, 2), ("n_body", 8, 4)],
                    [("n_wings_down", 8, 2), ("n_body", 9, 4)],
                    [("n_wings_up", 4, 2), ("n_body", 8, 4)],
                    [("n_wings_down", 8, 2), ("n_body", 9, 4)],
                ],
                "telegraph": [
                    [("n_wings_back", 6, 2), ("n_body", 7, 4)],
                    [("n_wings_back", 5, 2), ("n_body", 6, 4)],
                ],
                "attack": [
                    [("n_wings_back", 9, 2), ("n_body", 11, 4)],
                    [("n_wings_back", 10, 2), ("n_body", 12, 4)],
                ],
                "recover": [
                    [("n_wings_down", 8, 2), ("n_body", 9, 4)],
                ],
                "hurt": [
                    [("n_wings_back", 7, 2), ("n_body", 9, 4)],
                ],
                "stagger": [
                    [("n_body", 10, 4), ("n_wings_down", 14, 2)],
                ],
                "dead": [
                    [("n_body", 12, 4), ("n_wings_back", 15, 2)],
                ],
            },
        },
        "slinger": {
            "size": (20, 36),
            "frames": {
                "idle": [
                    [("@s_arm_rest", 0, 0), ("s_head", 4, 5), ("s_body", 11, 4), ("s_legs_stand", 26, 5)],
                    [("@s_arm_rest", 1, 0), ("s_head", 5, 5), ("s_body", 12, 4), ("s_legs_stand", 26, 5)],
                ],
                "chase": [
                    [("@s_arm_rest", 0, 0), ("s_head", 4, 5), ("s_body", 11, 4), ("s_legs_a", 26, 5)],
                    [("@s_arm_rest", 1, 0), ("s_head", 5, 5), ("s_body", 12, 4), ("s_legs_stand", 26, 5)],
                    [("@s_arm_rest", 0, 0), ("s_head", 4, 5), ("s_body", 11, 4), ("s_legs_a", 26, 5)],
                    [("@s_arm_rest", 1, 0), ("s_head", 5, 5), ("s_body", 12, 4), ("s_legs_stand", 26, 5)],
                ],
                "telegraph": [
                    [("@s_arm_wind", 0, 0), ("s_head", 4, 5), ("s_body", 11, 4), ("s_legs_stand", 26, 5)],
                    [("@s_arm_wind", -1, 0), ("s_head", 3, 5), ("s_body", 11, 4), ("s_legs_stand", 26, 5)],
                ],
                "attack": [
                    [("s_head", 5, 5), ("s_body", 12, 4), ("s_legs_stand", 26, 5), ("@s_arm_throw", 1, 0)],
                    [("s_head", 6, 5), ("s_body", 13, 4), ("s_legs_stand", 26, 5), ("@s_arm_throw", 2, 0)],
                ],
                "recover": [
                    [("@s_arm_rest", 2, 0), ("s_head", 6, 5), ("s_body", 13, 4), ("s_legs_stand", 26, 5)],
                ],
                "hurt": [
                    [("@s_arm_rest", 2, 0), ("s_head", 7, 5), ("s_body", 13, 4), ("s_legs_stand", 26, 5)],
                ],
                "stagger": [
                    [("@s_arm_rest", 3, 0), ("s_head", 8, 5), ("s_body", 14, 4), ("s_legs_a", 26, 5)],
                ],
                "dead": [
                    [("@s_arm_rest", 6, 0), ("s_head", 11, 5), ("s_body", 17, 4), ("s_legs_a", 26, 5)],
                ],
            },
        },
        "overseer": {
            "size": (34, 52),
            "frames": {
                "idle": [
                    [("@v_arm_rest", 0, 0), ("v_head", 0, 9), ("v_body", 10, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 0, 0)],
                    [("@v_arm_rest", 1, 0), ("v_head", 1, 9), ("v_body", 11, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 1, 0)],
                ],
                "chase": [
                    [("@v_arm_rest", 0, 0), ("v_head", 0, 9), ("v_body", 10, 6), ("v_legs_a", 34, 6), ("@v_lantern", 0, 1)],
                    [("@v_arm_rest", 1, 0), ("v_head", 1, 9), ("v_body", 11, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 1, 0)],
                    [("@v_arm_rest", 0, 0), ("v_head", 0, 9), ("v_body", 10, 6), ("v_legs_a", 34, 6), ("@v_lantern", 0, 1)],
                    [("@v_arm_rest", 1, 0), ("v_head", 1, 9), ("v_body", 11, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 1, 0)],
                ],
                "telegraph": [
                    [("@v_arm_high", 1, 0), ("v_head", 1, 9), ("v_body", 11, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 1, 0)],
                    [("@v_arm_high", 0, 0), ("v_head", 0, 9), ("v_body", 10, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 0, 0)],
                ],
                "attack": [
                    [("v_head", 2, 9), ("v_body", 12, 6), ("v_legs_stand", 34, 6), ("@v_arm_down", 1, 0), ("@v_lantern", 2, 0)],
                    [("v_head", 3, 9), ("v_body", 13, 6), ("v_legs_stand", 34, 6), ("@v_arm_down", 2, 0), ("@v_lantern", 3, 0)],
                ],
                "recover": [
                    [("@v_arm_rest", 2, 0), ("v_head", 2, 9), ("v_body", 12, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 2, 0)],
                ],
                "hurt": [
                    [("@v_arm_rest", 1, 0), ("v_head", 1, 9), ("v_body", 11, 6), ("v_legs_stand", 34, 6), ("@v_lantern", 1, 0)],
                ],
                "stagger": [
                    [("@v_arm_rest", 4, 0), ("v_head", 4, 9), ("v_body", 14, 6), ("v_legs_a", 34, 6), ("@v_lantern", 4, 0)],
                ],
                "dead": [
                    [("@v_arm_rest", 8, 0), ("v_head", 8, 9), ("v_body", 18, 6), ("v_legs_a", 34, 6), ("@v_lantern", 8, 0)],
                ],
            },
        },
    },
}
# === END DATA ===


def _compose(size, layers):
    w, h = size
    g = [["." for _ in range(w)] for _ in range(h)]
    for name, top, dx in layers:
        if name.startswith("@"):
            for r, c, chunk in DATA["specs"][name[1:]]:
                for i, ch in enumerate(chunk):
                    if ch != "." and 0 <= r + top < h and 0 <= c + dx + i < w:
                        g[r + top][c + dx + i] = ch
        else:
            for y, row in enumerate(DATA["parts"][name]):
                for x, ch in enumerate(row):
                    if ch != "." and 0 <= top + y < h and 0 <= x + dx < w:
                        g[top + y][x + dx] = ch
    return ["".join(r) for r in g]


PALETTE = {k: tuple(v) for k, v in DATA["palette"].items()}

# gen_sprites iterates this: every sheet bakes to <name>.png + <name>.json,
# greyscale-shaded so the BodyJuice tints multiply cleanly.
SHEETS = {
    sheet: {
        "size": tuple(spec["size"]),
        "palette": PALETTE,
        "frames": {
            anim: [_compose(spec["size"], frame) for frame in frame_list]
            for anim, frame_list in spec["frames"].items()
        },
        "shade": {"greyscale": True},
    }
    for sheet, spec in DATA["sheets"].items()
}
