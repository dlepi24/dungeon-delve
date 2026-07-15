extends Camera2D
## Screenshake, plus following the player.
##
## Rooms are 1920x640 and the viewport is 1920x1080, so horizontally the room
## already fits — this exists mainly to keep the room framed vertically and to
## carry the shake. The follow is deliberately STIFF (high lerp): the M1 gate was
## judged with a static camera, and a laggy camera changes how movement reads.
## If it ever needs to be loose, that is a feel change and it is Dustin's call.

@export var target: Player
## 1.0 = snap. Lower values lag behind, which muddies the feel that was signed off.
@export_range(0.05, 1.0) var follow_stiffness: float = 1.0

@export_group("Shake")
@export_range(0.0, 1.0) var trauma_hit: float = 0.35
@export_range(0.0, 1.0) var trauma_parry: float = 0.6
@export_range(0.0, 1.0) var trauma_hurt: float = 0.45
@export var max_offset: Vector2 = Vector2(18, 12)
@export var max_roll_degrees: float = 1.5
@export var decay: float = 2.4

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.player_hurt.connect(_on_player_hurt)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Player


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_hit_landed(_damage: float, was_riposte: bool) -> void:
	add_trauma(trauma_parry if was_riposte else trauma_hit)


func _on_parry_succeeded() -> void:
	add_trauma(trauma_parry)


func _on_player_hurt(_damage: float) -> void:
	add_trauma(trauma_hurt)


func _process(delta: float) -> void:
	if target != null:
		var goal: Vector2 = Vector2(target.global_position.x, target.global_position.y - 200.0)
		global_position = global_position.lerp(goal, minf(1.0, follow_stiffness))

	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	_trauma = maxf(_trauma - decay * delta, 0.0)
	# Trauma SQUARED: small hits barely register, big ones kick. Linear reads mushy.
	var shake: float = _trauma * _trauma
	offset = Vector2(
		max_offset.x * shake * _rng.randf_range(-1.0, 1.0),
		max_offset.y * shake * _rng.randf_range(-1.0, 1.0),
	)
	rotation = deg_to_rad(max_roll_degrees) * shake * _rng.randf_range(-1.0, 1.0)
