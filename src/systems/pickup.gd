class_name Pickup
extends Area2D
## Something you collect in the world: ore (haul) or a heart (heal). One node,
## configured by kind at spawn, because the magnet-and-collect behaviour is
## identical — only the payoff and the colour differ.
##
## Sits on the Pickup collision layer. Magnets toward the player when close so
## loot feels generous rather than a pixel-hunt, then applies its effect on
## contact. Movement is in _physics_process (deterministic); the spin is _process
## (visual only).
##
## Drop RNG is seeded (see Enemy._drop_haul) so two players on one daily seed get
## the same drops — drops are gameplay, not decoration.

enum Kind { HAUL, HEAL, BUFF, WEAPON }

@export var kind: Kind = Kind.HAUL
## Haul value, or health restored, depending on kind.
@export var amount: int = 1
## The buff granted when kind is BUFF. Also colours the pickup.
@export var buff: BuffData
## The weapon granted when kind is WEAPON.
@export var weapon: WeaponData

@export_group("Feel")
@export var magnet_range: float = 120.0
@export var magnet_speed: float = 520.0
@export var spawn_pop: Vector2 = Vector2(0, -140)

const ORE_ICON: Texture2D = preload("res://assets/icons/ore.png")
const HEART_ICON: Texture2D = preload("res://assets/icons/heart.png")

var _velocity: Vector2 = Vector2.ZERO
var _player: Player = null
var _collected: bool = false
## Icon sprite, when this pickup has art. The ColorRect stays the fallback for
## anything without an icon (buffs), so missing art degrades to gray-box.
var _icon: Sprite2D = null
## The trade offer shown over a weapon when the loadout is full. Built lazily.
var _offer: Label = null

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_velocity = spawn_pop + Vector2(randf_range(-80, 80), 0)
	_apply_style()


## What it is, at a glance: ore chunks and hearts use the baked icon art, a
## weapon shows ITS OWN icon so a Maul on the ground reads different from a
## Dagger before you commit to grabbing it. Size still scales with value.
func _apply_style() -> void:
	var size: float = 14.0
	var colour: Color = Color(0.95, 0.7, 0.25)
	var texture: Texture2D = null
	match kind:
		Kind.HAUL:
			size = clampf(12.0 + float(amount) * 1.6, 12.0, 30.0)
			colour = Color(0.95, 0.7, 0.25) if amount < 5 else Color(1.0, 0.85, 0.35)
			texture = ORE_ICON
		Kind.HEAL:
			size = 20.0
			colour = Color(0.95, 0.3, 0.35)
			texture = HEART_ICON
		Kind.BUFF:
			size = 20.0
			colour = buff.colour if buff != null else Color(0.6, 0.8, 1.0)
		Kind.WEAPON:
			size = 34.0
			colour = weapon.swing_colour if weapon != null else Color(0.8, 0.9, 1.0)
			texture = weapon.icon if weapon != null else null
	if texture != null:
		_icon = Sprite2D.new()
		_icon.texture = texture
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.scale = Vector2.ONE * (size / 16.0)
		add_child(_icon)
		_visual.visible = false
	_visual.color = colour
	_visual.custom_minimum_size = Vector2(size, size)
	_visual.size = Vector2(size, size)
	_visual.position = -Vector2(size, size) * 0.5
	_visual.pivot_offset = Vector2(size, size) * 0.5


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return

	var to_player: Vector2 = (_player.global_position + Vector2(0, -28)) - global_position
	var dist: float = to_player.length()

	# A weapon facing a FULL loadout is an offer, not loot (Dustin's inventory
	# call): it stays on the ground and trades only on a deliberate interact.
	# The magnet-and-touch flow was silently discarding honed weapons.
	if kind == Kind.WEAPON and _player.loadout_full():
		_velocity.y += 900.0 * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 400.0 * delta)
		global_position += _velocity * delta
		_update_offer(dist < 110.0)
		return
	_update_offer(false)

	if dist < 22.0:
		_collect()
		return
	if dist < magnet_range:
		_velocity = _velocity.move_toward(to_player.normalized() * magnet_speed, magnet_speed * 4.0 * delta)
	else:
		_velocity.y += 900.0 * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 400.0 * delta)
	global_position += _velocity * delta


func _update_offer(near: bool) -> void:
	if not near:
		if _offer != null:
			_offer.visible = false
		return
	if _offer == null:
		_offer = Label.new()
		_offer.position = Vector2(-200, -96)
		_offer.size = Vector2(400, 56)
		_offer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_offer.add_theme_font_size_override(&"font_size", 15)
		_offer.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
		_offer.add_theme_constant_override(&"outline_size", 6)
		add_child(_offer)
	var dropped: WeaponData = _player.stowed_weapon()
	_offer.text = "%s\n[%s] Take — drops %s" % [
		weapon.display_name, Keybinds.hint_for(&"interact"),
		dropped.display_name if dropped != null else "nothing",
	]
	_offer.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _collected or _offer == null or not _offer.visible:
		return
	if not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	_collect()


func _collect() -> void:
	_collected = true
	match kind:
		Kind.HAUL:
			GameState.add_haul(amount)
			Events.haul_collected.emit(amount, global_position)
		Kind.HEAL:
			if _player != null:
				_player.heal(float(amount))
		Kind.BUFF:
			if _player != null and buff != null:
				_player.apply_buff(buff)
		Kind.WEAPON:
			if _player != null and weapon != null:
				_player.equip_weapon(weapon)
	queue_free()


func _process(_delta: float) -> void:
	# Icons bob rather than spin — a rotating pickaxe reads as a projectile.
	if _icon != null:
		_icon.position.y = sin(float(Time.get_ticks_msec()) * 0.005) * 3.0
	elif _visual != null:
		_visual.rotation += 0.06
