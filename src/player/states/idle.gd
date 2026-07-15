extends PlayerState
## Standing still on the ground.


func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, 0.0)

	if player.try_consume_jump():
		return &"Air"
	if player.try_consume_roll():
		return &"Roll"
	if not player.is_on_floor():
		return &"Air"

	if not is_zero_approx(player.get_input_direction()):
		return &"Run"
	return &""
