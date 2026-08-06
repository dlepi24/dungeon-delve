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


## --- Real controller button art (2026-07-28, Dustin's "improve controller
## art" pass; retires the rounds-7/8 "text glyphs are placeholder" note for
## chips). Face buttons draw as ROUND buttons: Sony shapes are drawn geometry
## in Sony's colours (never a font glyph, so never tofu — same rule as the
## arrows below), Xbox letters keep their letter but wear the official button
## colour. D-pad directions draw as an arrow cap. Everything else (keyboard
## keys, Stick, LB/R1, Menu) stays the text cap. Sentence-style hints all over
## the game keep using Keybinds.hint_for — this path is only for chips, which
## is where an icon has to carry the meaning alone.

## Official-ish button accents, dimmed into the game's palette rather than
## toy-bright: chips sit on parchment cards and the HUD, and pure sRGB primaries
## glow like LEDs there.
const _XBOX_FACE: Dictionary[int, Color] = {
	0: Color(0.45, 0.78, 0.35),   # A green
	1: Color(0.88, 0.32, 0.28),   # B red
	2: Color(0.35, 0.55, 0.92),   # X blue
	3: Color(0.93, 0.78, 0.25),   # Y yellow
}
const _PS_FACE: Dictionary[int, Color] = {
	0: Color(0.55, 0.68, 0.95),   # cross light blue
	1: Color(0.92, 0.40, 0.40),   # circle red
	2: Color(0.90, 0.55, 0.80),   # square pink
	3: Color(0.40, 0.85, 0.65),   # triangle green
}


## Chip size for an action, whatever kind of chip it resolves to. Face and
## D-pad chips are the same square as dir caps, so mixed rows line up.
static func action_size(action: StringName, font_size: int) -> Vector2:
	var info: Dictionary = Keybinds.hint_info(action)
	if info["kind"] == &"key":
		return chip_size(info["text"], font_size)
	return dir_size(font_size)


## Draw the right chip for an action: text cap, round face button, or D-pad
## arrow. Drop-in for draw_chip(hint_for(...)) at every chip call site.
static func draw_action(ci: CanvasItem, action: StringName, font_size: int, at: Vector2, progress: float = -1.0) -> float:
	var info: Dictionary = Keybinds.hint_info(action)
	match info["kind"]:
		&"face":
			return _draw_face(ci, info, font_size, at, progress)
		&"dpad":
			return _draw_dpad(ci, info["dir"] as Vector2, font_size, at)
		&"touch":
			return _draw_touch(ci, info["action"] as StringName, font_size, at, progress)
		_:
			return draw_chip(ci, info["text"] as String, font_size, at, progress)


## Touch chip: a round cap wearing the SAME drawn glyph as the on-screen
## button (TouchGlyphs), so a prompt points at a thing the thumb can find.
## Roll gets the flick chevrons — on touch that verb is a gesture, not a
## button. Hold-to-commit charges as the face buttons' clock sweep.
static func _draw_touch(ci: CanvasItem, action: StringName, font_size: int, at: Vector2, progress: float) -> float:
	var size: Vector2 = dir_size(font_size)
	var centre: Vector2 = at + size * 0.5
	var radius: float = size.x * 0.5
	ci.draw_circle(centre, radius, FILL)
	if progress > 0.0:
		var sweep: PackedVector2Array = PackedVector2Array([centre])
		var steps: int = 24
		for i: int in steps + 1:
			var a: float = -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0) * float(i) / float(steps)
			sweep.append(centre + Vector2.from_angle(a) * (radius - 2.0))
		ci.draw_colored_polygon(sweep, Color(BORDER, 0.40))
	ci.draw_arc(centre, radius, 0.0, TAU, 32, BORDER, 2.0, true)
	if action == &"roll":
		TouchGlyphs.draw_flick(ci, centre, radius * 0.52, TEXT)
	else:
		TouchGlyphs.draw(ci, action, centre, radius * 0.5, TEXT)
	return size.x


static func _draw_face(ci: CanvasItem, info: Dictionary, font_size: int, at: Vector2, progress: float) -> float:
	var size: Vector2 = dir_size(font_size)
	var centre: Vector2 = at + size * 0.5
	var radius: float = size.x * 0.5
	var index: int = info["index"]
	var sony: bool = Keybinds.pad_flavor == &"playstation"
	var accent: Color = (_PS_FACE if sony else _XBOX_FACE).get(index, TEXT)
	ci.draw_circle(centre, radius, FILL)
	# Hold-to-commit fill: a clock sweep from 12 o'clock, same amber wash as the
	# square cap's left→right fill — round chip, round charge.
	if progress > 0.0:
		var sweep: PackedVector2Array = PackedVector2Array([centre])
		var steps: int = 24
		for i: int in steps + 1:
			var a: float = -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0) * float(i) / float(steps)
			sweep.append(centre + Vector2(cos(a), sin(a)) * (radius - 2.0))
		if sweep.size() >= 3:
			ci.draw_colored_polygon(sweep, Color(BORDER, 0.40))
	ci.draw_arc(centre, radius - 1.0, 0.0, TAU, 32, BORDER, 2.0, true)
	if sony:
		_draw_ps_shape(ci, index, centre, radius * 0.5, accent)
	else:
		var letter: String = info["text"]
		var w: float = FONT.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ascent: float = FONT.get_ascent(font_size)
		var descent: float = FONT.get_descent(font_size)
		ci.draw_string(FONT, Vector2(centre.x - w * 0.5, centre.y - (ascent + descent) * 0.5 + ascent),
			letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)
	return size.x


## Sony's shapes as strokes and rings — drawn, so no font can tofu them.
static func _draw_ps_shape(ci: CanvasItem, index: int, centre: Vector2, s: float, accent: Color) -> void:
	const W: float = 2.5
	match index:
		0:  # cross
			ci.draw_line(centre + Vector2(-s, -s), centre + Vector2(s, s), accent, W, true)
			ci.draw_line(centre + Vector2(-s, s), centre + Vector2(s, -s), accent, W, true)
		1:  # circle
			ci.draw_arc(centre, s, 0.0, TAU, 24, accent, W, true)
		2:  # square
			var half: Vector2 = Vector2(s, s) * 0.92
			ci.draw_rect(Rect2(centre - half, half * 2.0), accent, false, W)
		3:  # triangle
			var top: Vector2 = centre + Vector2(0, -s * 1.1)
			var left: Vector2 = centre + Vector2(-s, s * 0.8)
			var right: Vector2 = centre + Vector2(s, s * 0.8)
			ci.draw_line(top, left, accent, W, true)
			ci.draw_line(left, right, accent, W, true)
			ci.draw_line(right, top, accent, W, true)


## A D-pad direction as an arrow cap — any of the four directions, drawn with
## the same geometry as draw_dir's ▲/▼ so stacked prompts stay uniform.
static func _draw_dpad(ci: CanvasItem, dir: Vector2, font_size: int, at: Vector2) -> float:
	var size: Vector2 = dir_size(font_size)
	ci.draw_style_box(_style(), Rect2(at, size))
	var centre: Vector2 = at + size * 0.5
	var r: float = size.x * 0.26
	var side: Vector2 = dir.orthogonal()
	var points: PackedVector2Array = PackedVector2Array([
		centre + dir * r,
		centre - dir * r + side * r * 0.85,
		centre - dir * r - side * r * 0.85,
	])
	ci.draw_colored_polygon(points, TEXT)
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
