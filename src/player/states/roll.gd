extends PlayerState
## The safe option, per the GDD pillar: always available, never punished, no
## stamina and no cooldown. Direction locks at the start so a roll always commits
## to a readable line rather than steering mid-way.

var _elapsed_ticks: int = 0
var _direction: int = 1


func enter() -> void:
	_elapsed_ticks = 0
	var input: float = player.get_input_direction()
	# Roll where you are steering; if steering nowhere, roll where you face.
	_direction = player.facing if is_zero_approx(input) else (1 if input > 0.0 else -1)
	player.facing = _direction
	player.invulnerable = false
	Events.player_rolled.emit()


func exit() -> void:
	player.invulnerable = false
	player.roll_progress = 0.0


func physics_update(delta: float) -> StringName:
	_elapsed_ticks += 1
	# Drives the visual tumble. Visual only — nothing reads this back.
	player.roll_progress = float(_elapsed_ticks) / maxf(1.0, float(player.ms_to_ticks(player.roll_duration_ms)))

	var iframe_start: int = player.ms_to_ticks(player.roll_iframe_start_ms)
	var iframe_end: int = iframe_start + player.ms_to_ticks(player.roll_iframe_duration_ms)
	player.invulnerable = _elapsed_ticks > iframe_start and _elapsed_ticks <= iframe_end

	# Gravity still applies so rolling off a ledge falls, and roll speed overrides
	# horizontal control outright — that commitment is what makes it a decision.
	player.apply_gravity(delta)
	player.velocity.x = float(_direction) * player.roll_speed

	if _elapsed_ticks < player.ms_to_ticks(player.roll_duration_ms):
		return &""

	if not player.is_on_floor():
		return &"Air"
	return &"Idle" if is_zero_approx(player.get_input_direction()) else &"Run"
