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
## Baseline cap, available to everyone regardless of build path. So an
## upgrade cannot be bought forever with no keystone chosen.
@export var max_level: int = 5

@export_group("Keystone")
## THE KEYSTONE SYSTEM (2026-07-23 decision log): nothing here is ever
## locked — every upgrade stays purchasable up to `max_level` no matter what
## path you've picked (Dustin's call: "no lock, just a bias"). Picking the
## matching keystone lets THIS stat keep going past baseline, up to
## `extended_max_level`. Empty keystone_id (the default) means this upgrade
## has no deeper tier at all.
@export var keystone_id: StringName = &""
## Cap when `keystone_id` is the player's active keystone. Ignored (falls
## back to `max_level`) otherwise.
@export var extended_max_level: int = 0

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


## The cap this upgrade is actually bound by right now: extended if the
## player's active keystone matches this upgrade's, baseline otherwise.
func effective_max_level(active_keystone: StringName) -> int:
	if keystone_id != &"" and keystone_id == active_keystone and extended_max_level > 0:
		return extended_max_level
	return max_level
