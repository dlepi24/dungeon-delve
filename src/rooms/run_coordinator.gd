extends Node
## Owns the flow of a live delve run: the extract/descend choice at each exit,
## and what happens on death. Everything that turns a sequence of rooms into a
## RUN with stakes lives here, so the Delve stays a pure assembler and the Player
## stays pure combat.
##
## The greed decision (GDD, locked 2026-07-15): at a room's exit, UP extracts
## (bank carried haul, end the run safe) and DOWN descends (deeper, richer,
## deadlier). Death loses all carried haul. Up/down maps to the mine — surface is
## up, ore is down — so it needs no tutorial.
##
## Death and extraction both pass through a result screen, so the outcome (what
## you lost, what you banked) is legible before the hub — without it a death read
## as a silent bug.

const HUB_SCENE: String = "res://src/hub/hub.tscn"

@export var delve: Delve
## Bonus fraction of carried haul for clearing ALL rooms rather than banking
## early. The full-clear premium: greed's ceiling should out-pay caution's
## floor, or the descend choice stops mattering once your bag is full.
@export_range(0.0, 2.0) var clear_bonus_fraction: float = 0.5
## How far below the music bed the delve sits — the quietest context, so the
## combat SFX own the foreground.
@export var music_attenuation_db: float = -8.0

var _at_exit: bool = false
var _ending: bool = false

# The extract/descend card floats in the WORLD, above the current room's exit
# door — same WorldPrompt as the shops and shrines. Built in code and parented
# to the Delve (world space) so it rides the camera and survives room swaps.
var _prompt: WorldPrompt = null

@onready var _result: CanvasLayer = $ResultScreen
@onready var _doors: CanvasLayer = $DoorChoice


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.delve_completed.connect(_on_delve_completed)
	_prompt = WorldPrompt.new()
	# Clear the door beacon's glow before the card starts.
	_prompt.lift = 30.0
	# The run-ending choice outranks any other card sharing the screen.
	_prompt.priority = 30
	delve.add_child(_prompt)
	_result.dismissed.connect(_to_hub)
	_doors.chosen.connect(func(index: int) -> void: delve.descend(index))
	Cursor.gameplay()
	Music.play(&"delve", music_attenuation_db)
	# Keyboard-vs-pad can change while standing at an exit; the prompt follows.
	Keybinds.input_device_changed.connect(func() -> void:
		if _at_exit and not _ending:
			_refresh_prompt())


func _physics_process(_delta: float) -> void:
	if _ending or delve == null:
		return
	var at: bool = delve.player_at_exit()
	if at != _at_exit:
		_at_exit = at
		if at:
			_place_prompt_at_exit()
			_refresh_prompt()
			_prompt.show_prompt()
		else:
			_prompt.hide_prompt()


## Park the card above the current room's exit door (the glowing shaft rises
## exit_size.y above the marker; the card floats just over its top).
func _place_prompt_at_exit() -> void:
	var room: Room = delve.current_room()
	if room == null:
		return
	_prompt.global_position = room.exit_marker.global_position - Vector2(0.0, room.exit_size.y)


func _refresh_prompt() -> void:
	# Crossing a stratum should be felt AT the door: name where down leads when
	# it leads somewhere new. Same-zone descents stay terse.
	var descend_line: String = "Descend deeper"
	var here: ZoneData = delve.current_zone()
	var below: ZoneData = delve.next_zone()
	if below != null and here != null and below != here:
		descend_line = "Descend — into %s" % below.display_name
	_prompt.set_card("", "", [
		PromptCard.dir_row(true, "Extract to surface — bank %d ore" % GameState.carried_haul),
		PromptCard.dir_row(false, descend_line),
	])


## Runtime input, handled here rather than in _physics_process so the press
## timing is reliable — the physics-frame just_pressed gotcha (see CLAUDE.md)
## only bites synthetic input, but _unhandled_input sidesteps it entirely.
func _unhandled_input(event: InputEvent) -> void:
	if _ending or not _at_exit:
		return
	if event.is_action_pressed(&"move_up") and _deliberate(event):
		get_viewport().set_input_as_handled()
		_extract()
	elif event.is_action_pressed(&"move_down") and _deliberate(event):
		get_viewport().set_input_as_handled()
		_descend()


## Two distinct shafts below: offer the doors. One (or the deep vein): just go.
func _descend() -> void:
	var options: Array = delve.next_options()
	if options.size() > 1:
		_doors.offer(Delve.HINTS.get(options[0], "silence"), Delve.HINTS.get(options[1], "silence"))
		return
	delve.descend()


## A stick press only counts here at a committed tilt. The 0.2 action deadzone
## is right for movement but wrong for a run-ENDING decision: walking into the
## exit with the thumb angled slightly up crossed it and extracted the player
## by accident, every time. Keys and D-pad presses are always deliberate.
func _deliberate(event: InputEvent) -> bool:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null:
		return true
	return absf(motion.axis_value) >= 0.7


func _extract() -> void:
	_ending = true
	_prompt.hide_prompt()
	var banked: int = GameState.carried_haul
	GameState.extract()
	_result.show_result(&"extracted", banked)


func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	_prompt.hide_prompt()
	var lost: int = GameState.carried_haul
	GameState.lose_run()
	_result.show_result(&"died", lost)


## Reaching the bottom of the mine alive is a forced, triumphant extract — you
## made it all the way down and out with the whole haul.
func _on_delve_completed() -> void:
	if _ending:
		return
	_ending = true
	_prompt.hide_prompt()
	# The full-clear premium lands before the extract banks it.
	var bonus: int = roundi(float(GameState.carried_haul) * clear_bonus_fraction)
	if bonus > 0:
		GameState.add_haul(bonus)
	var banked: int = GameState.carried_haul
	GameState.extract()
	_result.show_result(&"cleared", banked)


func _to_hub() -> void:
	# Deferred: changing scene from inside a signal or input handler mid-frame is
	# unsafe while the tree is still iterating.
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)
