extends CanvasLayer
## The vendor's buy screen. Sells permanent upgrades for banked haul.
##
## Rows are built from a list of UpgradeData resources, so a new upgrade for sale
## is a resource in the array, not code here. M5 ships one (max health).

@export var stock: Array[UpgradeData] = []

@onready var _list: VBoxContainer = $Panel/Margin/Rows/List
@onready var _banked: Label = $Panel/Margin/Rows/Banked
@onready var _close: Button = $Panel/Margin/Rows/Close

var _rows: Dictionary[StringName, Button] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close.pressed.connect(close)
	for upgrade: UpgradeData in stock:
		_add_row(upgrade)


func _add_row(upgrade: UpgradeData) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var buy: Button = Button.new()
	buy.custom_minimum_size = Vector2(180, 0)
	buy.pressed.connect(_buy.bind(upgrade))
	row.add_child(buy)
	_list.add_child(row)
	_rows[upgrade.id] = buy
	row.set_meta(&"label", label)
	row.set_meta(&"upgrade", upgrade)


func open() -> void:
	visible = true
	Cursor.menu()
	_refresh()


func close() -> void:
	visible = false
	Cursor.gameplay()


## The key that opened the shop closes it, and so does ESC. _input (not
## _unhandled_input) so this wins over the pause menu — ESC at a stall should
## close the stall, not stack a pause screen over it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _buy(upgrade: UpgradeData) -> void:
	var level: int = GameState.upgrade_level(upgrade.id)
	if level >= upgrade.max_level:
		return
	GameState.buy_upgrade(upgrade.id, upgrade.cost_for_level(level))
	_refresh()


func _refresh() -> void:
	_banked.text = "Banked haul: %d" % GameState.banked_haul
	for row: Node in _list.get_children():
		var upgrade: UpgradeData = row.get_meta(&"upgrade") as UpgradeData
		var label: Label = row.get_meta(&"label") as Label
		var button: Button = _rows[upgrade.id]
		var level: int = GameState.upgrade_level(upgrade.id)
		label.text = "%s  (Lv %d/%d)\n%s" % [upgrade.display_name, level, upgrade.max_level, upgrade.description]
		if level >= upgrade.max_level:
			button.text = "MAXED"
			button.disabled = true
		else:
			var cost: int = upgrade.cost_for_level(level)
			button.text = "Buy  (%d)" % cost
			button.disabled = not GameState.can_afford(cost)
