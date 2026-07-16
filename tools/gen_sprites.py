#!/usr/bin/env python3
"""Bake the ASCII sprite frames into a PNG sheet.

Run: python3 tools/gen_sprites.py

Writes assets/sprites/player.png as a horizontal strip, one row per animation,
plus a .json manifest so the Godot side knows which frames belong to which
animation without hard-coding indices in two places.

Validates first and refuses to write a broken sheet — same discipline as the
room generator, and for the same reason: a wrong-width row would become a
silently sheared sprite, which is the kind of bug you only find by looking.

No dependencies. Writes the PNG by hand (zlib + struct) rather than pulling in
Pillow, so this runs on any machine with python3 and nothing else.
"""

import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "sprites"))
import player_frames  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")


def validate(name, frames, w, h, palette):
    errors = []
    for i, frame in enumerate(frames):
        if len(frame) != h:
            errors.append(f"{name}[{i}]: {len(frame)} rows, expected {h}")
            continue
        for y, row in enumerate(frame):
            if len(row) != w:
                errors.append(f"{name}[{i}] row {y}: width {len(row)}, expected {w}")
            for x, ch in enumerate(row):
                if ch not in palette:
                    errors.append(f"{name}[{i}] row {y} col {x}: '{ch}' is not in the palette")
    return errors


def write_png(path, width, height, pixels):
    """pixels: list of rows, each a list of (r,g,b,a)."""
    raw = b""
    for row in pixels:
        raw += b"\x00"  # filter type 0
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
    mod = player_frames
    w, h, palette = mod.W, mod.H, mod.PALETTE
    frames = mod.FRAMES

    errors = []
    for name, group in frames.items():
        errors += validate(name, group, w, h, palette)
    if errors:
        print("INVALID — refusing to write a broken sheet:")
        for e in errors:
            print("  " + e)
        return 1

    # One row per animation; columns are frames. Keeps the sheet readable if you
    # ever open it, and makes the manifest trivial.
    names = list(frames.keys())
    cols = max(len(g) for g in frames.values())
    rows = len(names)
    sheet_w, sheet_h = cols * w, rows * h

    canvas = [[(0, 0, 0, 0)] * sheet_w for _ in range(sheet_h)]
    manifest = {"frame_size": [w, h], "animations": {}}

    for r, name in enumerate(names):
        group = frames[name]
        manifest["animations"][name] = {"row": r, "count": len(group)}
        for c, frame in enumerate(group):
            for y, line in enumerate(frame):
                for x, ch in enumerate(line):
                    canvas[r * h + y][c * w + x] = palette[ch]

    os.makedirs(OUT_DIR, exist_ok=True)
    png_path = os.path.join(OUT_DIR, "player.png")
    write_png(png_path, sheet_w, sheet_h, canvas)
    with open(os.path.join(OUT_DIR, "player.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"player.png  {sheet_w}x{sheet_h}  ({rows} animations, up to {cols} frames each)")
    for name in names:
        print(f"  {name:8s} {len(frames[name])} frame(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
