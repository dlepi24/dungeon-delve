extends PlayerState
## Airborne: rising, falling, or inside the coyote window.


func physics_update(delta: float) -> StringName:
	var direction: float = player.get_input_direction()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, direction)
	player.update_facing(direction)
	player.try_jump_cut()

	# Checked before the landing transition on purpose. This one ordering is what
	# makes both feel features actually work: a coyote jump fires while we are
	# briefly off the ledge, and a jump buffered just before touchdown fires on
	# the landing frame itself rather than being eaten. We stay in Air either way
	# — try_consume_jump has already set the velocity.
	if player.try_consume_jump():
		return &""
	if player.try_consume_roll():
		return &"Roll"
	if player.try_consume_attack():
		return &"Attack"
	if player.try_consume_parry():
		return &"Parry"

	if player.is_on_floor():
		return &"Idle" if is_zero_approx(direction) else &"Run"
	return &""
