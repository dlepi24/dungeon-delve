class_name CrumblePlatform
extends StaticBody2D
## A timber bridge that gives way a beat after you land on it. Stand still and
## the mine drops you; keep moving and it holds just long enough. The collapse
## fiction, made into a verb you feel through your feet.
##
## Deterministic: all timing in physics ticks, triggered by player contact
## (which is itself deterministic). The shake is _process-visual only.

## How long it holds after first contact before giving way.
@export var shake_ms: int = 450
## How long it stays gone before re-forming.
@export var gone_ms: int = 2600
@export var size: Vector2 = Vector2(96, 14)
@export var colour: Color = Color(0.5, 0.4, 0.26)

enum State { SOLID, SHAKING, GONE }
var _state: State = State.SOLID
var _elapsed: int = 0

var _shape: CollisionShape2D
var _visual: ColorRect


func _ready() -> void:
	collision_layer = CollisionLayers.WORLD
	collision_mask = 0

	_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y * 0.5)
	add_child(_shape)

	_visual = ColorRect.new()
	_visual.size = size
	_visual.position = Vector2(-size.x * 0.5, -size.y)
	_visual.color = colour
	add_child(_visual)

	# The tripwire: a sensor riding just above the surface, watching for the
	# player's body. Bodies, not areas — the hurtbox is for combat.
	var sensor: Area2D = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = CollisionLayers.PLAYER
	var sensor_shape: CollisionShape2D = CollisionShape2D.new()
	var sensor_rect: RectangleShape2D = RectangleShape2D.new()
	sensor_rect.size = Vector2(size.x, 10)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -size.y - 5)
	sensor.add_child(sensor_shape)
	sensor.body_entered.connect(_on_body_entered)
	add_child(sensor)


func _on_body_entered(body: Node2D) -> void:
	if _state == State.SOLID and body is Player:
		_state = State.SHAKING
		_elapsed = 0


func _physics_process(_delta: float) -> void:
	if Hitstop.is_frozen() or _state == State.SOLID:
		return
	_elapsed += 1
	match _state:
		State.SHAKING:
			if _elapsed >= Ticks.from_ms(shake_ms):
				_state = State.GONE
				_elapsed = 0
				_shape.set_deferred(&"disabled", true)
		State.GONE:
			if _elapsed >= Ticks.from_ms(gone_ms):
				_state = State.SOLID
				_elapsed = 0
				_shape.set_deferred(&"disabled", false)


## Visual only: the warning judder while it decides to drop you, the fade while
## it is gone, the reappearance.
func _process(_delta: float) -> void:
	match _state:
		State.SOLID:
			_visual.modulate.a = 1.0
			_visual.position.x = -size.x * 0.5
		State.SHAKING:
			_visual.modulate.a = 1.0
			_visual.position.x = -size.x * 0.5 + randf_range(-2.5, 2.5)
		State.GONE:
			_visual.modulate.a = maxf(0.0, _visual.modulate.a - 0.1)
			_visual.position.x = -size.x * 0.5
