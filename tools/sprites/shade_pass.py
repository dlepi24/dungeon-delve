#!/usr/bin/env python3
"""Automatic shading post-pass over the ASCII-authored sprite frames.

Used by tools/gen_sprites.py at bake time. The ASCII stays the source of
truth — this never edits it, it only decides what colour each authored
pixel becomes:

  1. Material ramps   — each palette colour becomes a 5-step ramp
                        (hue-shifted: shadows cooler, highlights warmer)
  2. Directional light — top/front edges lit, bottom/back edges shaded
  3. Selective outlines — the silhouette (outline touching transparency)
                        stays near-black so readability survives; interior
                        outline pixels soften to the darkest shade of the
                        material they border. With `rim=True`, silhouette
                        pixels on the LIT side (top / upper-front) instead
                        take a warm rim-light colour — used on the player so
                        the Delver reads against the dark back wall.
  4. Lamp glow        — pixels near a designated lamp character get a
                        one-step warm boost

GREYSCALE SHEETS (enemies) shade in VALUE ONLY — hue and saturation stay
zero — so the BodyJuice telegraph tints multiply over them exactly as they
did over the flat art. That constraint is load-bearing; see enemy_frames.py.
"""
import colorsys


def ramp(rgb, greyscale=False):
    """5-step ramp around a base colour: [shadow2, shadow1, base, hi1, hi2]."""
    r, g, b = [c / 255.0 for c in rgb[:3]]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    steps = []
    specs = [(-0.045, 1.18, 0.58), (-0.025, 1.10, 0.78),
             (0.0, 1.0, 1.0), (0.035, 0.85, 1.22), (0.07, 0.65, 1.42)]
    for dh, sm, vm in specs:
        if greyscale:
            nh, ns = 0.0, 0.0
        else:
            nh = (h + (dh if _is_warm(h) else -dh)) % 1.0
            ns = min(1.0, s * sm)
        nv = max(0.0, min(1.0, v * vm))
        rr, gg, bb = colorsys.hsv_to_rgb(nh, ns, nv)
        steps.append((int(rr * 255), int(gg * 255), int(bb * 255), 255))
    return steps


def _is_warm(h):
    # Warm hues shift toward yellow when lit; cool hues toward cyan.
    return h < 0.22 or h > 0.83


def shade_frame(frame, palette, greyscale=False, outline_ch="o",
                lamp_ch=None, light=(1, -1), rim=False):
    """frame: list of equal-width strings. Returns a grid of RGBA tuples.

    `light` is the light direction the FRONT of the sprite faces; sprites
    are authored facing right and lit from the upper-front by convention.
    """
    H, W = len(frame), len(frame[0])
    ramps = {ch: ramp(col, greyscale) for ch, col in palette.items()
             if col[3] != 0}

    def at(x, y):
        if 0 <= x < W and 0 <= y < H:
            return frame[y][x]
        return "."

    lamps = [(x, y) for y in range(H) for x in range(W)
             if lamp_ch and frame[y][x] == lamp_ch]

    out = [[(0, 0, 0, 0)] * W for _ in range(H)]
    lx, ly = light
    for y in range(H):
        for x in range(W):
            ch = frame[y][x]
            if ch == ".":
                continue
            if ch == outline_ch:
                touching_air = any(at(x + dx, y + dy) == "."
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if touching_air:
                    lit_air = (at(x, y - 1) == "." or at(x + lx, y + ly) == ".")
                    neigh = [at(x + dx, y + dy) for dx, dy in
                             ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    mats = [c for c in neigh if c not in (".", outline_ch)]
                    if rim and lit_air and mats and not greyscale:
                        # Warm rim light: brightest ramp step of the touched
                        # material, pushed toward lantern-warm.
                        mat = max(sorted(set(mats)), key=mats.count)
                        hi = ramps[mat][4]
                        out[y][x] = (int(hi[0] * 0.55 + 255 * 0.45),
                                     int(hi[1] * 0.55 + 214 * 0.45),
                                     int(hi[2] * 0.55 + 150 * 0.45), 255)
                    else:
                        out[y][x] = palette[outline_ch]
                else:
                    neigh = [at(x + dx, y + dy) for dx, dy in
                             ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    mats = [c for c in neigh if c not in (".", outline_ch)]
                    # sorted(): set order is per-process random, and max()
                    # breaks count ties by iteration order — unsorted, the
                    # bake was nondeterministic and never round-tripped.
                    mat = max(sorted(set(mats)), key=mats.count) if mats else None
                    out[y][x] = ramps[mat][0] if mat else palette[outline_ch]
                continue

            step = 2  # base
            up, down = at(x + lx, y + ly), at(x - lx, y - ly)
            above, below = at(x, y - 1), at(x, y + 1)
            front = at(x + lx, y)
            if above in (".", outline_ch) or up in (".", outline_ch):
                step = 3
            elif below in (".", outline_ch):
                step = 1
            elif front in (".", outline_ch):
                step = 3
            elif down in (".", outline_ch):
                step = 1
            if above in (".", outline_ch) and at(x, y - 2) in (".", outline_ch):
                step = min(4, step + 1)
            if lamps:
                d = min(max(abs(x - gx), abs(y - gy)) for gx, gy in lamps)
                if d <= 2 and step < 4:
                    step += 1
            out[y][x] = ramps[ch][step]
    return out
