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
@export var fill_colour: Color = Color(0.42, 0.82, 0.4)
@export var drain_colour: Color = Color(0.9, 0.25, 0.25)
@export var background_colour: Color = Color(0.06, 0.05, 0.04, 0.8)
## A dark outline frame, so the bar reads as a framed gauge rather than a naked
## rectangle. Set width to 0 to disable (the tiny enemy bars keep a thin one).
@export var border_colour: Color = Color(0.09, 0.07, 0.05, 0.95)
@export var border_width: float = 2.0
## A one-pixel light lip along the top of the fill — the cheap trick that makes
## a flat bar read as a lit surface instead of programmer-art.
@export var highlight_colour: Color = Color(1, 1, 1, 0.28)
## How fast the drain bar catches up, in ratio per second.
@export var drain_speed: float = 0.9
## Hide entirely at full health, so an untouched room is not covered in bars.
@export var hide_when_full: bool = true

var _ratio: float = 1.0
var _drain: float = 1.0
var _frame: ColorRect = null
var _highlight: ColorRect = null

@onready var _background: ColorRect = $Background
@onready var _drain_rect: ColorRect = $Drain
@onready var _fill: ColorRect = $Fill


func _ready() -> void:
	# Frame behind everything (added first, moved to the back of the draw order).
	_frame = ColorRect.new()
	_frame.color = border_colour
	add_child(_frame)
	move_child(_frame, 0)
	# Highlight on top of the fill.
	_highlight = ColorRect.new()
	_highlight.color = highlight_colour
	add_child(_highlight)
	_apply_size()
	_background.color = background_colour
	_drain_rect.color = drain_colour
	_fill.color = fill_colour
	_refresh()


func _apply_size() -> void:
	for rect: ColorRect in [_background, _drain_rect, _fill]:
		rect.position = Vector2(-bar_size.x * 0.5, 0.0)
		rect.size = bar_size
	if _frame != null:
		_frame.position = Vector2(-bar_size.x * 0.5 - border_width, -border_width)
		_frame.size = bar_size + Vector2(border_width, border_width) * 2.0


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
	if _highlight != null:
		# Sits along the top of the live fill, so it shrinks with the bar.
		_highlight.position = Vector2(-bar_size.x * 0.5, 0.0)
		_highlight.size = Vector2(bar_size.x * _ratio, maxf(1.0, bar_size.y * 0.28))
		_highlight.visible = _ratio > 0.02
