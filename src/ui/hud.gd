extends CanvasLayer
## The one player HUD. Health, carried ore, the weapon loadout, buff timers and
## how deep you are — everything you need to make the greed decision, in icons
## rather than a wall of text.
##
## Weapon loadout reads like Dead Cells: a large square for what is in your
## hand, the stowed weapon nested behind its shoulder, one key to trade them.
## Icons come from WeaponData (baked by tools/gen_icons.py); a weapon with no
## icon falls back to a flat swing-colour square, so missing art degrades
## instead of crashing.
##
## Still a per-scene instance with an exported player (NOT an autoload — the
## scene knows its player, so we skip the group-lookup _ready-order trap).
## Continuous readouts poll in _process; discrete pickup toasts live in
## PickupFeedback, not here.

const PICKAXE_ICON: Texture2D = preload("res://assets/icons/pickaxe.png")

@export var player: Player

@onready var _bar: HealthBar = $Bar
@onready var _health_label: Label = $HealthLabel
@onready var _ore_count: Label = $OreCount
@onready var _ore_icon: TextureRect = $OreIcon
@onready var _active_icon: TextureRect = $WeaponSlots/Active/AIcon
@onready var _secondary: Panel = $WeaponSlots/Secondary
@onready var _secondary_icon: TextureRect = $WeaponSlots/Secondary/SIcon
@onready var _key_hint: Label = $WeaponSlots/KeyHint
@onready var _weapon_name: Label = $WeaponName
@onready var _buff_rows: VBoxContainer = $BuffRows
@onready var _debuff_rows: VBoxContainer = $DebuffRows
@onready var _depth_panel: Panel = $DepthPanel
@onready var _depth: Label = $DepthPanel/Depth


func _ready() -> void:
	if player == null:
		return
	_bar.hide_when_full = false
	_bar.bar_size = Vector2(260, 18)
	_bar.set_ratio(1.0)


func _process(_delta: float) -> void:
	if player == null:
		return
	_bar.set_ratio(player.health / maxf(1.0, player.effective_max_health()))
	_health_label.text = "%d / %d" % [roundi(player.health), roundi(player.effective_max_health())]
	_refresh_weapons()

	# Run-only readouts: ore at risk and depth only mean something mid-delve.
	var in_run: bool = GameState.run_active
	_ore_icon.visible = in_run
	_ore_count.visible = in_run
	_depth_panel.visible = in_run
	if in_run:
		_ore_count.text = str(GameState.carried_haul)
		_depth.text = "Room %d/%d   ore x%.2f" % [
			GameState.depth + 1, maxi(1, GameState.run_plan.size()), GameState.depth_haul_multiplier(),
		]

	_reconcile_rows(_buff_rows, player.active_buffs())
	# Debuffs: scaffolding only. No debuff exists yet — when one does, give the
	# player an active_debuffs() -> [{buff, fraction}] symmetric to active_buffs()
	# (a DebuffData resource, red-styled) and feed it here. The slot is reserved
	# so the layout does not reflow when the first debuff ships.
	_reconcile_rows(_debuff_rows, [])


## Active square always shows the hand (pickaxe by default); the stowed square
## and swap hint only exist once there is genuinely something to trade.
func _refresh_weapons() -> void:
	_apply_icon(_active_icon, player.equipped_weapon)
	_weapon_name.text = player.weapon_name()
	var stowed: WeaponData = _stowed_weapon()
	_secondary.visible = stowed != null
	_key_hint.visible = stowed != null
	if stowed != null:
		_apply_icon(_secondary_icon, stowed)
		_key_hint.text = "%s swap" % Keybinds.label_for(&"skill_1")


func _stowed_weapon() -> WeaponData:
	if player.held_weapons.size() < 2:
		return null
	return player.held_weapons[1 - player.active_slot]


## Weapon icon, or the pickaxe icon for the bare hands default, or a flat
## swing-colour square if a weapon has no art yet.
func _apply_icon(rect: TextureRect, weapon: WeaponData) -> void:
	if weapon == null:
		rect.texture = PICKAXE_ICON
		rect.modulate.a = 1.0
		return
	if weapon.icon != null:
		rect.texture = weapon.icon
	else:
		rect.texture = null
		rect.modulate = weapon.swing_colour


## One row per active timed effect: name plus a shrinking colour bar. Rebuilt by
## reconciliation each frame — cheap, there are never more than a handful.
func _reconcile_rows(rows: VBoxContainer, active: Array[Dictionary]) -> void:
	while rows.get_child_count() < active.size():
		rows.add_child(_make_row())
	for i: int in rows.get_child_count():
		var row: Control = rows.get_child(i) as Control
		row.visible = i < active.size()
		if i < active.size():
			var buff: BuffData = active[i]["buff"]
			var frac: float = active[i]["fraction"]
			var label: Label = row.get_node("Label")
			var bar: ColorRect = row.get_node("Bar")
			label.text = buff.display_name
			label.add_theme_color_override(&"font_color", buff.colour)
			bar.color = buff.colour
			bar.size.x = 150.0 * frac


func _make_row() -> Control:
	var row: Control = Control.new()
	row.custom_minimum_size = Vector2(160, 28)
	var label: Label = Label.new()
	label.name = "Label"
	row.add_child(label)
	var bar: ColorRect = ColorRect.new()
	bar.name = "Bar"
	bar.position = Vector2(0, 20)
	bar.size = Vector2(150, 4)
	row.add_child(bar)
	return row
