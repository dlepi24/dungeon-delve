extends Node
## Screenshots a scene for visual review without a human at the keyboard:
## instances it, waits for deferred builds and tweens to settle, saves the
## viewport to a PNG, quits. Runs as a SCENE (not --script) so autoloads exist,
## same rule as tools/check.tscn.
##
## Usage (needs a real window — headless has no renderer):
##   godot --path . res://tools/screenshot.tscn -- <res://scene.tscn> <out.png>

## Frames to let the scene settle: MineAtmosphere builds deferred, prompts fade
## in, and the grade tween needs a moment — a frame-1 grab lies about all of it.
@export var settle_frames: int = 45


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: godot --path . res://tools/screenshot.tscn -- <scene> <out.png>")
		get_tree().quit(1)
		return
	_capture(args[0], args[1])


func _capture(scene_path: String, out_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		printerr("could not load scene: " + scene_path)
		get_tree().quit(1)
		return
	var instance: Node = packed.instantiate()
	# The tree is still assembling during _ready; a direct add_child fails.
	get_tree().root.add_child.call_deferred(instance)
	for i: int in settle_frames:
		await get_tree().process_frame
	# One extra: process_frame fires BEFORE the frame's _process (CLAUDE.md), so
	# without it the grab reads the previous frame's visuals.
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("screenshot: %s (err=%d)" % [out_path, err])
	get_tree().quit(0 if err == OK else 1)
