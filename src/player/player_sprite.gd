class_name PlayerSprite
extends AnimatedSprite2D
## Drives the miner's animation from the player's FSM state.
##
## The state machine is the single source of truth: animation names match state
## names lowercased, so this reads the state and plays it. No parallel animation
## state machine to fall out of sync with the real one — that desync is the
## classic bug where the character keeps running while standing still.
##
## Builds its SpriteFrames from the generated sheet at load, using the manifest
## that tools/gen_sprites.py writes alongside it. That means adding an animation
## is editing the ASCII and re-running the generator; nothing here changes.
##
## Visual only. _process, never _physics_process.

const SHEET: String = "res://assets/sprites/player.png"
const MANIFEST: String = "res://assets/sprites/player.json"

@export var player: Player

@export_group("Timing")
## Frames per second per animation. Run is tied to speed below instead.
@export var idle_fps: float = 3.0
@export var roll_fps: float = 14.0
@export var attack_fps: float = 18.0
## The run cycle is driven by how fast you are actually moving, so the feet
## roughly keep up with the ground instead of skating.
@export var run_fps_at_top_speed: float = 14.0

var _current: StringName = &""


func _ready() -> void:
	sprite_frames = _build_frames()
	if player == null:
		player = get_parent() as Player
	_play(&"idle")


## Slices the sheet using the generator's manifest rather than hard-coded indices,
## so the two cannot drift apart.
func _build_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	var texture: Texture2D = load(SHEET) as Texture2D
	if texture == null:
		push_error("PlayerSprite: no sheet at %s — run python3 tools/gen_sprites.py" % SHEET)
		return frames

	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		push_error("PlayerSprite: no manifest at %s" % MANIFEST)
		return frames
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("PlayerSprite: manifest is not valid JSON")
		return frames
	var data: Dictionary = parsed as Dictionary

	var size: Array = data["frame_size"]
	var fw: int = int(size[0])
	var fh: int = int(size[1])
	var animations: Dictionary = data["animations"]

	for name: String in animations:
		var info: Dictionary = animations[name]
		var row: int = int(info["row"])
		var count: int = int(info["count"])
		frames.add_animation(StringName(name))
		frames.set_animation_loop(StringName(name), true)
		for i: int in count:
			var region: AtlasTexture = AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(float(i * fw), float(row * fh), float(fw), float(fh))
			frames.add_frame(StringName(name), region)
	return frames


func _play(animation: StringName) -> void:
	if _current == animation or not sprite_frames.has_animation(animation):
		return
	_current = animation
	play(animation)


func _process(_delta: float) -> void:
	if player == null:
		return

	# Face the way the player faces. flip_h rather than a scale, so the sprite's
	# offset does not have to be mirrored too.
	flip_h = player.facing < 0

	var state: StringName = StringName(String(player.get_state_name()).to_lower())
	if not sprite_frames.has_animation(state):
		state = &"idle"
	_play(state)

	match state:
		&"run":
			# Tie the cycle to actual speed: at a crawl the feet shuffle, at top
			# speed they sprint. A fixed rate reads as skating.
			var ratio: float = absf(player.velocity.x) / maxf(1.0, player.max_run_speed)
			speed_scale = maxf(0.35, ratio) * run_fps_at_top_speed / maxf(0.01, idle_fps)
		&"roll":
			speed_scale = roll_fps / maxf(0.01, idle_fps)
		&"attack":
			speed_scale = attack_fps / maxf(0.01, idle_fps)
		_:
			speed_scale = 1.0
