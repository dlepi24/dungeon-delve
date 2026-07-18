extends CanvasLayer
## The blacksmith's buy screen. Sells weapons for banked haul.
##
## The stock is REROLLED on every visit — a random subset of the weapon pool —
## so the smithy is worth checking after each run, and a run you would rather
## not gamble on drops can start armed instead. Bought weapons go through the
## exact same equip path as found ones: into the loadout, session-scoped, lost
## on death. The blacksmith sells you a head start, not property.
##
## Stock rolls use plain randomness, NOT the seeded service: shop stock is hub
## flavour, and burning seeded draws here would perturb the delve streams that
## daily seeds depend on.

## Everything the smith can stock. A new weapon for sale is a path here (and in
## the enemy drop pool, which deliberately stays its own list — drop-only or
## shop-only weapons are a design lever, not an accident waiting to happen).
const WEAPON_POOL: Array[String] = [
	"res://src/systems/weapons/dagger.tres",
	"res://src/systems/weapons/maul.tres",
	"res://src/systems/weapons/spear.tres",
]

## Weapons on the rack per visit.
@export var stock_size: int = 2

var _stock: Array[WeaponData] = []

@onready var _list: VBoxContainer = $Panel/Margin/Rows/List
@onready var _banked: Label = $Panel/Margin/Rows/Banked
@onready var _close: Button = $Panel/Margin/Rows/Close


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close.pressed.connect(close)
	# Stock is rolled ONCE per surface visit (this panel is rebuilt with the hub
	# scene after every run). Rolling in open() let you close and reopen the
	# shop until it stocked what you wanted, which made the reroll meaningless.
	_roll_stock()
	_rebuild_rows()


func open() -> void:
	_refresh()
	visible = true
	Cursor.menu()


func close() -> void:
	visible = false
	Cursor.gameplay()


## The key that opened the shop closes it, and so does ESC. _input so this wins
## over the pause menu.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _roll_stock() -> void:
	var pool: Array[String] = WEAPON_POOL.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_stock.clear()
	for i: int in mini(stock_size, pool.size()):
		var pick: int = rng.randi_range(0, pool.size() - 1)
		_stock.append(load(pool[pick]) as WeaponData)
		pool.remove_at(pick)


func _rebuild_rows() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for weapon: WeaponData in _stock:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)

		var icon: TextureRect = TextureRect.new()
		icon.texture = weapon.icon
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon)

		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The stats that make weapons feel different, in words a shopper can use.
		label.text = "%s\ndmg %d · wind-up %d ms · reach %d" % [
			weapon.display_name, roundi(weapon.damage), weapon.startup_ms, roundi(weapon.hitbox_size.x),
		]
		row.add_child(label)

		var buy: Button = Button.new()
		buy.custom_minimum_size = Vector2(150, 0)
		buy.pressed.connect(_buy.bind(weapon, buy))
		row.add_child(buy)
		row.set_meta(&"weapon", weapon)
		row.set_meta(&"button", buy)
		_list.add_child(row)


func _buy(weapon: WeaponData, button: Button) -> void:
	if not GameState.spend_banked(weapon.cost):
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.equip_weapon(weapon)
	button.text = "SOLD"
	button.disabled = true
	_refresh()


func _refresh() -> void:
	_banked.text = "Banked haul: %d" % GameState.banked_haul
	for row: Node in _list.get_children():
		var weapon: WeaponData = row.get_meta(&"weapon") as WeaponData
		var button: Button = row.get_meta(&"button") as Button
		if button.disabled:
			continue
		button.text = "Buy  (%d)" % weapon.cost
		button.disabled = not GameState.can_afford(weapon.cost)
