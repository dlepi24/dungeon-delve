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
@onready var _top_right: VBoxContainer = $TopRight
@onready var _daily_chip: PanelContainer = $TopRight/DailyChip
@onready var _pips: HBoxContainer = $TopRight/RoomChip/RoomM/RoomRow/Pips
@onready var _room_value: Label = $TopRight/RoomChip/RoomM/RoomRow/RoomValue
@onready var _ore_mult: Label = $TopRight/OreChip/OreM/OreRow/OreMult
@onready var _heat_chip: PanelContainer = $TopRight/HeatChip
@onready var _heat_value: Label = $TopRight/HeatChip/HeatM/HeatRow/HeatValue
@onready var _boss_bar: Control = $BossBar
@onready var _boss_name: Label = $BossBar/BossName
@onready var _boss_fill: ColorRect = $BossBar/BarFill

## The live boss while its bar is up. The bar polls it and lowers itself when
## the boss dies or stops existing (room change, run end).
var _boss: Enemy = null

## Inner fill width when the boss is at full health (BarBack minus the inset).
const BOSS_FILL_WIDTH: float = 794.0


func _ready() -> void:
	Events.boss_engaged.connect(_on_boss_engaged)
	if player == null:
		return
	_bar.hide_when_full = false
	# Shorter and squarer than before; the number rides on top of it now.
	_bar.bar_size = Vector2(152, 15)
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
	_top_right.visible = in_run
	if in_run:
		_ore_count.text = str(GameState.carried_haul)
		_refresh_run_chips()

	_update_boss_bar()
	# Boon column: timed buffs (shrinking bar) plus accepted shrine boons (full
	# bar — they last the run). Bane column: each bargain's price, in red. The
	# column that sat reserved for debuffs since round 1 finally earns its keep.
	var boons: Array[Dictionary] = []
	for entry: Dictionary in player.active_buffs():
		var buff: BuffData = entry["buff"]
		boons.append({"name": buff.display_name, "colour": buff.colour, "fraction": entry["fraction"]})
	var banes: Array[Dictionary] = []
	for shrine: ShrineData in GameState.active_modifiers:
		boons.append({"name": shrine.display_name, "colour": shrine.colour, "fraction": 1.0})
		if shrine.bane_text != "":
			banes.append({"name": shrine.bane_text, "colour": Color(0.95, 0.35, 0.3), "fraction": 1.0})
	_reconcile_rows(_buff_rows, boons)
	_reconcile_rows(_debuff_rows, banes)


func _on_boss_engaged(enemy: Node2D) -> void:
	_boss = enemy as Enemy
	if _boss == null:
		return
	_boss_name.text = _boss.stats.display_name.to_upper()
	_boss_bar.visible = true


func _update_boss_bar() -> void:
	if _boss == null:
		return
	if not is_instance_valid(_boss) or _boss.is_dead():
		_boss = null
		_boss_bar.visible = false
		return
	var ratio: float = clampf(_boss.health / maxf(1.0, _boss.max_health_value()), 0.0, 1.0)
	_boss_fill.size.x = BOSS_FILL_WIDTH * ratio


## The run chips: depth as filled pips (one per planned room), the ore
## multiplier beside its icon, heat as an ember badge that exists only while
## the mine is hot — and breathes when it is furious.
func _refresh_run_chips() -> void:
	_daily_chip.visible = GameState.run_mode == &"daily"
	var rooms: int = maxi(1, GameState.run_plan.size())
	while _pips.get_child_count() < rooms:
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 9)
		_pips.add_child(pip)
	for i: int in _pips.get_child_count():
		var pip: ColorRect = _pips.get_child(i) as ColorRect
		pip.visible = i < rooms
		pip.color = Color(1.0, 0.82, 0.4) if i <= GameState.depth else Color(0.28, 0.24, 0.18)
	_room_value.text = "%d / %d" % [GameState.depth + 1, rooms]
	_ore_mult.text = "x%.2f" % GameState.depth_haul_multiplier()
	var heat: int = GameState.mine_heat
	_heat_chip.visible = heat > 0
	if heat > 0:
		_heat_value.text = str(heat)
		# Past mid-heat the badge breathes — the mine is genuinely angry.
		if heat >= 4:
			var t: float = float(Time.get_ticks_msec()) / 1000.0
			_heat_chip.modulate.a = 0.8 + 0.2 * sin(t * 5.0)
		else:
			_heat_chip.modulate.a = 1.0


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
		_key_hint.text = "%s swap" % Keybinds.hint_for(&"skill_1")


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


## One row per active effect: name plus a colour bar (shrinking for timed
## effects, full for run-long ones). Rows carry plain {name, colour, fraction}
## so buffs and shrine bargains share the renderer. Rebuilt by reconciliation
## each frame — cheap, there are never more than a handful.
func _reconcile_rows(rows: VBoxContainer, active: Array[Dictionary]) -> void:
	while rows.get_child_count() < active.size():
		rows.add_child(_make_row())
	for i: int in rows.get_child_count():
		var row: Control = rows.get_child(i) as Control
		row.visible = i < active.size()
		if i < active.size():
			var colour: Color = active[i]["colour"]
			var edge: ColorRect = row.get_node("Edge")
			var label: Label = row.get_node("Label")
			var bar: ColorRect = row.get_node("Bar")
			label.text = active[i]["name"]
			edge.color = colour
			bar.color = colour
			bar.size.x = 146.0 * float(active[i]["fraction"])


## An effect row is a small chip: dark panel, a colour-coded edge strip, the
## name in HUD text, the remaining time as a thin bar along the bottom. Same
## visual system as everything else on screen — no more naked labels.
func _make_row() -> Control:
	var row: Control = Control.new()
	row.custom_minimum_size = Vector2(172, 30)
	var back: ColorRect = ColorRect.new()
	back.name = "Back"
	back.color = Color(0.03, 0.025, 0.02, 0.72)
	back.size = Vector2(172, 28)
	row.add_child(back)
	var edge: ColorRect = ColorRect.new()
	edge.name = "Edge"
	edge.size = Vector2(4, 28)
	row.add_child(edge)
	var label: Label = Label.new()
	label.name = "Label"
	label.position = Vector2(12, 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_color", Color(0.88, 0.83, 0.72))
	row.add_child(label)
	var bar: ColorRect = ColorRect.new()
	bar.name = "Bar"
	bar.position = Vector2(12, 22)
	bar.size = Vector2(146, 3)
	row.add_child(bar)
	return row
