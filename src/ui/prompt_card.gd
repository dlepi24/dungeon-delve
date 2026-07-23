class_name PromptCard
extends RefCounted
## The one renderer behind every interaction prompt in the game: a warm-dark
## panel holding an optional title + flavour line and one or more rows, where
## each row is a KeyChip (an action key, or a ↑/↓ direction arrow) beside a
## label. It draws onto ANY CanvasItem, so a world prompt (Node2D floating over
## a building) and the extract banner (a fixed HUD Control) render identically —
## that shared draw path is what actually keeps every prompt uniform.
##
## Rows are plain dictionaries built by the helpers below. Action glyphs resolve
## at DRAW time via Keybinds, so a keyboard↔pad swap just needs a redraw, never
## a rebuild. Visual only — nothing here ticks gameplay or reads the seeded Rng.

const FONT_BODY: FontFile = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/Rajdhani-Bold.ttf")

const CHIP_FS: int = 18
const TITLE_FS: int = 22
const SUB_FS: int = 16
const ROW_FS: int = 19

const PAD_X: float = 15.0
const PAD_Y: float = 11.0
const CHIP_GAP: float = 11.0
const ROW_GAP: float = 7.0
const TITLE_GAP: float = 5.0
const SUB_GAP: float = 8.0

const TITLE_COL: Color = Color(1.0, 0.92, 0.78, 1.0)
const SUB_COL: Color = Color(0.72, 0.66, 0.56, 1.0)
const ROW_COL: Color = Color(0.95, 0.91, 0.83, 1.0)
const GATED_COL: Color = Color(0.62, 0.55, 0.48, 1.0)

static var _panel: StyleBoxFlat = null
static var _shadow: StyleBoxFlat = null


# --- Row constructors: build these, hand an Array of them to draw()/measure(). ---

## A "press this key" row (interact → F / A / X, resolved per device).
static func action_row(action: StringName, label: String) -> Dictionary:
	return {"kind": &"action", "action": action, "label": label}

## A "hold this key" row for a consequential action (weapon swap, shrine bargain).
## Renders like an action row but the chip fills as `progress` (0..1) climbs, so
## the player watches the commitment build. See HoldInteract.
static func hold_row(action: StringName, label: String, progress: float) -> Dictionary:
	return {"kind": &"hold", "action": action, "label": label, "progress": progress}

## A "push the stick / key this way" row, shown as a ▲/▼ arrow.
static func dir_row(up: bool, label: String) -> Dictionary:
	return {"kind": &"dir", "up": up, "label": label}

## A greyed, chip-less row for a choice the player cannot take yet (e.g. can't
## afford the bargain). Reserves the chip column so its label still lines up.
static func gated_row(label: String) -> Dictionary:
	return {"kind": &"gated", "label": label}


static func _chip_width(row: Dictionary) -> float:
	if row["kind"] == &"action" or row["kind"] == &"hold":
		return KeyChip.chip_size(Keybinds.hint_for(row["action"]), CHIP_FS).x
	return KeyChip.dir_size(CHIP_FS).x


static func _label_width(row: Dictionary) -> float:
	return FONT_BODY.get_string_size(row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x


## The card's drawn size for this content, so a caller can place it (centre it
## over a building, or bottom-centre it on screen) before drawing.
static func measure(title: String, subtitle: String, rows: Array) -> Vector2:
	var chip_col: float = 0.0
	for row: Dictionary in rows:
		chip_col = maxf(chip_col, _chip_width(row))
	var content_w: float = 0.0
	if title != "":
		content_w = maxf(content_w, FONT_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS).x)
	if subtitle != "":
		content_w = maxf(content_w, FONT_BODY.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_FS).x)
	for row: Dictionary in rows:
		content_w = maxf(content_w, chip_col + CHIP_GAP + _label_width(row))
	var content_h: float = 0.0
	if title != "":
		content_h += float(TITLE_FS) + TITLE_GAP
	if subtitle != "":
		content_h += float(SUB_FS) + SUB_GAP
	var row_h: float = KeyChip.dir_size(CHIP_FS).y
	for i: int in rows.size():
		content_h += row_h
		if i < rows.size() - 1:
			content_h += ROW_GAP
	return Vector2(content_w + PAD_X * 2.0, content_h + PAD_Y * 2.0)


## Draw the whole card with its TOP-LEFT at `at`. Returns the drawn size.
static func draw(ci: CanvasItem, at: Vector2, title: String, subtitle: String, rows: Array) -> Vector2:
	var size: Vector2 = measure(title, subtitle, rows)
	ci.draw_style_box(_shadow_box(), Rect2(at + Vector2(3.0, 5.0), size))
	ci.draw_style_box(_panel_box(), Rect2(at, size))

	var x: float = at.x + PAD_X
	var y: float = at.y + PAD_Y
	if title != "":
		ci.draw_string(FONT_BOLD, Vector2(x, y + FONT_BOLD.get_ascent(TITLE_FS)), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS, TITLE_COL)
		y += float(TITLE_FS) + TITLE_GAP
	if subtitle != "":
		ci.draw_string(FONT_BODY, Vector2(x, y + FONT_BODY.get_ascent(SUB_FS)), subtitle,
			HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_FS, SUB_COL)
		y += float(SUB_FS) + SUB_GAP

	var chip_col: float = 0.0
	for row: Dictionary in rows:
		chip_col = maxf(chip_col, _chip_width(row))
	var row_h: float = KeyChip.dir_size(CHIP_FS).y
	for row: Dictionary in rows:
		if row["kind"] == &"action":
			KeyChip.draw_chip(ci, Keybinds.hint_for(row["action"]), CHIP_FS, Vector2(x, y))
		elif row["kind"] == &"hold":
			KeyChip.draw_chip(ci, Keybinds.hint_for(row["action"]), CHIP_FS, Vector2(x, y), row["progress"])
		elif row["kind"] == &"dir":
			KeyChip.draw_dir(ci, row["up"], CHIP_FS, Vector2(x, y))
		var colour: Color = GATED_COL if row["kind"] == &"gated" else ROW_COL
		var baseline: float = y + (row_h - (FONT_BODY.get_ascent(ROW_FS) + FONT_BODY.get_descent(ROW_FS))) * 0.5 + FONT_BODY.get_ascent(ROW_FS)
		ci.draw_string(FONT_BODY, Vector2(x + chip_col + CHIP_GAP, baseline), row["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, colour)
		y += row_h + ROW_GAP
	return size


## The mine's panel voice — warm-dark ground, timber border, rounded — shared
## with the theme's buttons so a world prompt and a menu button feel like one game.
static func _panel_box() -> StyleBoxFlat:
	if _panel == null:
		_panel = StyleBoxFlat.new()
		_panel.bg_color = Color(0.09, 0.075, 0.06, 0.96)
		_panel.border_color = Color(0.4, 0.33, 0.22, 1.0)
		_panel.set_border_width_all(2)
		_panel.set_corner_radius_all(6)
	return _panel


static func _shadow_box() -> StyleBoxFlat:
	if _shadow == null:
		_shadow = StyleBoxFlat.new()
		_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.35)
		_shadow.set_corner_radius_all(6)
	return _shadow
