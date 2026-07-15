class_name BodyJuice
extends Node2D
## Squash, stretch, spin and flash for a gray-box body.
##
## Purely visual, so it lives entirely in _process — nothing here may ever feed
## back into gameplay, or the determinism the GDD needs for ghost replays is gone.
## Callers request an effect from _physics_process; this node animates it on the
## render frame. A request is a fact ("you were hit"), never a state.
##
## This node is the thing that gets scaled, so it must sit BETWEEN the body and
## the ColorRect. Its origin is the body's origin (the player's feet), which is
## what makes a squash flatten downward instead of sinking into the floor.

## The rect to tint. Flashing lerps its colour rather than using modulate,
## because overbright modulate is not reliable across renderers.
##
## Looked up by name rather than exported on purpose. An exported node reference
## only resolves if the .tscn node header carries
## `node_paths=PackedStringArray("rect")`; hand-written scenes miss that and the
## property silently stays null — which is exactly how every telegraph colour and
## hit flash in this project was dead without a single error. A fixed child does
## not need to be configurable.
@onready var rect: ColorRect = $Visual

@export_group("Feel")
## How fast a flash fades. Higher = snappier.
@export var flash_decay: float = 9.0
@export var flash_colour: Color = Color(1, 1, 1)
## How fast squash/stretch springs back to normal. Higher = snappier.
@export var scale_recover: float = 14.0
## How fast the spin settles back to upright when a roll ends.
@export var spin_recover: float = 18.0

var _base_colour: Color = Color.WHITE
var _flash: float = 0.0
var _held_scale: Vector2 = Vector2.ONE
var _spin: float = 0.0
var _spin_held: bool = false


func _ready() -> void:
	if rect != null:
		_base_colour = rect.color


## The resting colour. The dummy drives this per state, since in gray-box a
## colour is its telegraph.
func set_base_colour(colour: Color) -> void:
	_base_colour = colour


func flash() -> void:
	_flash = 1.0


## Snap to a scale and spring back. For one-off impacts: landing, jumping, hits.
func punch(to: Vector2) -> void:
	scale = to
	_held_scale = Vector2.ONE


## Hold a scale until released. For sustained states like a roll.
func hold_scale(to: Vector2) -> void:
	_held_scale = to


func release_scale() -> void:
	_held_scale = Vector2.ONE


## Absolute spin, in radians. Held until release_spin().
func hold_spin(radians: float) -> void:
	_spin = radians
	_spin_held = true


func release_spin() -> void:
	_spin_held = false


func _process(delta: float) -> void:
	# Draw BEFORE decaying, so a flash always gets at least one visible frame.
	# Decaying first means a single long frame (a hitch, or an uncapped headless
	# loop) can drive _flash to zero before it is ever drawn, and the flash
	# silently never happens.
	if rect != null:
		rect.color = _base_colour.lerp(flash_colour, _flash)
	_flash = move_toward(_flash, 0.0, flash_decay * delta)

	scale = scale.lerp(_held_scale, minf(1.0, scale_recover * delta))

	if _spin_held:
		rotation = _spin
	else:
		rotation = lerp_angle(rotation, 0.0, minf(1.0, spin_recover * delta))
