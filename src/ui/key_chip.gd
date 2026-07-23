class_name KeyChip
extends RefCounted
## The single "press this" cap that every prompt in the game shows, so a keyboard
## key and a pad glyph read as the SAME object no matter where they appear. It
## draws onto any CanvasItem — a Node2D world prompt or a Control HUD panel — via
## the shared draw_* API, which is what actually keeps the buttons uniform: there
## is one place that decides what a key looks like, and this is it.
##
## Visual only. The glyph string comes from Keybinds (device-aware); this class
## just draws whatever text it is handed inside a cap.

const FONT: FontFile = preload("res://assets/fonts/Rajdhani-Bold.ttf")

## Cap padding around the glyph, and the mine's panel colours (amber cap on dark
## ground — the same accent the theme's live buttons wear).
const PAD_X: float = 9.0
const PAD_Y: float = 4.0
const FILL: Color = Color(0.05, 0.04, 0.03, 0.98)
const BORDER: Color = Color(1.0, 0.82, 0.4, 1.0)
const TEXT: Color = Color(1.0, 0.93, 0.74, 1.0)

# Lazily built and cached — a StyleBoxFlat cannot be a const, and rebuilding one
# per draw call would churn allocations on every prompt every frame.
static var _box: StyleBoxFlat = null


static func _style() -> StyleBoxFlat:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.bg_color = FILL
		_box.border_color = BORDER
		_box.set_border_width_all(2)
		_box.set_corner_radius_all(4)
	return _box


## The cap's drawn size for a glyph. Single letters are forced to a square (min
## width = height) so "A" reads as a key rather than a sliver, while "Menu" or
## "R1" grow to fit.
static func chip_size(glyph: String, font_size: int) -> Vector2:
	var text_w: float = FONT.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var h: float = float(font_size) + PAD_Y * 2.0
	var w: float = maxf(text_w + PAD_X * 2.0, h)
	return Vector2(w, h)


## Draw a cap with its TOP-LEFT at `at` on `ci`; returns the cap width so the
## caller can lay out whatever follows it. `progress` >= 0 draws a hold-to-interact
## fill — an amber wash rising left→right inside the cap as the player holds — so
## a "Hold to Take" chip visibly commits. A negative value (the default) is a
## plain press cap and draws no fill.
static func draw_chip(ci: CanvasItem, glyph: String, font_size: int, at: Vector2, progress: float = -1.0) -> float:
	var size: Vector2 = chip_size(glyph, font_size)
	ci.draw_style_box(_style(), Rect2(at, size))
	# Fill goes UNDER the glyph so the letter stays legible as the cap charges.
	if progress >= 0.0:
		var inset: float = 2.0
		var fill_w: float = maxf(0.0, (size.x - inset * 2.0) * clampf(progress, 0.0, 1.0))
		if fill_w > 0.0:
			ci.draw_rect(Rect2(at + Vector2(inset, inset), Vector2(fill_w, size.y - inset * 2.0)),
				Color(BORDER, 0.40))
	var text_w: float = FONT.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent: float = FONT.get_ascent(font_size)
	var descent: float = FONT.get_descent(font_size)
	var text_pos: Vector2 = Vector2(
		at.x + (size.x - text_w) * 0.5,
		at.y + (size.y - (ascent + descent)) * 0.5 + ascent,
	)
	ci.draw_string(FONT, text_pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)
	return size.x


## A directional cap (a square key with a drawn ▲/▼ inside it). Used for the
## mine's up/down verbs, where W/S, the D-pad and the stick ALL do the same
## thing — so the honest icon is an arrow, not any one device's key. The
## triangle is drawn, not a font glyph, so it can never tofu on a missing
## codepoint. Same square size for up and down so a stacked pair lines up.
static func dir_size(font_size: int) -> Vector2:
	var h: float = float(font_size) + PAD_Y * 2.0
	return Vector2(h, h)


## Draw a direction cap with its TOP-LEFT at `at`; `up` picks ▲ vs ▼. Returns width.
static func draw_dir(ci: CanvasItem, up: bool, font_size: int, at: Vector2) -> float:
	var size: Vector2 = dir_size(font_size)
	ci.draw_style_box(_style(), Rect2(at, size))
	var cx: float = at.x + size.x * 0.5
	var cy: float = at.y + size.y * 0.5
	var r: float = size.x * 0.26
	var points: PackedVector2Array
	if up:
		points = PackedVector2Array([
			Vector2(cx, cy - r), Vector2(cx - r, cy + r * 0.85), Vector2(cx + r, cy + r * 0.85),
		])
	else:
		points = PackedVector2Array([
			Vector2(cx, cy + r), Vector2(cx - r, cy - r * 0.85), Vector2(cx + r, cy - r * 0.85),
		])
	ci.draw_colored_polygon(points, TEXT)
	return size.x
