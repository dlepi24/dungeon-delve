extends Enemy
## Lunges across the room instead of swinging in place.
##
## This is the roll teacher, and the counterweight to the Brute. It commits to a
## direction the moment the dash starts and overshoots past you, so parrying it
## is possible but greedy — while rolling through it is clean and always
## available. The GDD pillar says roll-only play must stay fully viable; an
## enemy roster of nothing but parry-bait would quietly break that.
##
## Overrides the attack verb only. Every number still comes from its `.tres`.

var _dash_direction: int = 1


func _attack_start() -> void:
	super()
	# Lock the direction NOW. A dash that steers mid-flight is unreadable and
	# unrollable — the commitment is the whole reason it is fair.
	# How far it travels is dash_speed x swing_active_ms; tune the overshoot
	# past the player with those two, and it becomes rollable.
	_dash_direction = get_facing()


func _attack_physics(_delta: float) -> void:
	velocity.x = float(_dash_direction) * stats.dash_speed


func _attack_end() -> void:
	# Bleed most of the speed but not all: sliding to a stop sells the weight.
	velocity.x *= 0.35
