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

var _at_exit: bool = false
var _ending: bool = false

@onready var _prompt: CanvasLayer = $ExtractPrompt
@onready var _result: CanvasLayer = $ResultScreen


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.delve_completed.connect(_on_delve_completed)
	_prompt.visible = false
	_result.dismissed.connect(_to_hub)
	Cursor.gameplay()
	Music.play(&"delve")


func _physics_process(_delta: float) -> void:
	if _ending or delve == null:
		return
	var at: bool = delve.player_at_exit()
	if at != _at_exit:
		_at_exit = at
		_prompt.visible = at
		if at:
			_refresh_prompt()


func _refresh_prompt() -> void:
	var label: Label = _prompt.get_node("Panel/Margin/Label")
	label.text = "▲ W  Extract to surface  (bank %d)\n▼ S  Descend deeper" % GameState.carried_haul


## Runtime input, handled here rather than in _physics_process so the press
## timing is reliable — the physics-frame just_pressed gotcha (see CLAUDE.md)
## only bites synthetic input, but _unhandled_input sidesteps it entirely.
func _unhandled_input(event: InputEvent) -> void:
	if _ending or not _at_exit:
		return
	if event.is_action_pressed(&"move_up"):
		get_viewport().set_input_as_handled()
		_extract()
	elif event.is_action_pressed(&"move_down"):
		get_viewport().set_input_as_handled()
		delve.descend()


func _extract() -> void:
	_ending = true
	_prompt.visible = false
	var banked: int = GameState.carried_haul
	GameState.extract()
	_result.show_result(&"extracted", banked)


func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	_prompt.visible = false
	var lost: int = GameState.carried_haul
	GameState.lose_run()
	_result.show_result(&"died", lost)


## Reaching the bottom of the mine alive is a forced, triumphant extract — you
## made it all the way down and out with the whole haul.
func _on_delve_completed() -> void:
	if _ending:
		return
	_ending = true
	_prompt.visible = false
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
