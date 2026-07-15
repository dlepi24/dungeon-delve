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
