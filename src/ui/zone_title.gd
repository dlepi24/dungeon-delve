extends CanvasLayer
## The zone announcement: "▼ THE HOT VEIN" across the upper third when the run
## crosses into a new stratum. The Hades/Dead Cells area-card moment — it is
## what turns "room 3 of 6" into "I have descended somewhere new".
##
## Signal-driven off the Events bus and built entirely in code, so dropping the
## node into a run scene is the whole integration. Visual only: it never blocks
## input, and the room underneath is live the entire time.

## Seconds to fade in, hold, and fade out.
@export var fade_in: float = 0.45
@export var hold: float = 2.1
@export var fade_out: float = 0.9
## The card's accent — amber, the one colour the game reserves for "worth
## something". The zone NAME stays parchment-white for readability; only the
## rules and the descent chevron carry the accent.
@export var accent: Color = Color(1.0, 0.83, 0.48)

var _root: VBoxContainer = null
var _name_label: Label = null
var _tagline_label: Label = null
var _rule_left: ColorRect = null
var _rule_right: ColorRect = null
## Lifecycle clock: counts down through fade-in, hold, fade-out. <= 0 = idle.
var _time_left: float = 0.0


func _ready() -> void:
	layer = 12
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.anchor_left = 0.0
	_root.anchor_right = 1.0
	_root.anchor_top = 0.16
	_root.anchor_bottom = 0.16
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	# ▼ chevron: the descent, restated. Small and above the name.
	var chevron: Label = Label.new()
	chevron.text = "▼"
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.add_theme_color_override(&"font_color", accent)
	chevron.add_theme_font_size_override(&"font_size", 18)
	_root.add_child(chevron)

	# Name row: rule — NAME — rule. The rules stretch to frame the name.
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)

	_rule_left = _rule()
	row.add_child(_rule_left)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override(&"font_color", Color(0.96, 0.93, 0.86))
	_name_label.add_theme_font_size_override(&"font_size", 34)
	row.add_child(_name_label)
	_rule_right = _rule()
	row.add_child(_rule_right)

	_tagline_label = Label.new()
	_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline_label.add_theme_color_override(&"font_color", Color(0.75, 0.72, 0.66, 0.9))
	_tagline_label.add_theme_font_size_override(&"font_size", 15)
	_root.add_child(_tagline_label)

	Events.zone_entered.connect(_on_zone_entered)


func _rule() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(accent.r, accent.g, accent.b, 0.55)
	rect.custom_minimum_size = Vector2(90, 2)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _on_zone_entered(zone: ZoneData) -> void:
	# Letter-spaced smallcaps treatment: cheap, and it reads as a title rather
	# than a debug string.
	var spaced: PackedStringArray = PackedStringArray()
	for ch: String in zone.display_name.to_upper():
		spaced.append(ch)
	_name_label.text = " ".join(spaced)
	_tagline_label.text = zone.tagline
	_time_left = fade_in + hold + fade_out


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	# Draw THEN decay (see CLAUDE.md): apply this frame's alpha before ticking
	# the clock, so one long frame cannot swallow the card.
	var elapsed: float = (fade_in + hold + fade_out) - _time_left
	var alpha: float = 1.0
	if elapsed < fade_in:
		alpha = elapsed / maxf(0.01, fade_in)
	elif _time_left < fade_out:
		alpha = _time_left / maxf(0.01, fade_out)
	_root.modulate.a = clampf(alpha, 0.0, 1.0)
	_time_left -= delta
	if _time_left <= 0.0:
		_root.modulate.a = 0.0
