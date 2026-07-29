class_name EliteModifierData
extends Resource
## THE VEIN (GDD decision log, 2026-07-23): a numeric prefix rolled onto an
## existing enemy once the mine's heat has passed heat_vein_threshold — not a
## new sprite, not a subclass. Content-as-data, same discipline as everything
## else: a new elite is a .tres, not a system edit.
##
## tint_colour/tint_strength LAYER onto the enemy's normal telegraph tint
## (Enemy._enter) rather than replace it — wind-up still reads yellow, a swing
## still reads red, per "telegraph everything". The elite's hue pushes through
## on top of that, so it reads as a spin on a known enemy, not a mystery one.

@export var id: StringName = &""
@export var display_name: String = "Elite"

@export_group("Stats")
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var poise_mult: float = 1.0
## Health restored per second while not staggered/hurt/dead. Vampiric's kit;
## 0 for everything else.
@export var regen_per_second: float = 0.0
## Extra haul this elite drops on top of its base enemy's own reward.
@export var haul_bonus: int = 0

@export_group("Readability")
@export var tint_colour: Color = Color.WHITE
@export_range(0.0, 1.0) var tint_strength: float = 0.35
