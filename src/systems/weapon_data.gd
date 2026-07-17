class_name WeaponData
extends Resource
## A weapon that changes how you fight — reach, speed, damage, poise. Content is
## data: a new weapon is a .tres, and it can drop in a run or (later) be sold.
##
## The player's own exports ARE the base pickaxe; equipping a WeaponData overrides
## them for the run. Permanent upgrades (damage, attack speed) and buffs still
## multiply on top, so a found weapon and your meta progression stack.
##
## The whole point is that these feel DIFFERENT: a Dagger is fast/short/weak, a
## Maul is slow/huge/heavy. Flat +damage upgrades felt the same; a weapon does not.

@export var display_name: String = "Weapon"
@export var damage: float = 12.0
@export var poise_damage: float = 12.0

@export_group("Timing (ms)")
@export var startup_ms: int = 90
@export var active_ms: int = 80
@export var recovery_ms: int = 180
@export var cancel_start_ms: int = 170

@export_group("Reach")
## Hitbox size — the weapon's reach and coverage.
@export var hitbox_size: Vector2 = Vector2(46, 44)
@export var hitbox_offset: Vector2 = Vector2(34, -28)
## Fraction of run speed kept while swinging. Heavy weapons plant your feet.
@export_range(0.0, 1.0) var move_control: float = 0.15

@export_group("Readability")
@export var swing_colour: Color = Color(0.85, 0.95, 1.0, 0.85)
## HUD/shop icon (assets/icons/, baked by tools/gen_icons.py). Null falls back
## to a flat swing_colour square, so a missing icon degrades, not crashes.
@export var icon: Texture2D
