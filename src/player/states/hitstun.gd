extends PlayerState
## Took a hit. Knocked back, briefly not in control.

var _elapsed: int = 0


func enter() -> void:
	_elapsed = 0
	player.velocity.x = float(player.last_hit_direction) * player.hitstun_knockback
	player.velocity.y = -player.hitstun_pop


## Already reeling — a second hit should not restart the stun, or a multi-hit
## attack could lock you down forever.
func on_hit(_hitbox: Hitbox) -> StringName:
	return &""


func physics_update(delta: float) -> StringName:
	_elapsed += 1
	player.apply_gravity(delta)
	# Bleed off the knockback rather than stopping dead.
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.ground_friction * delta)

	if _elapsed < player.ms_to_ticks(player.hitstun_ms):
		return &""
	if not player.is_on_floor():
		return &"Air"
	return &"Idle" if is_zero_approx(player.get_input_direction()) else &"Run"
