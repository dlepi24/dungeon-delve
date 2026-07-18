extends Node
## Turns pickup events into floating world-space callouts: "+3 ore", "Haste!",
## "Maul!", "+25 HP". Instanced in any scene where pickups happen.
##
## A listener node rather than code in Pickup because the pickup should not know
## presentation exists — it already announces what happened on Events, and this
## is just the first thing to actually listen. Spawns into this node's parent
## (the scene's world Node2D), so positions are plain world coordinates with no
## camera math.
##
## The player is resolved lazily at each event, never cached from _ready — the
## group-lookup _ready-order trap (see CLAUDE.md) applies to any node that sits
## above the Player in the tree.

const ORE_COLOUR: Color = Color(1.0, 0.85, 0.35)
const HEAL_COLOUR: Color = Color(0.95, 0.3, 0.35)

## Where over the player's head callouts appear (heals, buffs, weapons).
@export var head_offset: Vector2 = Vector2(0, -86)


func _ready() -> void:
	Events.haul_collected.connect(_on_haul)
	Events.player_healed.connect(_on_healed)
	Events.buff_gained.connect(_on_buff)
	Events.weapon_equipped.connect(_on_weapon)
	Events.weapon_stowed.connect(_on_weapon_stowed)
	Events.shrine_accepted.connect(_on_shrine)


func _on_haul(amount: int, at: Vector2) -> void:
	FloatingText.spawn(get_parent(), at, "+%d ore" % amount, ORE_COLOUR, 24)


func _on_healed(amount: float) -> void:
	var at: Vector2 = _player_head()
	if at != Vector2.INF:
		FloatingText.spawn(get_parent(), at, "+%d HP" % roundi(amount), HEAL_COLOUR, 28)


func _on_buff(buff: BuffData) -> void:
	var at: Vector2 = _player_head()
	if at != Vector2.INF:
		FloatingText.spawn(get_parent(), at, "%s!" % buff.display_name, buff.colour, 32)


## Shown once per app session, the first time the loadout actually fills — a
## swap hint before there is anything to swap to is noise.
static var _swap_hint_shown: bool = false


func _on_weapon(weapon: WeaponData) -> void:
	var at: Vector2 = _player_head()
	if at == Vector2.INF:
		return
	var colour: Color = weapon.swing_colour
	colour.a = 1.0
	FloatingText.spawn(get_parent(), at, "%s!" % weapon.display_name, colour, 32)


## A quiet stow still deserves a word — the hand did not change, so without
## this the pickup looks like it did nothing. First stow also teaches the swap.
func _on_weapon_stowed(weapon: WeaponData) -> void:
	var at: Vector2 = _player_head()
	if at == Vector2.INF:
		return
	FloatingText.spawn(get_parent(), at, "%s stowed" % weapon.display_name, Color(0.75, 0.72, 0.62), 24)
	if not _swap_hint_shown:
		_swap_hint_shown = true
		FloatingText.spawn(get_parent(), at + Vector2(0, -40), "%s swaps weapons" % Keybinds.hint_for(&"skill_1"), Color(0.8, 0.75, 0.65), 22)


func _on_shrine(shrine: ShrineData) -> void:
	var at: Vector2 = _player_head()
	if at != Vector2.INF:
		FloatingText.spawn(get_parent(), at, "%s!" % shrine.display_name, shrine.colour, 32)


func _player_head() -> Vector2:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return Vector2.INF
	return player.global_position + head_offset
