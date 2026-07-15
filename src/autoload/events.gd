extends Node
## Global signal bus. Autoloaded as `Events`.
##
## Systems announce what happened here instead of reaching across the tree for
## each other. A shot of decoupling: the player does not know the HUD exists, it
## just reports that it took damage, and whoever cares connects.
##
## Conventions:
## - Signals are past-tense reports of fact, never commands. `player_died`, not
##   `kill_player`. A command signal is just `get_node("../../..")` wearing a hat.
## - Every parameter is statically typed.
## - Add a signal here only when a second system actually needs to hear it.
##   Speculative signals rot.

## A parry landed. M2's hitstop (6 frames, per the feel spec) hangs off this.
signal parry_succeeded

## Any attack connected. `was_riposte` marks the parry payoff so M2 can give it
## heavier hitstop than a normal 3-frame hit.
signal hit_landed(damage: float, was_riposte: bool)

## The player took a hit and entered hitstun.
signal player_hurt(damage: float)

## Movement beats. These exist because Sfx listens to them — the player should
## not have to know audio exists in order to make a sound.
signal player_jumped
signal player_landed
signal player_rolled

## An enemy's health hit zero.
signal enemy_died(enemy: Node2D)

## The player's health hit zero. M5 owns the real run-loss consequences; for now
## the room just puts you back.
signal player_died

## A run began, from this seed. The seed is shareable and reproduces the delve.
signal run_started(seed_value: int)
## The player entered room `index` of the plan.
signal room_entered(index: int, room_id: String)
## Every room in the plan is done.
signal delve_completed
