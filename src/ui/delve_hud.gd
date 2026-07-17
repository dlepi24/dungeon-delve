extends CanvasLayer
## Shows the seed and how deep you are. Dev-facing for now.
##
## The seed is on screen because M4's whole exit criterion is "the same seed
## produces the same delve" — you cannot check that by playing unless you can
## see which seed you are playing.

@onready var _label: Label = $Panel/Margin/Label

var _room_id: String = "?"
var _index: int = 0


func _ready() -> void:
	Events.room_entered.connect(_on_room_entered)
	Events.delve_completed.connect(_on_delve_completed)
	_refresh()


func _on_room_entered(index: int, room_id: String) -> void:
	_index = index
	_room_id = room_id
	GameState.depth = index
	_refresh()


func _on_delve_completed() -> void:
	_room_id = "COMPLETE"
	_refresh()


func _refresh() -> void:
	var plan: String = ""
	for id: StringName in GameState.run_plan:
		plan += "%s " % id
	_label.text = "seed %s\nroom %d/%d  %s   (haul x%.2f)\nplan: %s" % [
		GameState.seed_text(), _index + 1, GameState.run_plan.size(), _room_id,
		GameState.depth_haul_multiplier(), plan.strip_edges(),
	]
