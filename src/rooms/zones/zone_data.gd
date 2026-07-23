class_name ZoneData
extends Resource
## A stratum of the mine: everything that makes a band of depths read as a
## PLACE rather than "more mine". The run descends through three of these
## (Upper Workings -> Hot Vein -> Deadlight), and each carries its own grade,
## light, air, soundtrack, room pool and enemy lean — so the same systems wear
## a different skin per zone and depth becomes a journey instead of a number.
##
## Content-as-data, same discipline as weapons and enemies: a new zone is a new
## .tres, not a system edit. Everything visual here is applied by
## MineAtmosphere/Room; everything gameplay-adjacent (pools, spawn lean) is
## read by the Delve from the seeded streams, so determinism holds — a zone
## changes WHAT the draws mean, never how many draws happen.
##
## Art direction contract (GDD Setting): warm = yours and safe, cold = the
## mine, amber = value. The player's lamp therefore stays warm in every zone —
## the zones recolour the WORLD around that constant, which is what makes the
## Deadlight read as hostile: your one warm thing against its cold light.

@export var id: StringName = &""
## Shown on the zone title card and the descend prompt. Uppercase display style
## is applied by the card, not stored here.
@export var display_name: String = ""
## One quiet line under the title card — flavour, not instruction.
@export var tagline: String = ""

@export_group("Grade")
## The CanvasModulate the whole world sits under while in this zone.
@export var darkness: Color = Color(0.3, 0.34, 0.44)
## Multiplied onto the room's tile layers only (never enemies — their
## telegraph tint contract must survive), pushing the rock itself toward the
## zone's temperature.
@export var world_tint: Color = Color.WHITE
## Colour of the airborne particles; embers burn hot, spores glow cold.
@export var dust_colour: Color = Color(1.0, 0.9, 0.72)
## How the air moves: &"dust" drifts down, &"embers" rise, &"spores" hang.
@export var mote_style: StringName = &"dust"
## How hard the headroom sinks into shadow in this zone.
@export_range(0.0, 1.0) var top_shadow: float = 0.7
@export_range(0.0, 1.0) var vignette_strength: float = 0.55
## A glow rising from the BOTTOM of the frame — what is underneath this zone,
## bleeding up. The Hot Vein's magma light, the Deadlight's pale shine. 0 off.
@export_range(0.0, 1.0) var bottom_glow: float = 0.0
@export var bottom_glow_colour: Color = Color(1.0, 0.45, 0.18)

@export_group("Music")
## Delve track paths this zone draws from. The room-change drift shuffles
## WITHIN this pool, so a zone keeps its voice for its whole band.
@export var music_tracks: PackedStringArray = PackedStringArray()

@export_group("Rooms")
## Middle-room ids this zone's depths draw from (both door candidates).
@export var room_pool: PackedStringArray = PackedStringArray()
## Centrepiece ids used when the run's one big room lands in this zone.
@export var big_pool: PackedStringArray = PackedStringArray()

@export_group("Spawns")
## Chance an authored marker swaps to a same-weight alternate here.
@export_range(0.0, 1.0) var swap_chance: float = 0.45
## What a grunt-post may hold instead in this zone.
@export var grunt_swaps: PackedStringArray = PackedStringArray(["dart", "slinger"])
## What a dart-post may hold instead in this zone.
@export var dart_swaps: PackedStringArray = PackedStringArray(["grunt", "gnat"])
## Extra brute-promotion chance on top of the depth curve — the Hot Vein's
## heavier garrison is this number.
@export var promote_bonus: float = 0.0
