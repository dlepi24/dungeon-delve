extends Node
## Art-pass camera rig: boots a seeded run, walks it room by room, and saves a
## screenshot of every stop — one frame per zone arrival (title card up) and
## one settled. For judging zone palettes without hand-playing five rooms.
##
## Run WINDOWED (rendering must exist, and fullscreen would grab the desktop):
##   godot --path . --windowed --resolution 1280x720 res://tools/zone_shots.tscn
##
## Writes zone_*.png next to the project in .zone_shots/ (git-ignored by the
## build dir pattern; delete freely).

const SEED: int = 4242
const OUT_DIR: String = "res://.zone_shots"

var _run: Node2D = null
var _delve: Delve = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	GameState.pending_seed = SEED
	_run = (load("res://src/rooms/delve_run.tscn") as PackedScene).instantiate() as Node2D
	add_child(_run)
	_shoot.call_deferred()


func _shoot() -> void:
	_delve = _run.get_node("Delve") as Delve
	# Let the deferred auto-start land and the first room settle.
	await _frames(10)
	while true:
		var index: int = _delve.current_index()
		var id: StringName = _delve.get_plan()[index]
		# Arrival: the title card (if any) is still up.
		await _frames(30)
		_save("%02d_%s_arrive" % [index, id])
		# Settled: card gone, atmosphere tweens finished — and the player moved
		# to mid-room, so the shot frames the room's content, not its doorway.
		var room: Room = _delve.current_room()
		var player: Player = _run.get_node("Player") as Player
		if room != null and player != null:
			player.teleport_to((room.entry_position() + room.exit_position()) * 0.5)
		await _frames(75)
		_save("%02d_%s" % [index, id])
		if index >= _delve.get_plan().size() - 1:
			break
		_delve.descend()
		await _frames(8)
	get_tree().quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		# The model must not die on set: an AFK player parked next to enemies
		# for a 75-frame exposure WILL be killed, and the death result screen
		# then pauses the tree and resets the run under the rig's feet (found
		# the hard way — one polluted contact sheet, full of pause menu).
		var player: Player = _run.get_node_or_null("Player") as Player
		if player != null and player.health < player.effective_max_health():
			player.heal(player.effective_max_health())
		await get_tree().process_frame


func _save(label: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, label])
	image.save_png(path)
	print("shot: ", path)
