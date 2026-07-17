extends CanvasLayer
## Shows active temporary buffs with a shrinking timer, so you know what you have
## and how long it lasts. Rebuilt each frame from the player's active_buffs() —
## cheap, and there are never more than a handful.

@export var player: Player

@onready var _rows: VBoxContainer = $Rows


func _process(_delta: float) -> void:
	if player == null:
		return
	var active: Array[Dictionary] = player.active_buffs()
	# Reconcile row count with active buff count.
	while _rows.get_child_count() < active.size():
		_rows.add_child(_make_row())
	for i: int in _rows.get_child_count():
		var row: Control = _rows.get_child(i) as Control
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
