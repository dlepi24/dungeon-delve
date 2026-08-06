class_name TouchGlyphs
extends RefCounted
## The touch control language, drawn: one glyph per verb, geometry only (same
## tofu-proofing rule as KeyChip's pad shapes). Shared by the on-screen buttons
## (TouchControls) and the prompt chips (KeyChip's touch mode), so a tutorial
## card saying "press [glyph]" shows exactly the button the thumb knows.


## Draw the glyph for `action` centred at `at`, sized by `s` (roughly half the
## glyph's extent). Unknown actions draw nothing.
static func draw(ci: CanvasItem, action: StringName, at: Vector2, s: float, col: Color) -> void:
	match action:
		&"jump":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -s), at + Vector2(s, s * 0.7), at + Vector2(-s, s * 0.7)]), col)
		&"attack":
			# A pick: diagonal haft with a curved head across the top.
			ci.draw_line(at + Vector2(-s * 0.7, s), at + Vector2(s * 0.6, -s * 0.6), col, 5.0, true)
			ci.draw_arc(at + Vector2(0.1 * s, 0.1 * s), s * 1.05, -PI * 0.82, -PI * 0.18, 16, col, 5.0, true)
		&"roll":
			# Open circle with an arrowhead: a tumble.
			ci.draw_arc(at, s * 0.85, -PI * 0.25, PI * 1.3, 24, col, 5.0, true)
			var tip: Vector2 = at + Vector2.from_angle(PI * 1.3) * s * 0.85
			ci.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-s * 0.32, -s * 0.1), tip + Vector2(s * 0.28, -s * 0.34), tip + Vector2(s * 0.18, s * 0.3)]), col)
		&"parry":
			# A shield.
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-s, -s * 0.8), at + Vector2(s, -s * 0.8), at + Vector2(s, s * 0.1),
				at + Vector2(0, s), at + Vector2(-s, s * 0.1)]), Color(col, col.a * 0.35))
			ci.draw_polyline(PackedVector2Array([
				at + Vector2(-s, -s * 0.8), at + Vector2(s, -s * 0.8), at + Vector2(s, s * 0.1),
				at + Vector2(0, s), at + Vector2(-s, s * 0.1), at + Vector2(-s, -s * 0.8)]), col, 4.0, true)
		&"skill_2":
			# The hook: a drop line into an upturned J.
			ci.draw_line(at + Vector2(s * 0.3, -s), at + Vector2(s * 0.3, s * 0.2), col, 5.0, true)
			ci.draw_arc(at + Vector2(-s * 0.15, s * 0.2), s * 0.45, 0.0, PI, 12, col, 5.0, true)
		&"skill_1":
			# Two slots trading places.
			ci.draw_rect(Rect2(at + Vector2(-s, -s * 0.9), Vector2(s * 1.1, s * 1.1)), col, false, 4.0)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.1, -s * 0.2), Vector2(s * 1.1, s * 1.1)), col, false, 4.0)
		&"pause":
			ci.draw_rect(Rect2(at + Vector2(-s * 0.7, -s), Vector2(s * 0.45, s * 2.0)), col)
			ci.draw_rect(Rect2(at + Vector2(s * 0.25, -s), Vector2(s * 0.45, s * 2.0)), col)
		&"interact":
			# A tap: fingertip dot under two ripple arcs.
			ci.draw_circle(at + Vector2(0, s * 0.35), s * 0.42, col)
			ci.draw_arc(at + Vector2(0, s * 0.35), s * 0.75, -PI * 0.85, -PI * 0.15, 12, col, 3.5, true)
			ci.draw_arc(at + Vector2(0, s * 0.35), s * 1.1, -PI * 0.8, -PI * 0.2, 12, Color(col, col.a * 0.6), 3.0, true)


## The flick gesture (roll on touch): opposed chevrons, "snap it sideways".
static func draw_flick(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var tip_x: float = at.x + side * s
		ci.draw_polyline(PackedVector2Array([
			Vector2(tip_x - side * s * 0.55, at.y - s * 0.55),
			Vector2(tip_x, at.y),
			Vector2(tip_x - side * s * 0.55, at.y + s * 0.55)]), col, 3.5, true)
	ci.draw_circle(at, s * 0.22, col)
