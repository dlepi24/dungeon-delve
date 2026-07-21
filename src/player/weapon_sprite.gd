class_name WeaponSprite
extends Sprite2D
## Stage 2 of the weapon layer (docs/art-specs/weapon-layer.md): renders the
## EQUIPPED weapon in the Delver's glove, driven by the per-frame anchors that
## gen_sprites bakes into player.json. One body animation set, any weapon in
## hand: position from the frame's hand anchor, rotation from its shaft angle,
## visibility from its show flag (rolls holster).
##
## A WeaponData with no sprite yet hides this node, and the pickaxe baked into
## the body frames covers for it — so until weapons.png lands, the game looks
## exactly as it did before stage 2, and each weapon upgrades the moment its
## texture is assigned.
##
## Mirroring is scale.x = -1 plus a mirrored anchor, NOT flip_h: flip_h
## mirrors the texture but leaves rotation alone, which points a flipped
## weapon the wrong way. Negative scale mirrors the whole rotated sprite.
##
## Visual only. _process, never _physics_process.

@export var player: Player
@export var body: PlayerSprite

## Top-left of the 40x56 frame relative to the feet origin — matches the body
## Sprite's position. Converts manifest pixel coords to VisualRoot space.
const FRAME_OFFSET: Vector2 = Vector2(-20, -56)

## Weapon art is authored shaft-up, which the manifest calls 90 degrees.
const ART_ANGLE: float = 90.0
## Frame indices in the 5-pose attack the smear sweeps between.
const ATTACK_WIND_FRAME: int = 0
const ATTACK_CONTACT_FRAME: int = 3

@export_group("Arc smear")
## The amber sweep between the wind and contact angles, spawned on the contact
## frame. Engine-drawn, so it fits any weapon's length and speed for free.
@export var smear_colour: Color = Color(1.0, 0.78, 0.35, 0.55)
## Seconds the smear lives (spec: ~2 visual frames).
@export var smear_life: float = 0.07
## Sweep radius when the weapon has no sprite to measure (the baked pick).
@export var smear_radius: float = 18.0

var _last_attack_frame: int = -1


func _ready() -> void:
	centered = false
	if player == null:
		player = owner as Player
	if body == null:
		body = get_node_or_null("../Sprite") as PlayerSprite


func _process(_delta: float) -> void:
	if player == null or body == null:
		visible = false
		return
	_watch_for_contact()

	var weapon: WeaponData = player.equipped_weapon
	if weapon == null or weapon.sprite == null:
		visible = false
		return
	var entry: Dictionary = _anchor_entry(body.frame)
	if entry.is_empty() or not bool(entry.get("show", true)):
		visible = false
		return

	texture = weapon.sprite
	offset = -weapon.grip
	var facing: float = float(player.facing)
	position = _hand_position(entry, facing)
	# Manifest angle: 0 = forward, 90 = up. Shaft-up art needs (90 - angle) of
	# clockwise rotation to point at `angle`; the mirror negates it.
	rotation_degrees = (ART_ANGLE - float(entry.get("angle", ART_ANGLE))) * facing
	scale = Vector2(facing, 1.0)
	# BodyJuice drives the hit flash by modulating the body sprite directly, so
	# riding its modulate is what keeps the weapon flashing in sync with it.
	modulate = body.modulate
	visible = true


## Manifest anchor for the body's current animation at a given frame index.
func _anchor_entry(frame_index: int) -> Dictionary:
	var per_anim: Array = body.anchors.get(String(body.animation), []) as Array
	if frame_index < 0 or frame_index >= per_anim.size():
		return {}
	return per_anim[frame_index] as Dictionary


func _hand_position(entry: Dictionary, facing: float) -> Vector2:
	var hand: Array = entry.get("hand", [20, 35]) as Array
	return Vector2(
		(FRAME_OFFSET.x + float(hand[0])) * facing,
		FRAME_OFFSET.y + float(hand[1]))


## Spawn the smear exactly once per swing, as the animation lands on the
## contact pose. Frame-change detection rather than state detection: the body
## animation is the single source of swing timing (it is already fitted to the
## weapon's real startup+active+recovery).
func _watch_for_contact() -> void:
	if String(body.animation) != "attack":
		_last_attack_frame = -1
		return
	var frame_now: int = body.frame
	if frame_now == _last_attack_frame:
		return
	_last_attack_frame = frame_now
	if frame_now == ATTACK_CONTACT_FRAME:
		_spawn_smear()


func _spawn_smear() -> void:
	var contact: Dictionary = _anchor_entry(ATTACK_CONTACT_FRAME)
	var wind: Dictionary = _anchor_entry(ATTACK_WIND_FRAME)
	if contact.is_empty() or wind.is_empty():
		return
	var from_deg: float = float(wind.get("angle", 140.0))
	var to_deg: float = float(contact.get("angle", -35.0))

	var radius: float = smear_radius
	var weapon: WeaponData = player.equipped_weapon
	if weapon != null and weapon.sprite != null:
		# Grip-to-tip of the shaft-up art is how far the weapon actually reaches.
		radius = maxf(smear_radius, weapon.grip.y)

	var fan: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var steps: int = 10
	for i: int in steps + 1:
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(steps)))
		# Manifest angle space: 0 = +x, 90 = up; screen y points down.
		points.append(Vector2(cos(a), -sin(a)) * radius)
	fan.polygon = points
	fan.color = smear_colour

	var facing: float = float(player.facing)
	fan.position = _hand_position(contact, facing)
	fan.scale = Vector2(facing, 1.0)
	# Under VisualRoot, so the smear inherits squash and spin like everything
	# else attached to the body.
	get_parent().add_child(fan)
	var tween: Tween = fan.create_tween()
	tween.tween_property(fan, "modulate:a", 0.0, smear_life)
	tween.tween_callback(fan.queue_free)
