class_name HealthBar
extends Node2D
## A gray-box health bar. Used above enemies and, driven by the HUD, for the
## player.
##
## Readability, not decoration. "Is this thing nearly dead?" changes whether you
## greed one more hit or roll away — it is a combat decision, and without a bar
## the answer is invisible.
##
## The drain is what makes damage legible: the fill snaps to the new value while
## a slower red bar chases it, so you SEE how big a hit was rather than watching
## a number jump. That difference is most of why a riposte reads as a payoff.

@export var bar_size: Vector2 = Vector2(46, 6)
@export var fill_colour: Color = Color(0.35, 0.85, 0.4)
@export var drain_colour: Color = Color(0.9, 0.25, 0.25)
@export var background_colour: Color = Color(0, 0, 0, 0.65)
## How fast the drain bar catches up, in ratio per second.
@export var drain_speed: float = 0.9
## Hide entirely at full health, so an untouched room is not covered in bars.
@export var hide_when_full: bool = true

var _ratio: float = 1.0
var _drain: float = 1.0

@onready var _background: ColorRect = $Background
@onready var _drain_rect: ColorRect = $Drain
@onready var _fill: ColorRect = $Fill


func _ready() -> void:
	_apply_size()
	_background.color = background_colour
	_drain_rect.color = drain_colour
	_fill.color = fill_colour
	_refresh()


func _apply_size() -> void:
	for rect: ColorRect in [_background, _drain_rect, _fill]:
		rect.position = Vector2(-bar_size.x * 0.5, 0.0)
		rect.size = bar_size


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	# Taking damage snaps the green bar; healing snaps both, or the drain bar
	# would sit below the fill and read as damage.
	if _ratio > _drain:
		_drain = _ratio
	_refresh()


func _process(delta: float) -> void:
	if _drain > _ratio:
		_drain = maxf(_ratio, _drain - drain_speed * delta)
		_refresh()


func _refresh() -> void:
	visible = not (hide_when_full and is_equal_approx(_ratio, 1.0) and is_equal_approx(_drain, 1.0))
	_fill.size = Vector2(bar_size.x * _ratio, bar_size.y)
	_drain_rect.size = Vector2(bar_size.x * _drain, bar_size.y)
