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
## Seconds you must hold interact to swap this weapon into your hand. Tuned to
## clear a panic tap; see HoldInteract.
@export var take_hold_time: float = 0.24

var _velocity: Vector2 = Vector2.ZERO
var _player: Player = null
var _collected: bool = false
## Art node, when this pickup has any: a BakedSprite for ore/hearts (2-frame
## glint/pulse from the object sheets), a plain Sprite2D for weapon icons. The
## ColorRect stays the fallback for anything without art (buffs), so missing
## art degrades to gray-box.
var _icon: Node2D = null
## The trade offer shown over a weapon when the loadout is full. Built lazily.
## Same WorldPrompt card as the shops and shrines: weapon name, a big Take, and
## a dim line naming what it drops.
var _offer: WorldPrompt = null
## Whether the offer is currently up — the hold check reads this, not the card.
var _offered: bool = false
## Swapping the weapon in your hand is a commitment, so it takes a deliberate
## HOLD, not a tap — a panic jump (which shares the button on the pad) can't
## trigger it. See HoldInteract.
var _hold: HoldInteract = HoldInteract.new()

@onready var _visual: ColorRect = $Visual
var _ground: RayCast2D = null


func _ready() -> void:
	_hold.hold_time = take_hold_time
	_velocity = spawn_pop + Vector2(randf_range(-80, 80), 0)
	# Pickups are Areas, not bodies — nothing stops them at the floor except
	# this probe. The magnet used to hide that (it grabbed them mid-air), but a
	# weapon a full loadout refuses to magnet fell straight through the world.
	_ground = RayCast2D.new()
	_ground.target_position = Vector2(0, 18)
	_ground.collision_mask = CollisionLayers.WORLD
	_ground.enabled = false
	add_child(_ground)
	# The room-clear payoff: every loose pickup rushes to the player, so the
	# end of a fight is a shower of earnings instead of a scavenger walk.
	# Full-loadout weapon offers are exempt — they never magnet by design.
	Events.room_cleared.connect(func() -> void: magnet_range = 4000.0)
	_apply_style()


## Gravity with a floor. Used whenever the magnet is not carrying us.
func _fall(delta: float) -> void:
	_velocity.y += 900.0 * delta
	_velocity.x = move_toward(_velocity.x, 0.0, 400.0 * delta)
	var motion: Vector2 = _velocity * delta
	_ground.force_raycast_update()
	if _velocity.y > 0.0 and _ground.is_colliding():
		var floor_y: float = _ground.get_collision_point().y
		if global_position.y + motion.y >= floor_y - 8.0:
			global_position.y = floor_y - 8.0
			_velocity = Vector2.ZERO
			return
	global_position += motion


## What it is, at a glance: ore chunks and hearts use the baked icon art, a
## weapon shows ITS OWN icon so a Maul on the ground reads different from a
## Dagger before you commit to grabbing it. Size still scales with value.
func _apply_style() -> void:
	var size: float = 14.0
	var colour: Color = Color(0.95, 0.7, 0.25)
	var texture: Texture2D = null
	var sheet: String = ""
	match kind:
		Kind.HAUL:
			size = clampf(12.0 + float(amount) * 1.6, 12.0, 30.0)
			colour = Color(0.95, 0.7, 0.25) if amount < 5 else Color(1.0, 0.85, 0.35)
			sheet = "ore"
		Kind.HEAL:
			size = 20.0
			colour = Color(0.95, 0.3, 0.35)
			sheet = "heart"
		Kind.BUFF:
			size = 20.0
			colour = buff.colour if buff != null else Color(0.6, 0.8, 1.0)
		Kind.WEAPON:
			size = 34.0
			colour = weapon.swing_colour if weapon != null else Color(0.8, 0.9, 1.0)
			texture = weapon.icon if weapon != null else null
	if sheet != "":
		# Ore glints, hearts pulse — the 2-frame loops from the object sheets.
		# Big nuggets still read big: value scales the sprite like the rect.
		var baked: BakedSprite = BakedSprite.make(sheet, 2.5)
		baked.scale = Vector2.ONE * (size / 14.0)
		_icon = baked
		add_child(_icon)
		_visual.visible = false
	elif texture != null:
		var flat: Sprite2D = Sprite2D.new()
		flat.texture = texture
		flat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flat.scale = Vector2.ONE * (size / 16.0)
		_icon = flat
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
		_fall(delta)
		var near: bool = dist < 110.0
		if _hold.poll(near and not _collected, delta):
			_collect()
			return
		# On the pad, interact and jump share A: eat the hop once the hold is
		# committed so it stops knocking you off the offer. Keyboard keeps jump live.
		if _hold.committing and Keybinds.using_gamepad:
			_player.swallow_jump()
		_update_offer(near)
		return
	_update_offer(false)

	if dist < 22.0:
		_collect()
		return
	if dist < magnet_range:
		_velocity = _velocity.move_toward(to_player.normalized() * magnet_speed, magnet_speed * 4.0 * delta)
		global_position += _velocity * delta
	else:
		_fall(delta)


func _update_offer(near: bool) -> void:
	_offered = near
	if not near:
		if _offer != null:
			_offer.hide_prompt()
		return
	if _offer == null:
		_offer = WorldPrompt.new()
		_offer.position = Vector2(0, -40)
		_offer.priority = 20
		add_child(_offer)
	var dropped: WeaponData = _player.stowed_weapon()
	var drops: String = dropped.display_name if dropped != null else "nothing"
	_offer.set_card(weapon.display_name, "drops %s" % drops,
		[PromptCard.hold_row(&"interact", "Hold to Take", _hold.progress)])
	_offer.show_prompt()


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
