class_name HaulPickup
extends Area2D
## A nugget of ore dropped in the world. Sits on the Pickup collision layer, and
## when the player's collector overlaps it, it is collected into carried haul.
##
## Magnets toward the player once they are close, so you do not have to pixel-hunt
## loot in the middle of a fight — the collection should feel generous. Visual
## only in _process; the actual collect is a body check in _physics_process so it
## stays deterministic.

@export var amount: int = 1
@export var magnet_range: float = 120.0
@export var magnet_speed: float = 520.0
## Small pop upward on spawn so drops scatter off a corpse rather than stacking.
@export var spawn_pop: Vector2 = Vector2(0, -140)

var _velocity: Vector2 = Vector2.ZERO
var _player: Player = null
var _collected: bool = false

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_velocity = spawn_pop + Vector2(randf_range(-80, 80), 0)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return

	var to_player: Vector2 = (_player.global_position + Vector2(0, -28)) - global_position
	var dist: float = to_player.length()

	# Collect on contact.
	if dist < 22.0:
		_collect()
		return

	if dist < magnet_range:
		# Accelerate toward the player once in range.
		_velocity = _velocity.move_toward(to_player.normalized() * magnet_speed, magnet_speed * 4.0 * delta)
	else:
		# Otherwise fall and settle.
		_velocity.y += 900.0 * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 400.0 * delta)

	global_position += _velocity * delta


func _collect() -> void:
	_collected = true
	GameState.add_haul(amount)
	Events.haul_collected.emit(amount, global_position)
	queue_free()


## Visual only — a little spin and shimmer so ore reads as valuable.
func _process(_delta: float) -> void:
	if _visual != null:
		_visual.rotation += 0.06
