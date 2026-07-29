#!/usr/bin/env python3
"""The PAYDIRT app icon: a dark rounded plate with the game's amber border and
a faceted gold nugget — the KeyChip / HUD-card visual language, so the desktop
icon looks like the game it launches. Drawn at 64 px and scaled x4 nearest to
256 (crisp pixel edges, matching the sprite bake).

Deterministic, no dependencies (hand-written PNG like gen_sprites.py).
Run: python3 tools/gen_icon.py   ->  icon.png (project root)
"""
import struct
import zlib

SIZE = 64
SCALE = 4

BG = (13, 10, 8, 255)          # dark plate (KeyChip FILL, slightly warm)
BORDER = (255, 209, 102, 255)  # amber (KeyChip BORDER)
GOLD = (219, 158, 56, 255)     # nugget body (tileset ORE)
GOLD_LIT = (255, 209, 107, 255)
GOLD_DARK = (140, 95, 36, 255)
RIM = (97, 66, 31, 255)        # ore-seam rim, grounds the nugget on the plate
GLINT = (255, 244, 214, 255)


def in_round_rect(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 1


def in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


# The nugget: a chunky irregular hexagon, then facet polys carve light and
# shadow into it — same upper-left warm light as the whole art set.
NUGGET = [(32, 16), (45, 22), (48, 34), (41, 47), (25, 48), (17, 36), (20, 23)]
FACET_LIT = [(32, 16), (45, 22), (34, 33), (20, 23)]
FACET_DARK = [(48, 34), (41, 47), (25, 48), (33, 34)]


def colour_at(x, y):
    # cell centre sampling
    px, py = x + 0.5, y + 0.5
    if not in_round_rect(px, py, 2, 2, 62, 62, 11):
        return (0, 0, 0, 0)
    if not in_round_rect(px, py, 5, 5, 59, 59, 8):
        return BORDER
    # rim first so the nugget reads seated, not pasted
    if in_poly(px, py, [(p[0] * 1.06 - 32 * 0.06, p[1] * 1.06 - 34 * 0.06) for p in NUGGET]):
        base = RIM
    else:
        return BG
    if in_poly(px, py, NUGGET):
        base = GOLD
        if in_poly(px, py, FACET_LIT):
            base = GOLD_LIT
        elif in_poly(px, py, FACET_DARK):
            base = GOLD_DARK
        # a two-pixel glint on the lit shoulder
        if 26 <= px <= 29 and 20 <= py <= 22:
            base = GLINT
    return base


def write_png(path, size, rows):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def main():
    small = [[colour_at(x, y) for x in range(SIZE)] for y in range(SIZE)]
    big = [[small[y // SCALE][x // SCALE] for x in range(SIZE * SCALE)] for y in range(SIZE * SCALE)]
    write_png("icon.png", SIZE * SCALE, big)
    print("icon.png  %dx%d" % (SIZE * SCALE, SIZE * SCALE))


if __name__ == "__main__":
    main()
