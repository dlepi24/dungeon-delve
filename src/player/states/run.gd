extends PlayerState
## Moving along the ground.


func physics_update(delta: float) -> StringName:
	var direction: float = player.get_input_direction()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, direction)
	player.update_facing(direction)

	if player.try_consume_jump():
		return &"Air"
	if player.try_consume_roll():
		return &"Roll"
	if not player.is_on_floor():
		return &"Air"

	# Hold Run until we have actually stopped, not just until input released, or
	# the decel curve gets cut off and stopping reads as an abrupt snap.
	if is_zero_approx(direction) and is_zero_approx(player.velocity.x):
		return &"Idle"
	return &""
