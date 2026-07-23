extends Control
## "The First Descent" opening crawl — the story frame the mechanics tutorial
## doesn't give: why the mine, why you go down, what is waiting below. This is
## pure narrative, so it is a cinematic full-screen card rather than a diegetic
## WorldPrompt — there is no verb to teach yet, and the diegetic-card ethos is
## about TEACHING, not framing. Skippable, and first-run-gated upstream: the
## title routes fresh players here, everyone else straight to the hub.
##
## Pacing (Dustin's call): it AUTO-ADVANCES on a timer so the player can just
## read, after one press to begin (nobody wants a crawl playing to an empty
## room). A press or click still jumps ahead early, and Esc/B skips the lot.
##
## The copy lives in an @export so the lore can be rewritten in the inspector
## without touching flow. On the last beat (or a skip) it hands to the mechanics
## tutorial, which is what sets intro_seen when its own finale extracts — so
## bailing before then correctly replays the whole onboarding.

const TUTORIAL_SCENE: String = "res://src/rooms/tutorial_run.tscn"

## The crawl, one beat per card. Flow does not care how many — rewrite, add or
## cut freely. Names stay out on purpose (GDD open question 5).
@export var beats: PackedStringArray = [
	"The district's veins ran deeper than any map dared follow.",
	"So the crews went down. Shift after shift, chasing ore that paid richer the deeper it lay.",
	"Then the deep shafts went quiet. No whistle. No lift. Nobody came back up.",
	"They are still down there. Hollow now, lantern-eyed — still swinging the tools they died holding.",
	"The ore is still down there too. Enough to be worth the long walk into the dark.",
	"You have a pick, a lamp, and one rule the mine respects: come up before it keeps you.",
]
## Seconds a beat lingers before auto-advancing (on top of the fade-in). The knob
## to turn if the crawl reads too fast or too slow.
@export var hold_time: float = 3.6
## Seconds for a beat to fade in; the fade-out on advance is quicker.
@export var fade_time: float = 0.6

var _index: int = 0
var _started: bool = false
var _advancing: bool = false
var _finishing: bool = false
var _text: Label = null
var _heading: Label = null
var _hint: Label = null
var _auto: Tween = null


func _ready() -> void:
	Cursor.menu()
	# The title's calm hub bed carries in through the Music autoload; keep it.
	# The delve track belongs to the tutorial, which starts it on entry.
	_build_ui()
	_show_start()


## Full-screen dark ground, a title, the beat text at reading size, and a
## device-aware prompt line. Built in code so the scene file stays a one-node
## stub; this is the top-level Control, so the "Control-under-Control collapses"
## trap does not apply. Labels ignore the mouse so a click falls through to
## _unhandled_input as an advance.
func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.028, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_heading = Label.new()
	_heading.text = "THE FIRST DESCENT"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_heading.offset_top = 130.0
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading.add_theme_font_size_override(&"font_size", 26)
	_heading.add_theme_color_override(&"font_color", Color(0.62, 0.52, 0.38, 0.8))
	add_child(_heading)

	# A fixed, centred measure so long and short beats sit in the same place.
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.set_anchors_preset(Control.PRESET_CENTER)
	_text.offset_left = -440.0
	_text.offset_right = 440.0
	_text.offset_top = -110.0
	_text.offset_bottom = 110.0
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override(&"font_size", 30)
	_text.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.72))
	_text.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_text.add_theme_constant_override(&"outline_size", 6)
	add_child(_text)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -96.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override(&"font_size", 16)
	_hint.add_theme_color_override(&"font_color", Color(0.7, 0.62, 0.5, 0.85))
	add_child(_hint)
	# The advance glyph follows whichever device is driving, like every other hint.
	Keybinds.input_device_changed.connect(_refresh_hint)


## The opening card: title held, waiting for the one press that starts the crawl.
func _show_start() -> void:
	_heading.visible = true
	_text.text = "Press to begin."
	_text.modulate.a = 1.0
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _started:
		_hint.text = "%s / click  next        Esc / B  skip" % Keybinds.hint_for(&"interact")
	else:
		_hint.text = "%s / click  begin        Esc / B  skip" % Keybinds.hint_for(&"interact")


func _begin_crawl() -> void:
	_started = true
	_heading.visible = false
	_refresh_hint()
	_play_beat(0)


## Show a beat, then auto-advance after it has been up for hold_time. The whole
## chain lives in one tween so a manual advance can cancel it cleanly.
func _play_beat(i: int) -> void:
	_index = i
	_text.text = beats[i] if i < beats.size() else ""
	_text.modulate.a = 0.0
	_kill_auto()
	_auto = create_tween()
	_auto.tween_property(_text, "modulate:a", 1.0, fade_time)
	_auto.tween_interval(hold_time)
	_auto.tween_callback(_advance)


## Advance to the next beat (or finish). Called by the auto timer AND by a manual
## press/click; _advancing guards the fade-out from being re-entered mid-swap.
func _advance() -> void:
	if not _started or _advancing or _finishing:
		return
	_kill_auto()
	if _index + 1 >= beats.size():
		_finish()
		return
	_advancing = true
	var tween: Tween = create_tween()
	tween.tween_property(_text, "modulate:a", 0.0, fade_time * 0.5)
	tween.tween_callback(func() -> void:
		_advancing = false
		_play_beat(_index + 1))


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_kill_auto()
	get_tree().change_scene_to_file.call_deferred(TUTORIAL_SCENE)


func _kill_auto() -> void:
	if _auto != null and _auto.is_valid():
		_auto.kill()
	_auto = null


## Esc/B skips the whole crawl straight to the tutorial (the mechanics are not
## skippable, only the story). Otherwise the engage button, Space, or a left
## click either begins the crawl or jumps to the next beat.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	var press: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") \
			or event.is_action_pressed(&"ui_accept")
	var click: bool = event is InputEventMouseButton and event.is_pressed() \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not (press or click):
		return
	get_viewport().set_input_as_handled()
	if _started:
		_advance()
	else:
		_begin_crawl()
