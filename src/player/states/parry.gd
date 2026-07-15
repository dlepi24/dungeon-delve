extends PlayerState
## The greedy option, per the GDD pillar.
##
## A tight active window at the front (120 ms), then a recovery tail you are
## locked into (~300 ms). Land it and you deflect the hit and open a riposte;
## miss it and the tail is a real punish window. Roll deliberately does not
## cancel the tail — see the note on parry_whiff_recovery_ms in player.gd.

var _elapsed: int = 0


func enter() -> void:
	_elapsed = 0
	# Plant. Parrying is a stand-and-read, not a movement option.
	player.velocity.x = 0.0


## The whole pillar lives in this branch.
func on_hit(hitbox: Hitbox) -> StringName:
	if _elapsed <= player.ms_to_ticks(player.parry_active_ms):
		hitbox.notify_parried()
		player.open_riposte()
		Events.parry_succeeded.emit()
		# Straight back to neutral with no recovery — "reward is speed and
		# style". The tempo swing IS the reward, on top of the riposte.
		return &"Idle"
	# Caught inside the recovery tail. That is the punish, and it is intended.
	return &"Hitstun"


func physics_update(delta: float) -> StringName:
	_elapsed += 1
	player.apply_gravity(delta)
	player.apply_horizontal(delta, 0.0)

	var total: int = player.ms_to_ticks(player.parry_active_ms) + player.ms_to_ticks(player.parry_whiff_recovery_ms)
	if _elapsed >= total:
		if not player.is_on_floor():
			return &"Air"
		return &"Idle"
	return &""


func is_window_active() -> bool:
	return _elapsed <= player.ms_to_ticks(player.parry_active_ms)
