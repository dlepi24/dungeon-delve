class_name EnemySprite
extends AnimatedSprite2D
## Drives an enemy's animation from its FSM state, and sizes itself from the
## sheet's manifest.
##
## Animation names match the Enemy State enum lowercased, so this reads the live
## state and plays it. No parallel animation state machine to fall out of sync —
## that desync is how you get a creature still winding up while it is already
## hitting you.
##
## The sheet comes from EnemyStats.sprite_sheet, so a new enemy skin is data.
##
## Deliberately does NOT set its own colour. BodyJuice tints it from the stats,
## which is what keeps the telegraph working now that the art is real.

const DIR: String = "res://assets/sprites/"

@export var enemy: Enemy
## The art is authored at 1 px per game 2 px, matching the player's density.
@export var pixel_scale: float = 2.0

var _current: StringName = &""


func _ready() -> void:
	if enemy == null:
		enemy = get_parent().get_parent() as Enemy
	if enemy == null or enemy.stats == null:
		return
	_build(enemy.stats.sprite_sheet)


func _build(sheet: String) -> void:
	var texture: Texture2D = load("%s%s.png" % [DIR, sheet]) as Texture2D
	var file: FileAccess = FileAccess.open("%s%s.json" % [DIR, sheet], FileAccess.READ)
	if texture == null or file == null:
		push_error("EnemySprite: missing sheet '%s' — run python3 tools/gen_sprites.py" % sheet)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("EnemySprite: '%s' manifest is not valid JSON" % sheet)
		return
	var data: Dictionary = parsed as Dictionary

	var size: Array = data["frame_size"]
	var fw: int = int(size[0])
	var fh: int = int(size[1])

	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var animations: Dictionary = data["animations"]
	for name: String in animations:
		var info: Dictionary = animations[name]
		frames.add_animation(StringName(name))
		frames.set_animation_loop(StringName(name), true)
		for i: int in int(info["count"]):
			var region: AtlasTexture = AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(float(i * fw), float(int(info["row"]) * fh), float(fw), float(fh))
			frames.add_frame(StringName(name), region)
	sprite_frames = frames

	# Centre horizontally and stand the feet on the body's origin. Computed from
	# the manifest rather than hard-coded, so each creature's own canvas size is
	# respected and a resized sheet does not silently start floating.
	centered = false
	scale = Vector2(pixel_scale, pixel_scale)
	position = Vector2(-float(fw) * pixel_scale * 0.5, -float(fh) * pixel_scale)
	_play(&"idle")


func _play(animation: StringName) -> void:
	if _current == animation or sprite_frames == null or not sprite_frames.has_animation(animation):
		return
	_current = animation
	play(animation)


func _process(_delta: float) -> void:
	if enemy == null or sprite_frames == null:
		return
	flip_h = enemy.get_facing() < 0
	var state: StringName = StringName(enemy.get_state_name().to_lower())
	if not sprite_frames.has_animation(state):
		state = &"idle"
	_play(state)
