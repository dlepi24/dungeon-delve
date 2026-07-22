extends Camera2D
## Trauma-based screenshake.
##
## Shake is stored as "trauma" (0..1) and the offset uses trauma SQUARED. That
## curve is the whole trick: small hits barely register while big ones kick hard,
## where a linear mapping makes everything feel equally mushy. Trauma decays
## every frame, so repeated hits stack into something bigger instead of
## restarting a fixed animation.
##
## Visual only, so it runs in _process and uses its own unseeded RNG. That is
## safe specifically BECAUSE it never touches gameplay — if shake ever moved a
## hitbox, it would have to come from the GDD's seeded service instead, or two
## replays of the same inputs would diverge.

@export_group("Feel")
## Trauma added by a normal hit landing.
@export_range(0.0, 1.0) var trauma_hit: float = 0.35
## Trauma added by a parry. The pillar should hit harder than a normal swing.
@export_range(0.0, 1.0) var trauma_parry: float = 0.6
## Trauma added when the player takes a hit.
@export_range(0.0, 1.0) var trauma_hurt: float = 0.45
## Max pixel offset at full trauma.
@export var max_offset: Vector2 = Vector2(18, 12)
## Max rotation at full trauma, degrees. Keep small; a little goes a long way.
@export var max_roll_degrees: float = 1.5
## How fast trauma bleeds off, per second. Higher = shorter, sharper shake.
@export var decay: float = 2.4

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.player_hurt.connect(_on_player_hurt)


func add_trauma(amount: float) -> void:
	if not Settings.screen_shake:  # accessibility toggle, same as FollowCamera
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_hit_landed(_damage: float, was_riposte: bool) -> void:
	add_trauma(trauma_parry if was_riposte else trauma_hit)


func _on_parry_succeeded() -> void:
	add_trauma(trauma_parry)


func _on_player_hurt(_damage: float) -> void:
	add_trauma(trauma_hurt)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return

	_trauma = maxf(_trauma - decay * delta, 0.0)
	var shake: float = _trauma * _trauma
	offset = Vector2(
		max_offset.x * shake * _rng.randf_range(-1.0, 1.0),
		max_offset.y * shake * _rng.randf_range(-1.0, 1.0),
	)
	rotation = deg_to_rad(max_roll_degrees) * shake * _rng.randf_range(-1.0, 1.0)
