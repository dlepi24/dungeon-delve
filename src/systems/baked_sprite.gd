class_name BakedSprite
extends AnimatedSprite2D
## An AnimatedSprite2D that builds itself from a baked sheet under
## assets/sprites/ (PNG + the generator's JSON manifest) — the same
## slice-by-manifest discipline as PlayerSprite and EnemySprite, so the art
## pipeline has exactly one contract. Used by the delve furniture and hub
## buildings (art-drop 2026-07-21): a scene node just names a sheet; code can
## call make().
##
## Visual only. Flickers are unseeded wall-clock animation on purpose — set
## dressing must never touch the seeded gameplay streams.

const DIR: String = "res://assets/sprites/"

## Sheet name under assets/sprites/, e.g. "smithy".
@export var sheet: String = ""
## Animation to play; empty = the manifest's first.
@export var anim: StringName = &""
## Playback speed. 2.5 fps makes a 2-frame loop the ~0.4 s coal flicker.
@export var fps: float = 2.5

func _ready() -> void:
	if sheet != "":
		_build()


static func make(sheet_name: String, fps_value: float = 2.5, which: StringName = &"") -> BakedSprite:
	var out: BakedSprite = BakedSprite.new()
	out.sheet = sheet_name
	out.fps = fps_value
	out.anim = which
	return out


func _build() -> void:
	var texture: Texture2D = load("%s%s.png" % [DIR, sheet]) as Texture2D
	var file: FileAccess = FileAccess.open("%s%s.json" % [DIR, sheet], FileAccess.READ)
	if texture == null or file == null:
		push_error("BakedSprite: missing sheet '%s' — run python3 tools/gen_sprites.py" % sheet)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("BakedSprite: '%s' manifest is not valid JSON" % sheet)
		return
	var data: Dictionary = parsed as Dictionary
	var size: Array = data["frame_size"]
	var fw: int = int(size[0])
	var fh: int = int(size[1])
	var animations: Dictionary = data["animations"]

	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var first: StringName = &""
	for name: String in animations:
		var info: Dictionary = animations[name]
		if first == &"":
			first = StringName(name)
		frames.add_animation(StringName(name))
		frames.set_animation_loop(StringName(name), true)
		frames.set_animation_speed(StringName(name), fps)
		for i: int in int(info["count"]):
			var region: AtlasTexture = AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(float(i * fw), float(int(info["row"]) * fh), float(fw), float(fh))
			frames.add_frame(StringName(name), region)
	sprite_frames = frames
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play(anim if anim != &"" and frames.has_animation(anim) else first)
