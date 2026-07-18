extends PlayerState
## Standing still on the ground.


func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, 0.0)

	if player.try_consume_jump():
		return &"Air"
	if player.try_consume_roll():
		return &"Roll"
	if player.try_consume_attack():
		return &"Attack"
	if player.try_consume_parry():
		return &"Parry"
	if Input.is_action_just_pressed(&"skill_2"):
		var anchor: Node2D = player.find_hook_anchor()
		if anchor != null:
			player.hook_target = anchor
			return &"Hook"
	if not player.is_on_floor():
		return &"Air"

	if not is_zero_approx(player.get_input_direction()):
		return &"Run"
	return &""
