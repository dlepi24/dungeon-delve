#!/usr/bin/env python3
"""Bake the ASCII icon art into PNGs.

Run: python3 tools/gen_icons.py

Writes one 16x16 PNG per icon into assets/icons/. Crude pixel art on purpose —
readable at HUD size, unmistakably placeholder, replaced at M9 like the rest of
the art. Same discipline as gen_sprites.py: ASCII here is the source of truth,
validation refuses to bake a broken sheet, and the PNG is written by hand
(zlib + struct) so nothing beyond python3 is needed.

Icons are used by the HUD (weapon squares, ore counter, health) and referenced
from WeaponData resources, so a new weapon's icon is: draw it here, bake, point
the .tres at it.
"""

import os
import struct
import sys
import zlib

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")

# Shared palette. '.' is transparent everywhere.
PALETTE = {
    ".": (0, 0, 0, 0),
    "h": (139, 90, 43, 255),     # wood handle
    "H": (170, 115, 60, 255),    # wood highlight
    "m": (184, 196, 204, 255),   # steel
    "d": (96, 104, 112, 255),    # dark steel / outline
    "g": (212, 175, 55, 255),    # gold guard
    "b": (205, 255, 230, 255),   # dagger pale steel (matches swing colour)
    "i": (120, 110, 130, 255),   # maul dark iron
    "I": (160, 148, 170, 255),   # maul iron highlight
    "p": (255, 210, 140, 255),   # spear bright point (matches swing colour)
    "a": (242, 179, 64, 255),    # ore amber
    "A": (255, 217, 90, 255),    # ore bright amber
    "r": (232, 58, 74, 255),     # heart red
    "R": (255, 130, 140, 255),   # heart highlight
}

# 16x16 each. Weapons point UP so they read as "a weapon" in a square slot.
ICONS = {
    "pickaxe": [
        "...mmmmmmmmmm...",
        "..mm...HH...mm..",
        ".mm....hh....mm.",
        ".m.....hh.....m.",
        "m......hh......m",
        "m......hh......m",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        "................",
    ],
    "dagger": [
        "................",
        ".......bb.......",
        "......bbbb......",
        "......bbbb......",
        "......bbbb......",
        "......bbbb......",
        "......bbbb......",
        ".......bb.......",
        "....gggggggg....",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        "......hHHh......",
        "................",
        "................",
        "................",
    ],
    "maul": [
        "..dddddddddddd..",
        ".diiiiIIIIiiiid.",
        ".diiiiIIIIiiiid.",
        ".diiiiiiiiiiiid.",
        ".diiiiiiiiiiiid.",
        "..dddddddddddd..",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        "......hHHh......",
        "................",
    ],
    "spear": [
        ".......pp.......",
        "......pppp......",
        "......pppp......",
        "......pppp......",
        ".......pp.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
        ".......hh.......",
    ],
    "ore": [
        "................",
        "................",
        "......aa........",
        ".....aaaa.......",
        "....aaAAaa......",
        "...aaAAAAaa.....",
        "..aaAAAAAAaa....",
        "..aaAAAAAAaa....",
        "..aaaAAAAaaa....",
        "...aaaaaaaa.....",
        "....aaaaaa......",
        ".....aaaa.......",
        "................",
        "................",
        "................",
        "................",
    ],
    "heart": [
        "................",
        "................",
        "..rrr....rrr....",
        ".rRrrr..rrrrr...",
        ".rRrrrrrrrrrr...",
        ".rrrrrrrrrrrr...",
        ".rrrrrrrrrrrr...",
        "..rrrrrrrrrr....",
        "...rrrrrrrr.....",
        "....rrrrrr......",
        ".....rrrr.......",
        "......rr........",
        "................",
        "................",
        "................",
        "................",
    ],
}

SIZE = 16


def validate():
    errors = []
    for name, rows in ICONS.items():
        if len(rows) != SIZE:
            errors.append(f"{name}: {len(rows)} rows, expected {SIZE}")
            continue
        for y, row in enumerate(rows):
            if len(row) != SIZE:
                errors.append(f"{name} row {y}: width {len(row)}, expected {SIZE}")
            for x, ch in enumerate(row):
                if ch not in PALETTE:
                    errors.append(f"{name} row {y} col {x}: '{ch}' not in palette")
    return errors


def write_png(path, width, height, pixels):
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for (r, g, b, a) in row:
            raw += struct.pack("BBBB", r, g, b, a)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    errors = validate()
    if errors:
        print("INVALID icons — refusing to bake:")
        for e in errors:
            print("  " + e)
        return 1
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, rows in ICONS.items():
        pixels = [[PALETTE[ch] for ch in row] for row in rows]
        path = os.path.join(OUT_DIR, f"{name}.png")
        write_png(path, SIZE, SIZE, pixels)
        print(f"  {name}.png")
    print(f"OK — {len(ICONS)} icon(s) into {os.path.relpath(OUT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
