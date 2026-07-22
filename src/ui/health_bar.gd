class_name HealthBar
extends Node2D
## v5: a chunky SEGMENTED gauge for the player (beat-em-up style — Streets of
## Rage / TMNT), and the thin continuous bar for enemy overhead health.
##
## PLAYER MODE (segment_hp > 0): the bar is a ROW OF BIG CELLS, one per
## segment_hp. A max-health boon adds whole cells, so the bar visibly GROWS —
## "I have more health now" reads at a glance without a number. Filled cells
## take the health colour (green -> yellow -> orange -> red with total health);
## a hit leaves a dim drain sliver in the cell it emptied; below low_pulse_below
## the fill pulses. Drawn left-aligned so it grows to the right.
##
## ENEMY MODE (segment_hp == 0): the old thin, centred bar. Unchanged.
##
## v5 draws everything in _draw(); the ColorRect children the old .tscn carries
## are freed on ready, so the scene file needs no edit.

@export var bar_size: Vector2 = Vector2(46, 6)
@export var drain_colour: Color = Color(0.66, 0.13, 0.10)
@export var background_colour: Color = Color(0.06, 0.05, 0.04, 0.9)
@export var border_colour: Color = Color(0.09, 0.07, 0.05, 0.95)
@export var border_width: float = 2.0
## The light lip along the top of the fill — reads the cell as a lit surface.
@export var highlight_colour: Color = Color(1, 1, 1, 0.28)
## How fast the drain bar catches up, in ratio per second.
@export var drain_speed: float = 0.9
@export var hide_when_full: bool = true
## HP per cell. 0 = the thin enemy bar (no cells). The player HUD sets 25.
@export var segment_hp: float = 0.0
## Owner keeps this current when segment_hp > 0 (hud.gd, every frame) so a
## max-health boon adds cells live.
@export var max_health: float = 100.0
## Below this ratio the fill pulses. 0 disables (enemy bars).
@export var low_pulse_below: float = 0.0
## One chunky cell, player mode. Big on purpose — glance readability.
@export var cell_size: Vector2 = Vector2(24, 26)
@export var cell_gap: float = 4.0

## Colour stops, (ratio, colour), low to high. The greens hold a plateau at the
## top so full-ish health doesn't read as "damaged".
const STOPS: Array = [
	[0.00, Color(0.82, 0.17, 0.13)],
	[0.30, Color(0.92, 0.46, 0.13)],
	[0.55, Color(0.95, 0.80, 0.24)],
	[0.80, Color(0.50, 0.82, 0.32)],
	[1.00, Color(0.36, 0.84, 0.40)],
]

var _ratio: float = 1.0
var _drain: float = 1.0
var _pulse_t: float = 0.0


func _ready() -> void:
	for child: Node in get_children():
		child.queue_free()
	_apply_visibility()
	queue_redraw()


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	if _ratio > _drain:  # healing snaps both, or the drain reads as damage
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


## Total drawn width of the player bar (cells + gaps), so the HUD can lay out
## whatever sits to the right of it.
func segmented_width() -> float:
	var count: int = maxi(1, roundi(max_health / maxf(1.0, segment_hp)))
	return float(count) * cell_size.x + float(count - 1) * cell_gap


func _draw() -> void:
	if segment_hp > 0.0:
		_draw_segmented()
	else:
		_draw_continuous()


## The beat-em-up bar: N big cells growing right from the origin. Each cell is
## framed, empty-dark, then filled from the left by that cell's share of health.
func _draw_segmented() -> void:
	var count: int = maxi(1, roundi(max_health / maxf(1.0, segment_hp)))
	var cw: float = cell_size.x
	var ch: float = cell_size.y
	var fill: Color = health_colour(_ratio)
	if low_pulse_below > 0.0 and _ratio <= low_pulse_below:
		fill = fill.lightened(0.16 + 0.16 * sin(_pulse_t))
	for i: int in count:
		var x: float = float(i) * (cw + cell_gap)
		# Frame, then recessed empty cell.
		if border_width > 0.0:
			draw_rect(Rect2(x - border_width, -border_width,
					cw + border_width * 2.0, ch + border_width * 2.0), border_colour)
		draw_rect(Rect2(x, 0.0, cw, ch), background_colour)
		# This cell's slice of the 0..1 range.
		var lo: float = float(i) / float(count)
		var span: float = 1.0 / float(count)
		var drain_frac: float = clampf((_drain - lo) / span, 0.0, 1.0)
		if drain_frac > 0.0:
			draw_rect(Rect2(x, 0.0, cw * drain_frac, ch), drain_colour)
		var fill_frac: float = clampf((_ratio - lo) / span, 0.0, 1.0)
		if fill_frac > 0.0:
			draw_rect(Rect2(x, 0.0, cw * fill_frac, ch), fill)
			draw_rect(Rect2(x, 0.0, cw * fill_frac, maxf(2.0, ch * 0.26)), highlight_colour)


## The thin enemy bar: one continuous fill, centred on the origin.
func _draw_continuous() -> void:
	var origin: Vector2 = Vector2(-bar_size.x * 0.5, 0.0)
	if border_width > 0.0:
		draw_rect(Rect2(origin - Vector2(border_width, border_width),
				bar_size + Vector2(border_width, border_width) * 2.0), border_colour)
	draw_rect(Rect2(origin, bar_size), background_colour)
	if _drain > 0.0:
		draw_rect(Rect2(origin, Vector2(bar_size.x * _drain, bar_size.y)), drain_colour)
	if _ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, bar_size.y)), health_colour(_ratio))
		draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, maxf(1.0, bar_size.y * 0.22))),
				highlight_colour)
