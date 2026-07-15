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
##
## Deliberately empty at M0. Signals land as M1 systems earn them.
