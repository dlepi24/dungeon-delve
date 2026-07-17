class_name ShrineData
extends Resource
## One shrine bargain: a boon and its price, for the rest of the run.
##
## Design (GDD 2026-07-17): shrines are the greed pillar in miniature. An altar
## in a delve room offers this bargain in plain words; accept and it shapes the
## WHOLE run (not a timed buff — buffs stay the short treats), walk away free.
## Bargains stack if you find and accept more than one. Content rule holds: a
## new bargain is a .tres in the pool, not code.
##
## Three flavours, all expressible here: stat trades (boon vs bane multipliers),
## pay-now (ore_cost spends CARRIED ore — at-risk loot into strength), and curse
## trades (promote_bonus feeds the spawn-promotion system).

@export var id: StringName = &"bargain"
@export var display_name: String = "Bargain"
## The offer, in one line the player reads at the altar. Say both halves.
@export var bargain_text: String = ""
## Shown in the HUD's red column while active. Empty = no listed bane (the
## price was paid up front, e.g. an ore cost).
@export var bane_text: String = ""

@export_group("Boon")
## Multiplies all haul gained this run. 1.4 = +40% ore.
@export var ore_mult: float = 1.0
## Outgoing damage. Folds into the player's damage_multiplier.
@export var damage_mult: float = 1.0
## Move speed.
@export var move_mult: float = 1.0
## Attack speed.
@export var attack_speed_mult: float = 1.0

@export_group("Bane")
## Incoming damage taken. 1.5 = take half again as much.
@export var incoming_mult: float = 1.0
## Max health. 0.75 = lose a quarter of your maximum.
@export var max_health_mult: float = 1.0
## Added to the depth-promotion chance per spawn: the mine sends harder foes.
@export var promote_bonus: float = 0.0
## Carried (at-risk) ore paid on accept. 0 = the bargain itself is the price.
@export var ore_cost: int = 0

@export_group("Readability")
## Altar glow and HUD colour.
@export var colour: Color = Color(0.9, 0.75, 0.4)
