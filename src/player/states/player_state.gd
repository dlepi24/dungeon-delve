class_name PlayerState
extends Node
## Base for player FSM states. One state per script, each a child node of the
## StateMachine, so the player script never becomes a 600-line match statement
## and M3's enemies can reuse this shape instead of reinventing it.
##
## physics_update() RETURNS the name of the state to switch to, or &"" to stay
## put. It does not call transition_to() itself. That distinction matters: a
## state that switches mid-update would otherwise keep executing lines after it
## has already handed over control, which is the classic one-frame FSM bug.

var player: Player
var machine: PlayerStateMachine


func setup(p: Player, m: PlayerStateMachine) -> void:
	player = p
	machine = m


func enter() -> void:
	pass


func exit() -> void:
	pass


## Return the next state's node name, or &"" to remain in this state.
func physics_update(_delta: float) -> StringName:
	return &""


## Something landed on our hurtbox and i-frames did not eat it. Return the state
## to switch to, or &"" to ignore. Taking a hit means hitstun unless a state has
## a reason to say otherwise — Parry is the whole point of this being overridable.
func on_hit(_hitbox: Hitbox) -> StringName:
	return &"Hitstun"
