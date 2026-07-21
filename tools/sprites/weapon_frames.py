#!/usr/bin/env python3
"""Weapon sprites, authored as ASCII. Run via tools/gen_sprites.py.

Stage 2 of the weapon layer (docs/art-specs/weapon-layer.md): the four
weapons the game ships — pickaxe, dagger, maul, spear — each on a 24x24
canvas, drawn SHAFT-UP (the manifest's angle 90) so WeaponSprite's
rotation math stays trivial: rotate by `deg_to_rad(90 - anchor.angle)`
around the grip and the shaft lies along the anchor angle.

Every weapon declares its GRIP — the pixel that sits on the hand anchor
(where the glove closes around the shaft). gen_sprites validates that the
grip lands on an opaque pixel and writes it into the manifest next to the
sheet region.

Full colour, same discipline as player_frames.py: flat palette characters
here, shading at bake time via shade_pass (material ramps + directional
light + selective outlines). Colours are lifted from the palettes already
in the game — wood/steel/leather from player_frames.py, the weapon-identity
colours (pale dagger steel, maul iron, spear point) from gen_icons.py so a
weapon in hand matches its HUD icon.

LEGEND
  .  transparent    o  outline          w  wood shaft      k  leather wrap
  m  steel          d  dark steel       g  gold guard      r  cord lash
  b  dagger pale steel                  i  maul dark iron
  I  maul iron highlight                p  spear bright point
"""

SIZE = 24

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (26, 18, 14, 255),      # outline (player sheet)
    "w": (140, 96, 54, 255),     # wood (player sheet)
    "k": (44, 34, 28, 255),      # leather wrap (player belt/strap)
    "m": (196, 202, 214, 255),   # steel (player sheet)
    "d": (96, 104, 112, 255),    # dark steel (icons)
    "g": (212, 175, 55, 255),    # gold guard (icons)
    "r": (176, 138, 92, 255),    # cord lash (player rope/satchel)
    "b": (205, 255, 230, 255),   # dagger pale steel (icons / swing colour)
    "i": (120, 110, 130, 255),   # maul dark iron (icons)
    "I": (160, 148, 170, 255),   # maul iron highlight (icons)
    "p": (255, 210, 140, 255),   # spear bright point (icons / swing colour)
}

# Shaft sits on columns 11-12 for every weapon so they swap in-hand without
# a visual jump; the grip is the wrap pixel the glove closes on.

PICKAXE = [
    "........oooooooo........",
    "......oommmmmmmmoo......",
    "....oommmmmmmmmmmmoo....",
    "...ommmmooowwooommmmo...",
    "..ommmo...owwo...ommmo..",
    "..omo.....owwo.....omo..",
    "...o......owwo......o...",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........okko..........",
    "..........okko..........",
    "..........okko..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........oooo..........",
    "........................",
]

DAGGER = [
    "........................",
    "........................",
    "........................",
    "........................",
    "...........oo...........",
    "..........obbo..........",
    "..........obbo..........",
    ".........obbbbo.........",
    ".........obbbbo.........",
    ".........obbbbo.........",
    ".........obbbbo.........",
    "..........obbo..........",
    "..........obbo..........",
    ".....oggggggggggggo.....",
    "..........okko..........",
    "..........okko..........",
    "..........okko..........",
    "..........okko..........",
    ".........oggggo.........",
    "..........oooo..........",
    "........................",
    "........................",
    "........................",
    "........................",
]

MAUL = [
    "....oooooooooooooooo....",
    "...oiiiiIIIIIIiiiiiio...",
    "...oiiiIIIIIIIIiiiiio...",
    "...oiiiiiiiiiiiiiiiio...",
    "...oiiiiiiiiiiiiiiiio...",
    "...oiiiiiiiiiiiiiiiio...",
    "....oooooooooooooooo....",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........okko..........",
    "..........okko..........",
    "..........okko..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........oooo..........",
    "........................",
    "........................",
]

SPEAR = [
    "...........oo...........",
    "..........oppo..........",
    "..........oppo..........",
    ".........oppppo.........",
    ".........oppppo.........",
    "..........oppo..........",
    "..........oddo..........",
    "..........orro..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........okko..........",
    "..........okko..........",
    "..........okko..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........owwo..........",
    "..........oddo..........",
    "..........oooo..........",
    "........................",
]

# Order here is sheet order (left to right). Grip is (x, y) in the tile,
# origin top-left — the middle of the leather wrap on every weapon.
WEAPONS = {
    "pickaxe": {"rows": PICKAXE, "grip": (11, 16)},
    "dagger":  {"rows": DAGGER,  "grip": (11, 15)},
    "maul":    {"rows": MAUL,    "grip": (11, 16)},
    "spear":   {"rows": SPEAR,   "grip": (11, 15)},
}
