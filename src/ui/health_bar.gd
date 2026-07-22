class_name HealthBar
extends Node2D
## v4: segmented, colour-shifting health gauge. Player HUD and enemy overhead
## bars share it.
##
## Three readability layers, cheapest first:
##  - COLOUR is the glance read: the fill lerps green -> yellow -> orange ->
##    red as health falls, so "am I in trouble" needs zero arithmetic.
##  - SEGMENTS are the count read: one notch per segment_hp makes "two chunks
##    left" legible mid-fight. Enemy bars keep segment_hp = 0 and stay clean.
##  - The DRAIN is the event read: a dark-red bar chases the fill at
##    drain_speed, so the size of the last hit is visible as a sliver.
##
## v4 draws everything itself in _draw() — the ColorRect children the old
## .tscn carries are freed on ready, so the scene file needs no edit.

@export var bar_size: Vector2 = Vector2(46, 6)
@export var drain_colour: Color = Color(0.66, 0.13, 0.10)
@export var background_colour: Color = Color(0.06, 0.05, 0.04, 0.9)
@export var border_colour: Color = Color(0.09, 0.07, 0.05, 0.95)
@export var border_width: float = 2.0
## The one-pixel light lip along the top of the fill.
@export var highlight_colour: Color = Color(1, 1, 1, 0.28)
## How fast the drain bar catches up, in ratio per second.
@export var drain_speed: float = 0.9
@export var hide_when_full: bool = true
## HP per segment notch. 0 = no notches (the tiny enemy bars). The player HUD
## sets 25.0, so a max-health boon visibly adds notches.
@export var segment_hp: float = 0.0
## Owner keeps this current when segment_hp > 0 (hud.gd, every frame).
@export var max_health: float = 100.0
## Below this ratio the fill pulses. 0 disables (enemy bars).
@export var low_pulse_below: float = 0.0

## Colour stops, (ratio, colour), low to high. Piecewise-lerped; the greens
## hold a plateau at the top so full-ish health doesn't read as "damaged".
const STOPS: Array = [
	[0.00, Color(0.80, 0.16, 0.12)],
	[0.30, Color(0.90, 0.45, 0.12)],
	[0.55, Color(0.93, 0.79, 0.22)],
	[0.80, Color(0.55, 0.80, 0.30)],
	[1.00, Color(0.40, 0.82, 0.38)],
]

var _ratio: float = 1.0
var _drain: float = 1.0
var _pulse_t: float = 0.0


func _ready() -> void:
	# The old scene's Background/Drain/Fill ColorRects are obsolete.
	for child: Node in get_children():
		child.queue_free()
	_apply_visibility()
	queue_redraw()


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	# Healing snaps both, or the drain would sit below the fill and read as
	# damage.
	if _ratio > _drain:
		_drain = _ratio
	_apply_visibility()
	queue_redraw()


func _process(delta: float) -> void:
	if _drain > _ratio:
		_drain = maxf(_ratio, _drain - drain_speed * delta)
		queue_redraw()
	if low_pulse_below > 0.0 and _ratio > 0.0 and _ratio <= low_pulse_below:
		_pulse_t = fmod(_pulse_t + delta * 2.6, TAU)
		queue_redraw()


func _apply_visibility() -> void:
	visible = not (hide_when_full and is_equal_approx(_ratio, 1.0) and is_equal_approx(_drain, 1.0))


static func health_colour(ratio: float) -> Color:
	ratio = clampf(ratio, 0.0, 1.0)
	for i: int in range(1, STOPS.size()):
		if ratio <= STOPS[i][0]:
			var lo: Array = STOPS[i - 1]
			var hi: Array = STOPS[i]
			var t: float = (ratio - lo[0]) / maxf(0.0001, hi[0] - lo[0])
			return (lo[1] as Color).lerp(hi[1], t)
	return STOPS[-1][1]


func _draw() -> void:
	var origin: Vector2 = Vector2(-bar_size.x * 0.5, 0.0)
	if border_width > 0.0:
		draw_rect(Rect2(origin - Vector2(border_width, border_width),
				bar_size + Vector2(border_width, border_width) * 2.0), border_colour)
	draw_rect(Rect2(origin, bar_size), background_colour)
	if _drain > 0.0:
		draw_rect(Rect2(origin, Vector2(bar_size.x * _drain, bar_size.y)), drain_colour)
	if _ratio > 0.0:
		var fill: Color = health_colour(_ratio)
		if low_pulse_below > 0.0 and _ratio <= low_pulse_below:
			fill = fill.lightened(0.18 + 0.18 * sin(_pulse_t))
		draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, bar_size.y)), fill)
		draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, maxf(1.0, bar_size.y * 0.22))),
				highlight_colour)
	# Notches LAST, over fill and background alike, so the total capacity is
	# always countable — including the empty chunks you could heal back.
	if segment_hp > 0.0 and max_health > segment_hp:
		var notch_w: float = maxf(1.0, roundf(bar_size.y / 8.0))
		var count: int = int(ceilf(max_health / segment_hp))
		for i: int in range(1, count):
			var fx: float = bar_size.x * clampf(float(i) * segment_hp / max_health, 0.0, 1.0)
			draw_rect(Rect2(origin + Vector2(fx - notch_w * 0.5, 0.0),
					Vector2(notch_w, bar_size.y)), Color(border_colour, 0.8))
