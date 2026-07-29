extends Control
## The Records screen: today's daily result, the best ranked dailies, the best
## free extractions, and the career line — all read from the silent run
## history that has been accumulating since round 4. Logging then, ranking now.

signal closed

@onready var _panel: PanelContainer = $Panel
@onready var _today_value: Label = $Panel/Margin/Rows/TodayValue
@onready var _sep_global: HSeparator = $Panel/Margin/Rows/SepGlobal
@onready var _global_header: Label = $Panel/Margin/Rows/GlobalHeader
@onready var _global: Label = $Panel/Margin/Rows/Global
@onready var _dailies: Label = $Panel/Margin/Rows/Dailies
@onready var _frees: Label = $Panel/Margin/Rows/Frees
@onready var _career: Label = $Panel/Margin/Rows/Career
@onready var _back: Button = $Panel/Margin/Rows/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(func() -> void: closed.emit())
	Leaderboard.board_loaded.connect(_on_board_loaded)
	UiScaler.apply(_panel, Settings.ui_scale, Vector2(0.5, 0.5))
	Settings.ui_scale_changed.connect(func(s: float) -> void: UiScaler.apply(_panel, s, Vector2(0.5, 0.5)))


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	closed.emit()


func open() -> void:
	visible = true
	_rebuild()
	_refresh_global()
	_back.grab_focus()


## The online section: shown only when the Leaderboard is live, filled async.
## Never an error dialog — an unreachable board is one quiet line and the
## local records still carry the screen.
func _refresh_global() -> void:
	var show: bool = Leaderboard.enabled()
	_sep_global.visible = show
	_global_header.visible = show
	_global.visible = show
	if not show:
		return
	_global.text = "Fetching the day's board…"
	Leaderboard.fetch_board()


func _on_board_loaded(ok: bool, rows: Array[Dictionary], my_rank: int, total: int) -> void:
	if not visible:
		return
	if not ok:
		_global.text = "The board is out of reach right now — your score is kept and sent later."
		return
	if rows.is_empty():
		_global.text = "Nobody has ranked today. The mine is all yours."
		return
	var lines: PackedStringArray = []
	for i: int in mini(5, rows.size()):
		var row: Dictionary = rows[i]
		var mark: String = "" if bool(row.get("survived", true)) else "  ·  died"
		lines.append("%d.  %s  —  %d ore  ·  room %d%s" % [
			i + 1, str(row.get("handle", "?")), int(row.get("haul", 0)), int(row.get("depth", 0)), mark,
		])
	if my_rank > 0:
		lines.append("you (%s):  #%d of %d" % [Settings.daily_handle, my_rank, total])
	elif Settings.daily_handle != "":
		lines.append("you (%s):  not in the top %d of %d" % [Settings.daily_handle, Leaderboard.TOP_COUNT, total])
	_global.text = "\n".join(lines)


func _rebuild() -> void:
	var records: Array[Dictionary] = _load_records()
	var today: String = GameState.today_string()

	# Today's ranked daily, if it happened.
	var todays: Dictionary = {}
	var dailies: Array[Dictionary] = []
	var frees: Array[Dictionary] = []
	for record: Dictionary in records:
		var mode: String = str(record.get("mode", "free"))
		var ranked: bool = bool(record.get("ranked", false))
		if mode == "daily" and ranked:
			dailies.append(record)
			if str(record.get("at", "")).begins_with(today):
				todays = record
		elif str(record.get("outcome", "")) == "extracted":
			frees.append(record)

	if todays.is_empty():
		_today_value.text = "Not yet attempted — one ranked run, one shot." \
			if GameState.daily_available() else "Attempt spent; no result recorded."
	else:
		_today_value.text = _line(todays)

	_dailies.text = _top_lines(dailies, 5, "No ranked dailies yet.")
	_frees.text = _top_lines(frees, 5, "No extractions yet.")
	# Best heat survived (BLAZING, 2026-07-23): once heat has no ceiling, this
	# is the number a veteran actually chases — same career line, same read.
	_career.text = "%d runs   ·   deepest room %d   ·   best extract %d   ·   %d kills   ·   best heat %d" % [
		GameState.total_runs, GameState.deepest_room, GameState.best_haul, GameState.total_kills,
		GameState.best_heat_survived,
	]


## Rank: banked haul first (death banks nothing), depth breaks ties.
func _top_lines(records: Array[Dictionary], count: int, empty_text: String) -> String:
	if records.is_empty():
		return empty_text
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("amount", 0)) != int(b.get("amount", 0)):
			return int(a.get("amount", 0)) > int(b.get("amount", 0))
		return int(a.get("room", 0)) > int(b.get("room", 0)))
	var lines: PackedStringArray = []
	for i: int in mini(count, records.size()):
		lines.append("%d.  %s" % [i + 1, _line(records[i])])
	return "\n".join(lines)


func _line(record: Dictionary) -> String:
	var date: String = str(record.get("at", "")).substr(5, 5).replace("-", "/")
	if str(record.get("outcome", "")) == "extracted":
		return "%d ore  ·  room %d  ·  %s" % [int(record.get("amount", 0)), int(record.get("room", 0)), date]
	return "died in room %d, nothing banked  ·  %s" % [int(record.get("room", 0)), date]


func _load_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(GameState.HISTORY_PATH):
		return out
	var reader: FileAccess = FileAccess.open(GameState.HISTORY_PATH, FileAccess.READ)
	if reader == null:
		return out
	while not reader.eof_reached():
		var line: String = reader.get_line()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out
