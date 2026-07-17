class_name UpgradeData
extends Resource
## One permanent upgrade the vendor sells. Per the hard rule, content is data: a
## new upgrade is a .tres, not a system edit. M5 ships one (max health); M6 adds
## more by dropping in resources.

@export var id: StringName = &"max_health"
@export var display_name: String = "Reinforced Lungs"
@export var description: String = "+20 max health"

## What each level adds to the stat. The player reads level * amount at spawn.
@export var per_level: float = 20.0
## Cap, so an upgrade cannot be bought forever.
@export var max_level: int = 5

@export_group("Cost")
## First level's cost in banked haul.
@export var base_cost: int = 40
## Each level costs this much more than the last (linear ramp). Escalating cost
## is what keeps early haul meaningful without trivialising late runs.
@export var cost_step: int = 30


func cost_for_level(level: int) -> int:
	return base_cost + cost_step * level


func value_at_level(level: int) -> float:
	return per_level * float(level)
