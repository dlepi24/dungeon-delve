extends CanvasLayer
## The vendor's buy screen. Sells permanent upgrades for banked haul.
##
## Rows are built from a list of UpgradeData resources, so a new upgrade for sale
## is a resource in the array, not code here. M5 ships one (max health).

@export var stock: Array[UpgradeData] = []

@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/Margin/Rows/List
@onready var _banked: Label = $Panel/Margin/Rows/Banked
@onready var _keystone_status: Label = $Panel/Margin/Rows/KeystoneStatus
@onready var _keystones: HBoxContainer = $Panel/Margin/Rows/Keystones
@onready var _close: Button = $Panel/Margin/Rows/Close

var _rows: Dictionary[StringName, Button] = {}
## THE KEYSTONE SYSTEM (2026-07-23): the three build-path identities. Names
## only exist here and in GameState/UpgradeData.keystone_id as plain
## StringNames — there is no KeystoneData resource, since a path is just
## "which existing upgrade(s) get to go past baseline," not new content of
## its own the way a weapon or an enemy is.
const KEYSTONES: Array[StringName] = [&"powderhand", &"ironback", &"tunnel_rat"]
const KEYSTONE_LABELS: Dictionary[StringName, String] = {
	&"powderhand": "Powderhand",
	&"ironback": "Ironback",
	&"tunnel_rat": "Tunnel Rat",
}
var _keystone_buttons: Dictionary[StringName, Button] = {}
var _order: Array[Control] = []
var _nav: MenuNav = MenuNav.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close.pressed.connect(close)
	# THE STARTING CLASS LAYER (2026-07-23): hidden outright pre-extraction,
	# no teaser — same shape as the Hollow Below's entrance in hub.gd (built
	# but invisible until GameState.threshold_open()). This panel is re-
	# instantiated fresh every hub visit, so re-checking here at _ready() is
	# enough; has_extracted can only change mid-delve, never while this is open.
	var keystones_available: bool = GameState.has_extracted
	_keystone_status.visible = keystones_available
	_keystones.visible = keystones_available
	for keystone: StringName in KEYSTONES:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(150, 0)
		button.pressed.connect(_pick_keystone.bind(keystone))
		# The same colour WeaponSprite tints the weapon with (GameState.
		# KEYSTONE_COLOURS) — so the identity reads the same whether you're
		# looking at the shop or the character.
		button.add_theme_color_override(&"font_color", GameState.KEYSTONE_COLOURS.get(keystone, Color.WHITE))
		_keystones.add_child(button)
		_keystone_buttons[keystone] = button
	for upgrade: UpgradeData in stock:
		_add_row(upgrade)
	_order = []
	if keystones_available:
		for keystone: StringName in KEYSTONES:
			_order.append(_keystone_buttons[keystone])
	for upgrade: UpgradeData in stock:
		_order.append(_rows[upgrade.id])
	_order.append(_close)
	MenuNav.disable_builtin_nav(_order)
	UiScaler.apply(_panel, Settings.ui_scale, Vector2(0.5, 0.5))
	Settings.ui_scale_changed.connect(func(s: float) -> void: UiScaler.apply(_panel, s, Vector2(0.5, 0.5)))


func _process(delta: float) -> void:
	if visible:
		_nav.poll(delta, _order)


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
	_close.text = "Close"
	_refresh()
	_focus_first()


## First affordable buy button, else Close — gamepad navigation needs a start.
func _focus_first() -> void:
	for row: Node in _list.get_children():
		var button: Button = _rows.get((row.get_meta(&"upgrade") as UpgradeData).id)
		if button != null and not button.disabled:
			button.grab_focus()
			return
	_close.grab_focus()


func close() -> void:
	visible = false
	Cursor.gameplay()


## The key that opened the shop closes it, and so does ESC/B. _input (not
## _unhandled_input) so this wins over the pause menu — ESC at a stall should
## close the stall, not stack a pause screen over it.
##
## The interact check EXCLUDES presses that double as menu verbs: on a pad,
## A is interact AND ui_accept (it should press the focused buy button, not
## slam the shop), and D-pad up is interact AND ui_up (navigation). Without
## the exclusions, browsing a shop on a controller closed it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var closes: bool = event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
		or (event.is_action_pressed(&"interact")
			and not event.is_action_pressed(&"ui_accept") and not event.is_action_pressed(&"ui_up"))
	if closes:
		get_viewport().set_input_as_handled()
		close()


func _buy(upgrade: UpgradeData) -> void:
	var level: int = GameState.upgrade_level(upgrade.id)
	if level >= upgrade.effective_max_level(GameState.active_keystone):
		return
	GameState.buy_upgrade(upgrade.id, upgrade.cost_for_level(level))
	_refresh()


## Free the first time (nothing to walk away from); scaling banked-haul cost
## every time after, per GameState.respec_cost(). Buttons for the ALREADY
## active keystone are disabled — nothing to switch to.
func _pick_keystone(keystone: StringName) -> void:
	if keystone == GameState.active_keystone:
		return
	GameState.respec_keystone(keystone)
	_refresh()


func _refresh() -> void:
	_banked.text = "Banked haul: %d" % GameState.banked_haul
	var active: StringName = GameState.active_keystone
	if active == &"":
		# This line only ever shows once GameState.has_extracted is true (the
		# row is hidden entirely before that), so it doubles as the "this is
		# new" moment — same permanent-elevated-framing precedent as the
		# Hollow Below's hub prompt, no separate toast/announcement needed.
		_keystone_status.text = "A path has opened up. Choose one — free the first time, and nothing you already own is ever locked."
	else:
		_keystone_status.text = "Path: %s  ·  switch for %d" % [KEYSTONE_LABELS[active], GameState.respec_cost()]
	for keystone: StringName in KEYSTONES:
		var button: Button = _keystone_buttons[keystone]
		if keystone == active:
			button.text = "%s (active)" % KEYSTONE_LABELS[keystone]
			button.disabled = true
		else:
			var cost: int = GameState.respec_cost() if active != &"" else 0
			button.text = "%s  (%s)" % [KEYSTONE_LABELS[keystone], "Free" if cost == 0 else str(cost)]
			button.disabled = not GameState.can_afford(cost)
	for row: Node in _list.get_children():
		var upgrade: UpgradeData = row.get_meta(&"upgrade") as UpgradeData
		var label: Label = row.get_meta(&"label") as Label
		var button: Button = _rows[upgrade.id]
		var level: int = GameState.upgrade_level(upgrade.id)
		var cap: int = upgrade.effective_max_level(active)
		var extended: String = "  [%s]" % KEYSTONE_LABELS[upgrade.keystone_id] if cap > upgrade.max_level else ""
		label.text = "%s  (Lv %d/%d)%s\n%s" % [upgrade.display_name, level, cap, extended, upgrade.description]
		if level >= cap:
			button.text = "MAXED"
			button.disabled = true
		else:
			var cost: int = upgrade.cost_for_level(level)
			button.text = "Buy  (%d)" % cost
			button.disabled = not GameState.can_afford(cost)
