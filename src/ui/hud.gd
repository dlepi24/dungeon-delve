extends CanvasLayer
## The one player HUD. Health, carried haul, weapon, buff timers, and how deep
## you are — everything you need to make the greed decision, in one place.
##
## M7 consolidation: this used to be four scattered CanvasLayers (health hud,
## buff hud, dev delve hud, debug overlay) duplicated per scene, half of them
## dev-facing. Now: one player-facing shell, instanced per scene with an
## exported player (NOT an autoload — the scene knows its player, so we skip
## the group-lookup _ready-order trap entirely). The debug overlay stays
## separate and F3-gated because it is a tool, not UI.
##
## Continuous readouts (health, haul, buff fractions) poll in _process — they
## change every frame anyway. Discrete feedback (pickup toasts) is event-driven
## and lives in PickupFeedback, not here.

@export var player: Player

@onready var _bar: HealthBar = $Bar
@onready var _health_label: Label = $HealthLabel
@onready var _haul: Label = $Haul
@onready var _weapon: Label = $Weapon
@onready var _buff_rows: VBoxContainer = $BuffRows
@onready var _debuff_rows: VBoxContainer = $DebuffRows
@onready var _depth: Label = $Depth


func _ready() -> void:
	if player == null:
		return
	_bar.hide_when_full = false
	_bar.bar_size = Vector2(280, 18)
	_bar.set_ratio(1.0)


func _process(_delta: float) -> void:
	if player == null:
		return
	_bar.set_ratio(player.health / maxf(1.0, player.effective_max_health()))
	_health_label.text = "%d / %d" % [roundi(player.health), roundi(player.effective_max_health())]
	_weapon.text = _loadout_text()

	# Run-only rows: haul at risk and depth only mean something mid-delve.
	var in_run: bool = GameState.run_active
	_haul.visible = in_run
	_depth.visible = in_run
	if in_run:
		_haul.text = "Haul: %d" % GameState.carried_haul
		_depth.text = "Room %d/%d   ore x%.2f" % [
			GameState.depth + 1, maxi(1, GameState.run_plan.size()), GameState.depth_haul_multiplier(),
		]

	_reconcile_rows(_buff_rows, player.active_buffs())
	# Debuffs: scaffolding only. No debuff exists yet — when one does, give the
	# player an active_debuffs() -> [{buff, fraction}] symmetric to active_buffs()
	# (a DebuffData resource, red-styled) and feed it here. The slot is reserved
	# so the layout does not reflow when the first debuff ships.
	_reconcile_rows(_debuff_rows, [])


## The weapon line: just the pickaxe until something is found, then both loadout
## slots with their swap keys, the one in hand marked. Key names come from live
## keybinds so a rebind never makes this line lie.
func _loadout_text() -> String:
	if player.held_weapons.is_empty():
		return player.weapon_name()
	var parts: PackedStringArray = []
	for i: int in player.held_weapons.size():
		var key: String = Keybinds.label_for(&"skill_1" if i == 0 else &"skill_2")
		var mark: String = "> " if i == player.active_slot else "  "
		parts.append("%s[%s] %s" % [mark, key, player.held_weapons[i].display_name])
	return "    ".join(parts)


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
