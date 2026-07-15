class_name PlayerStateMachine
extends Node
## Owns the active PlayerState and routes physics updates to it. States are
## discovered from the child nodes, so adding one in M1's combat half means
## dropping in a node and a script — no edits here.

## Node name of the state to start in.
@export var initial_state: StringName = &"Idle"

var _current: PlayerState
var _states: Dictionary[StringName, PlayerState] = {}


func setup(player: Player) -> void:
	for child: Node in get_children():
		if child is PlayerState:
			var state: PlayerState = child as PlayerState
			_states[child.name] = state
			state.setup(player, self)

	if not _states.has(initial_state):
		push_error("PlayerStateMachine: initial_state '%s' is not a child state." % initial_state)
		return

	_current = _states[initial_state]
	_current.enter()


func physics_update(delta: float) -> void:
	if _current == null:
		return
	var next: StringName = _current.physics_update(delta)
	if next != &"":
		transition_to(next)


## Route an incoming hit to whichever state is live. Fires from the hurtbox
## signal during the physics step, not from physics_update, so it transitions
## directly rather than returning a name.
func handle_hit(hitbox: Hitbox) -> void:
	if _current == null:
		return
	var next: StringName = _current.on_hit(hitbox)
	if next != &"":
		transition_to(next)


func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("PlayerStateMachine: no state named '%s'." % state_name)
		return
	_current.exit()
	_current = _states[state_name]
	_current.enter()


func get_current_name() -> StringName:
	return _current.name if _current != null else &"<none>"
