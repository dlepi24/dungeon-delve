class_name DebrisRain
extends Node2D
## The collapsing mine, collapsing: rocks shake loose from the ceiling on a
## schedule seeded at room load. Each fall is telegraphed by a glowing column
## for a beat before the rock releases — "telegraph everything" applies to the
## ceiling too.
##
## The rock is a Projectile, which buys everything for free: roll i-frames
## dodge it, walls stop it, and — the joy — a PARRY bats it away. Depth and
## mine heat schedule more falls ("heat shakes the mine loose"), which means
## the same seed at different heat rains differently; that is heat working as
## designed, same as its spawn promotions.

const DEBRIS_ATTACK: String = "res://src/systems/hazards/debris_attack.tres"

## Ticks of glowing warning before each rock releases.
@export var warning_ticks: int = 48

## {tick: int, x: float}, set by the Delve from the seeded hazards stream.
var events: Array[Dictionary] = []
var room_height: float = 640.0

var _tick: int = 0
var _warnings: Dictionary[int, ColorRect] = {}


func _physics_process(_delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_tick += 1
	for i: int in events.size():
		var event: Dictionary = events[i]
		var release: int = event["tick"]
		if _tick == release - warning_ticks:
			_show_warning(i, event["x"])
		elif _tick == release:
			_drop(i, event["x"])


func _show_warning(index: int, x: float) -> void:
	var column: ColorRect = ColorRect.new()
	column.size = Vector2(16, room_height)
	column.position = Vector2(x - 8, 0)
	column.color = Color(1.0, 0.75, 0.3, 0.14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_warnings[index] = column


func _drop(index: int, x: float) -> void:
	var column: ColorRect = _warnings.get(index)
	if column != null:
		column.queue_free()
		_warnings.erase(index)
	var attack: EnemyAttackData = load(DEBRIS_ATTACK) as EnemyAttackData
	Projectile.spawn(get_parent(), Vector2(x, 44.0), Vector2.DOWN, attack)
