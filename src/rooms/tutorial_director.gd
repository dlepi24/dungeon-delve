class_name TutorialDirector
extends Node
## Drives "The First Descent" — the guided intro. Teaches one verb per beat with
## a WorldPrompt card that rides above the player, gating each beat on a real
## Events signal (or a simple position check), then hands off to the hub with the
## intro_seen flag set. It REPLACES RunCoordinator: the extract/descend fork
## appears only at the finale, as the last lesson.
##
## Path (2026-07-22): ROOM 1 (entry) teaches move → jump → attack → parry →
## shrine, its authored enemies/shrine cleared so the guided beats own the floor;
## ROOM 2 (tut_traversal) teaches roll (spike gap) → grapple (anchor to a high
## exit); then the extract finale. Reaching any exit advances — to the next room
## mid-intro, or to extract in the last room. The scripted capstone boss is the
## remaining layer.
##
## Teach-don't-wall (Dustin's call): survival verbs are required by geometry; the
## tricky ones (parry, roll, grapple) have escape hatches — you can walk/jump/
## climb past and reaching the exit always progresses.

@export var delve: Delve

const HUB_SCENE: String = "res://src/hub/hub.tscn"
const DUMMY: PackedScene = preload("res://src/enemies/training_dummy.tscn")
const AXE: PackedScene = preload("res://src/systems/hazards/swinging_axe.tscn")
const SPIKES: PackedScene = preload("res://src/systems/hazards/spikes.tscn")
const BOSS_SCENE: PackedScene = preload("res://src/enemies/tutorial_boss.tscn")
const SHRINE_SCENE: PackedScene = preload("res://src/systems/shrine.tscn")
## A no-cost bargain, so the intro shrine is acceptable before you've earned ore.
const TUTORIAL_SHRINE: String = "res://src/systems/shrines/vein_of_greed.tres"
## The authored tutorial path: teaching room, traversal room, boss arena.
const PLAN: Array[StringName] = [&"entry", &"tut_traversal", &"tut_boss"]
## How far the player must walk for the MOVE beat to count as learned.
const MOVE_DISTANCE: float = 220.0

enum Beat { MOVE, JUMP, ATTACK, PARRY, SHRINE, ROLL, POGO, GRAPPLE, BOSS, EXTRACT, DONE }

var _player: Player = null
var _beat: Beat = Beat.MOVE
var _teach: WorldPrompt = null       # rides above the player
var _exit_card: WorldPrompt = null   # floats at the door for the finale
var _dummy: TrainingDummy = null
var _axe: SwingingAxe = null          # the roll obstacle, hung over the floor
var _spikes: Node2D = null            # the pogo target — a bed struck from above
var _boss: TutorialBoss = null        # the capstone; the exit is gated until it falls
var _shrine: Shrine = null           # placed deliberately, with space, for its beat
var _move_anchor_x: float = 0.0
var _ending: bool = false


func _ready() -> void:
	Cursor.gameplay()
	Music.play(&"delve", -8.0)
	# Keep this run off the daily/ranked path, and flag it so the old first-run
	# TeachingSigns overlay stands down (this supersedes it).
	GameState.pending_mode = &"tutorial"
	Events.player_jumped.connect(_on_jumped)
	Events.hit_landed.connect(_on_hit)
	Events.parry_succeeded.connect(_on_parry)
	Events.shrine_accepted.connect(_on_shrine)
	Events.player_rolled.connect(_on_rolled)
	# In the intro you cannot fail: a lethal hit revives you instead of sticking
	# you in the death beat with no coordinator to hand off to.
	Events.player_died.connect(_on_player_died)
	delve.start_plan(PLAN)
	# The room and player settle during start_plan's work; begin a frame later.
	_begin.call_deferred()


func _begin() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	# Clean teaching space: clear the room's authored enemies AND any seeded
	# shrine, so the guided beats own the floor. The shrine gets its own
	# deliberate beat later — a stray one jammed against the dummy is exactly the
	# card/pile-up the intro must not have.
	for stray: Node in get_tree().get_nodes_in_group(&"enemies"):
		stray.queue_free()
	for stray: Node in get_tree().get_nodes_in_group(&"shrines"):
		stray.queue_free()
	_teach = WorldPrompt.new()
	_teach.lift = 34.0
	_teach.position = Vector2(0, -58)
	_player.add_child(_teach)
	_enter_beat(Beat.MOVE)


func _enter_beat(beat: Beat) -> void:
	_beat = beat
	match beat:
		Beat.MOVE:
			_move_anchor_x = _player.global_position.x
			_teach.set_card("", "", [PromptCard.action_row(&"move_right", "Move — head deeper")])
			_teach.show_prompt()
		Beat.JUMP:
			_teach.set_card("", "", [PromptCard.action_row(&"jump", "Jump the ledges")])
		Beat.ATTACK:
			_spawn_dummy()
			_teach.set_card("", "", [PromptCard.action_row(&"attack", "Attack the dummy")])
		Beat.PARRY:
			_teach.set_card("It swings back", "parry the instant it flashes",
				[PromptCard.action_row(&"parry", "Parry")])
		Beat.SHRINE:
			_spawn_shrine()
			# A distance hint; the shrine's own card takes over as you approach it
			# (the prompt arbiter yields the teaching card to the higher-priority
			# offer), so the two never stack.
			_teach.set_card("A bargain ahead", "the mine sells power for a price — take it or walk past", [])
		Beat.ROLL:
			_spawn_axe()
			_teach.set_card("A blade sweeps the path", "roll through it — you're invincible mid-roll",
				[PromptCard.action_row(&"roll", "Roll")])
			_teach.show_prompt()
		Beat.POGO:
			_spawn_pogo_target()
			_teach.set_card("Struck from above, spikes are a foothold",
				"in the air, hold DOWN and attack to pogo off them",
				[PromptCard.action_row(&"attack", "Down + Attack, mid-air")])
			_teach.show_prompt()
		Beat.GRAPPLE:
			_teach.set_card("The way out is up", "hook the timber beam to zip up — or climb the ledges",
				[PromptCard.action_row(&"skill_2", "Grapple")])
		Beat.BOSS:
			_spawn_boss()
			# An announcement, not a permanent hat: introduce him, then fade so the
			# fight is unobstructed. The beat stays BOSS until he falls.
			_teach.set_card("THE FOREMAN", "read the swing — roll it, or parry for a riposte", [])
			_teach.show_prompt()
			_hide_teach_after(4.0)
		Beat.EXTRACT:
			_teach.hide_prompt()
			_show_exit_card()
		Beat.DONE:
			pass


func _spawn_dummy() -> void:
	if _dummy != null and is_instance_valid(_dummy):
		return
	_dummy = DUMMY.instantiate() as TrainingDummy
	delve.add_child(_dummy)
	# Ahead of the player, on open floor — clear of the exit and the shrine, which
	# sits near the door for its own beat.
	_dummy.global_position = _player.global_position + Vector2(240, -20)


## The roll obstacle: a swinging blade hung over the traversal room's floor path,
## ahead of the entry so the player meets it walking right. Pivot is arm_length
## above the floor, so the blade sweeps at body height on solid ground.
func _spawn_axe() -> void:
	if _axe != null and is_instance_valid(_axe):
		return
	var room: Room = delve.current_room()
	if room == null:
		return
	_axe = AXE.instantiate() as SwingingAxe
	var entry: Vector2 = room.entry_position()
	_axe.global_position = Vector2(entry.x + 360.0, entry.y - _axe.arm_length)
	room.add_child(_axe)


## A spike bed on the floor past the blade — the pogo target. You bounce off it
## from above; rolling through or stepping around it is the escape hatch.
func _spawn_pogo_target() -> void:
	if _spikes != null and is_instance_valid(_spikes):
		return
	var room: Room = delve.current_room()
	if room == null:
		return
	_spikes = SPIKES.instantiate() as Node2D
	_spikes.global_position = Vector2(room.entry_position().x + 720.0, room.entry_position().y)
	room.add_child(_spikes)


## The Foreman, across the arena from the entry. Its `died` signal is the only
## thing that opens the extract finale — the exit is gated until it falls.
func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return
	var room: Room = delve.current_room()
	if room == null:
		return
	_boss = BOSS_SCENE.instantiate() as TutorialBoss
	_boss.global_position = Vector2(room.exit_marker.global_position.x - 300.0, room.entry_position().y)
	_boss.died.connect(_on_boss_died)
	room.add_child(_boss)


## Placed deliberately near the exit (not seeded), with room around it, so the
## bargain reads as its own beat instead of piling onto the dummy or the door.
func _spawn_shrine() -> void:
	if _shrine != null and is_instance_valid(_shrine):
		return
	var room: Room = delve.current_room()
	if room == null:
		return
	_shrine = SHRINE_SCENE.instantiate() as Shrine
	_shrine.data = load(TUTORIAL_SHRINE) as ShrineData
	_shrine.global_position = room.exit_marker.global_position - Vector2(360.0, 0.0)
	room.add_child(_shrine)


func _process(_delta: float) -> void:
	if _player == null or _ending:
		return
	if _beat == Beat.MOVE:
		if absf(_player.global_position.x - _move_anchor_x) >= MOVE_DISTANCE:
			_enter_beat(Beat.JUMP)
		return
	# Doing the pogo (down+attack in the air) advances to grapple; doing the
	# grapple dismisses its card. Both read the live player state — there is no
	# signal for either verb.
	if _beat == Beat.POGO and _player.get_state_name() == &"Pogo":
		_enter_beat(Beat.GRAPPLE)
	elif _beat == Beat.GRAPPLE and _player.get_state_name() == &"Hook":
		_teach.hide_prompt()
	# The boss gates its room's exit: only its death (not reaching the door)
	# advances. EXTRACT/DONE are terminal.
	if _beat == Beat.EXTRACT or _beat == Beat.DONE or _beat == Beat.BOSS:
		return
	# Reaching the exit always progresses — to the next room mid-intro, or to the
	# extract finale in the last room. This is also the teach-don't-wall escape:
	# a player who fumbles parry/roll/grapple still reaches the light.
	if delve.player_at_exit():
		_on_reach_exit()


## Reaching a mid-intro exit descends into the next room and starts its first
## beat; the last room's exit opens the extract finale.
func _on_reach_exit() -> void:
	if delve.current_index() >= PLAN.size() - 1:
		_enter_beat(Beat.EXTRACT)
		return
	_free_dummy()  # it rode on the Delve, not the room, so free it by hand
	delve.descend()
	match delve.current_index():
		1:
			_enter_beat(Beat.ROLL)
		2:
			_enter_beat(Beat.BOSS)
		_:
			_enter_beat(Beat.EXTRACT)


func _on_boss_died() -> void:
	if _beat == Beat.BOSS:
		_enter_beat(Beat.EXTRACT)


## Fade the teaching card after `seconds`, but only if we're still on the beat
## that showed it — used for announcement cards (the boss intro) that shouldn't
## linger over a long beat.
func _hide_teach_after(seconds: float) -> void:
	var at_beat: Beat = _beat
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if not _ending and _beat == at_beat and _teach != null:
			_teach.hide_prompt())


func _free_dummy() -> void:
	if _dummy != null and is_instance_valid(_dummy):
		_dummy.queue_free()
	_dummy = null


func _on_jumped() -> void:
	if _beat == Beat.JUMP:
		_enter_beat(Beat.ATTACK)


func _on_hit(_damage: float, _was_riposte: bool, _impact: StringName, _material: StringName) -> void:
	if _beat == Beat.ATTACK:
		_enter_beat(Beat.PARRY)


func _on_parry() -> void:
	if _beat == Beat.PARRY:
		_enter_beat(Beat.SHRINE)


func _on_rolled() -> void:
	if _beat == Beat.ROLL:
		_enter_beat(Beat.POGO)


## In the intro, death is impossible — the mine spits you back out. This both
## fixes the stuck death-beat (no coordinator to hand off to) and is the right
## teaching call: hits still hurt (health drops, the low-HP pulse fires), but you
## never fail or lose your place. Real stakes are the real game's job.
func _on_player_died() -> void:
	if _player == null or _ending:
		return
	_player.reset_for_new_run()
	var room: Room = delve.current_room()
	if room != null:
		_player.teleport_to(room.entry_position())
	if _teach == null:
		return
	_teach.set_card("Only training", "the mine won't let you die here — but hits still sting", [])
	_teach.show_prompt()
	# Restore the current beat's prompt after a beat, if we're still on it.
	var at_beat: Beat = _beat
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if not _ending and _beat == at_beat:
			_enter_beat(_beat))


func _on_shrine(_data: ShrineData) -> void:
	if _beat == Beat.SHRINE:
		_teach.set_card("Taken.", "head for the light — the way out", [])


func _show_exit_card() -> void:
	var room: Room = delve.current_room()
	if room == null:
		return
	_exit_card = WorldPrompt.new()
	_exit_card.lift = 30.0
	_exit_card.priority = 30
	delve.add_child(_exit_card)
	_exit_card.global_position = room.exit_marker.global_position - Vector2(0.0, room.exit_size.y)
	_exit_card.set_card("", "", [PromptCard.dir_row(true, "Extract — bank your first haul")])
	_exit_card.show_prompt()


## The finale's only real input: UP at the exit extracts. Deliberate-tilt guard
## mirrors the real run's, so a lightly-angled stick never ends the intro early.
func _unhandled_input(event: InputEvent) -> void:
	if _ending or _beat != Beat.EXTRACT:
		return
	if event.is_action_pressed(&"move_up") and _deliberate(event):
		get_viewport().set_input_as_handled()
		_finish()


func _deliberate(event: InputEvent) -> bool:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null:
		return true
	return absf(motion.axis_value) >= 0.7


func _finish() -> void:
	_ending = true
	_beat = Beat.DONE
	GameState.intro_seen = true
	GameState.save_game()
	# The hub's _ready clears the run state; we just mark the intro done and go.
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)
