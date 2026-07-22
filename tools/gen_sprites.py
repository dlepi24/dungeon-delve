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
import enemy_frames  # noqa: E402
import weapon_frames  # noqa: E402
import object_frames  # noqa: E402
import building_frames  # noqa: E402
import shade_pass  # noqa: E402

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


def bake(sheet_name, w, h, palette, frames, shade=None, anchors=None):
    """shade: None for flat colours, or a dict of shade_pass options —
    {"greyscale": bool, "lamp": "l"}. Shading happens at bake time only;
    the ASCII source and its palette stay exactly as authored."""
    errors = []
    for name, group in frames.items():
        errors += validate(f"{sheet_name}.{name}", group, w, h, palette)
    if errors:
        print(f"INVALID {sheet_name} — refusing to write a broken sheet:")
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
    if anchors:
        # Stage-2 weapon-layer contract: per-frame hand anchor, weapon angle
        # and visibility. Ignored by PlayerSprite today; WeaponSprite reads it.
        manifest["anchors"] = anchors

    for r, name in enumerate(names):
        group = frames[name]
        manifest["animations"][name] = {"row": r, "count": len(group)}
        for c, frame in enumerate(group):
            if shade is not None:
                shaded = shade_pass.shade_frame(
                    frame, palette,
                    greyscale=shade.get("greyscale", False),
                    lamp_ch=shade.get("lamp"))
                for y in range(h):
                    for x in range(w):
                        canvas[r * h + y][c * w + x] = shaded[y][x]
            else:
                for y, line in enumerate(frame):
                    for x, ch in enumerate(line):
                        canvas[r * h + y][c * w + x] = palette[ch]

    os.makedirs(OUT_DIR, exist_ok=True)
    write_png(os.path.join(OUT_DIR, f"{sheet_name}.png"), sheet_w, sheet_h, canvas)
    with open(os.path.join(OUT_DIR, f"{sheet_name}.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"{sheet_name}.png  {sheet_w}x{sheet_h}  ({rows} animations, up to {cols} frames each)")
    for name in names:
        print(f"    {name:10s} {len(frames[name])} frame(s)")
    return 0


def bake_weapons():
    """Weapon layer (stage 2): one 24x24 tile per weapon in a horizontal
    strip, plus a manifest mapping name -> sheet region + grip pixel.
    Shaded through the same pass as the player so they match in hand."""
    size = weapon_frames.SIZE
    palette = weapon_frames.PALETTE
    errors = []
    for name, spec in weapon_frames.WEAPONS.items():
        errors += validate(f"weapons.{name}", [spec["rows"]], size, size, palette)
        gx, gy = spec["grip"]
        if not (0 <= gx < size and 0 <= gy < size):
            errors.append(f"weapons.{name}: grip {(gx, gy)} outside the tile")
        elif spec["rows"][gy][gx] == ".":
            errors.append(f"weapons.{name}: grip {(gx, gy)} lands on transparency")
    if errors:
        print("INVALID weapons — refusing to write a broken sheet:")
        for e in errors:
            print("  " + e)
        return 1

    names = list(weapon_frames.WEAPONS.keys())
    canvas = [[(0, 0, 0, 0)] * (size * len(names)) for _ in range(size)]
    manifest = {"tile_size": [size, size], "weapons": {}}
    for c, name in enumerate(names):
        spec = weapon_frames.WEAPONS[name]
        shaded = shade_pass.shade_frame(spec["rows"], palette)
        for y in range(size):
            for x in range(size):
                canvas[y][c * size + x] = shaded[y][x]
        manifest["weapons"][name] = {
            "region": [c * size, 0, size, size],
            "grip": list(spec["grip"]),
        }

    os.makedirs(OUT_DIR, exist_ok=True)
    write_png(os.path.join(OUT_DIR, "weapons.png"), size * len(names), size, canvas)
    with open(os.path.join(OUT_DIR, "weapons.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"weapons.png  {size * len(names)}x{size}  ({len(names)} weapons: {', '.join(names)})")
    return 0


def main():
    # Player is full colour with a helmet lamp; enemies shade in value only
    # so the BodyJuice telegraph tints keep working (see enemy_frames.py).
    bad = bake("player", player_frames.W, player_frames.H,
               player_frames.PALETTE, player_frames.FRAMES,
               shade=getattr(player_frames, "SHADE", {"lamp": "l"}),
               anchors=getattr(player_frames, "ANCHORS", None))
    for sheet_name, spec in enemy_frames.SHEETS.items():
        w, h = spec["size"]
        bad |= bake(sheet_name, w, h, spec["palette"], spec["frames"],
                    shade=spec.get("shade", {"greyscale": True}))
    # Delve furniture and hub buildings: FULL COLOUR (they are scenery, not
    # telegraphs — the greyscale contract is for BodyJuice-tinted enemies only),
    # with the warm lamp boost around each sheet's glow pixels.
    for sheets in (object_frames.SHEETS, building_frames.SHEETS):
        for sheet_name, spec in sheets.items():
            w, h = spec["size"]
            bad |= bake(sheet_name, w, h, spec["palette"], spec["frames"],
                        shade=spec.get("shade"))
    bad |= bake_weapons()
    return bad


if __name__ == "__main__":
    raise SystemExit(main())
