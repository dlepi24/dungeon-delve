class_name BuffData
extends Resource
## A temporary power-up picked up during a run. Content is data: a new buff is a
## .tres, and enemies can drop any of them.
##
## Multipliers combine with the player's permanent upgrades and with each other,
## so grabbing Might while Haste is active does both. 1.0 means "no effect on
## this stat", which is why every multiplier defaults to 1.0.

@export var id: StringName = &"haste"
@export var display_name: String = "Haste"
@export var duration_ms: int = 8000

@export_group("Effects")
## Outgoing damage. 2.0 = double.
@export var damage_mult: float = 1.0
## Incoming damage. 0.5 = take half. 0.0 = invulnerable for the duration.
@export var incoming_mult: float = 1.0
## Move speed. 1.4 = 40% faster.
@export var move_mult: float = 1.0
## Attack speed. 1.5 = swings 50% faster.
@export var attack_speed_mult: float = 1.0

## HUD/pickup colour, so each buff reads at a glance.
@export var colour: Color = Color(0.4, 0.9, 1.0)
