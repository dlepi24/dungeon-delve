extends CanvasLayer
## A short black fade-in on every room entry, so moving deeper reads as
## ARRIVING somewhere rather than the level teleporting around you.
##
## Listens to the Events bus; nothing needs a reference to it. Visual only —
## the fade never blocks input or delays the room being live underneath it.

## Seconds from black to clear.
@export var fade_time: float = 0.35

var _alpha: float = 0.0
var _rect: ColorRect


func _ready() -> void:
	layer = 30
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.anchors_preset = Control.PRESET_FULL_RECT
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	Events.room_entered.connect(func(_i: int, _id: String) -> void: _alpha = 1.0)
	Events.run_started.connect(func(_seed: int) -> void: _alpha = 1.0)


func _process(delta: float) -> void:
	# Draw, THEN decay — the other order eats the effect on a long frame.
	_rect.visible = _alpha > 0.01
	_rect.modulate.a = _alpha
	_alpha = move_toward(_alpha, 0.0, delta / maxf(0.05, fade_time))
