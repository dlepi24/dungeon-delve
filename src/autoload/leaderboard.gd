extends Node
## The online daily-board client. Autoloaded as `Leaderboard`.
##
## PAYDIRT's competition is async (GDD): everyone races the same UTC daily
## seed; this posts your ranked result and reads the day's board. Design
## stance, non-negotiable: the board is ADDITIVE UI. The game never blocks on
## it, never surfaces a network error as a player-facing failure, and is fully
## playable offline — a failed submit parks in a retry file and goes out on a
## later boot. No accounts: a 12-character handle is the only thing that ever
## leaves the machine.
##
## SERVICE_URL is the deployed Cloudflare Worker (server/leaderboard/ — see
## its README for the three-command deploy). Empty string = the whole system
## is dormant: nothing is sent, and the records screen hides its board
## section. That is also the honest anti-cheat statement: the server clamps
## plausibility and keeps one row per handle per day, nothing more — this is
## a friendly itch board, not an anti-tamper system.

const SERVICE_URL: String = ""
const PENDING_PATH: String = "user://pending_score.json"
const REQUEST_TIMEOUT: float = 8.0
## Board rows the records screen shows; the fetch asks for exactly this many.
const TOP_COUNT: int = 50

signal board_loaded(ok: bool, rows: Array[Dictionary], my_rank: int, total: int)
signal score_submitted(ok: bool)

## Snapshotted at run start, GhostRecorder-style: whether the live run is the
## day's ranked attempt, and which UTC day it ranks into (a run straddling
## midnight ranks into the day it STARTED — same day as its seed).
var _ranked: bool = false
var _date: String = ""
var _fetching: bool = false


func enabled() -> bool:
	return SERVICE_URL != ""


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.run_extracted.connect(func(amount: int) -> void: _finish(amount, true))
	Events.run_lost.connect(func(_amount: int) -> void: _finish(0, false))
	# A submit that failed (offline, service down) retries on the next boot.
	if enabled():
		_retry_pending.call_deferred()


func _on_run_started(_seed_value: int) -> void:
	_ranked = GameState.run_mode == &"daily" and GameState.run_ranked
	_date = GameState.today_string()


## The player's board name. Lazily minted so nobody is ever blocked on picking
## one; editable under OPTIONS. Plain unseeded randomness — hub-flavour rule,
## the seeded streams are for the mine.
func handle() -> String:
	if Settings.daily_handle == "":
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.randomize()
		Settings.set_daily_handle("MINER-%04d" % (generator.randi() % 10000))
	return Settings.daily_handle


## A ranked daily just ended: park the result on disk FIRST, then try to send
## it. Death posts haul 0 (death banks nothing — the board tells the same
## story as the records screen), with room reached as the tiebreak.
func _finish(haul: int, survived: bool) -> void:
	if not _ranked:
		return
	_ranked = false
	var record: Dictionary = {
		"date": _date,
		"handle": handle(),
		"haul": haul,
		"depth": GameState.depth + 1,
		"survived": survived,
	}
	var file: FileAccess = FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record))
		file.close()
	if enabled():
		_submit(record)


func _retry_pending() -> void:
	if not FileAccess.file_exists(PENDING_PATH):
		return
	var reader: FileAccess = FileAccess.open(PENDING_PATH, FileAccess.READ)
	if reader == null:
		return
	var parsed: Variant = JSON.parse_string(reader.get_as_text())
	reader.close()
	if parsed is Dictionary:
		_submit(parsed as Dictionary)


func _submit(record: Dictionary) -> void:
	_request(SERVICE_URL + "/submit", HTTPClient.METHOD_POST, JSON.stringify(record),
		func(ok: bool, _body: PackedByteArray) -> void:
			if ok:
				DirAccess.open("user://").remove(PENDING_PATH.get_file())
			score_submitted.emit(ok))


## Ask for today's board. Result arrives on board_loaded; a failure emits
## ok=false and the UI says "unreachable" — it never throws at the player.
func fetch_board() -> void:
	if not enabled() or _fetching:
		return
	_fetching = true
	var url: String = "%s/board?date=%s&limit=%d" % [SERVICE_URL, GameState.today_string(), TOP_COUNT]
	_request(url, HTTPClient.METHOD_GET, "", _on_board)


func _on_board(ok: bool, body: PackedByteArray) -> void:
	_fetching = false
	if not ok:
		board_loaded.emit(false, [] as Array[Dictionary], -1, 0)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is not Dictionary:
		board_loaded.emit(false, [] as Array[Dictionary], -1, 0)
		return
	var payload: Dictionary = parsed as Dictionary
	var rows: Array[Dictionary] = []
	for entry: Variant in payload.get("rows", []) as Array:
		if entry is Dictionary:
			rows.append(entry as Dictionary)
	# Rank is found client-side in the returned rows (no accounts, so the
	# server cannot know who "you" are). Deeper than TOP_COUNT reads as
	# unranked, which the records screen words honestly.
	var my_rank: int = -1
	for i: int in rows.size():
		if str(rows[i].get("handle", "")) == Settings.daily_handle:
			my_rank = i + 1
			break
	board_loaded.emit(true, rows, my_rank, int(payload.get("total", rows.size())))


## One-shot HTTPRequest wrapper: fire, hand (ok, body) to the callback, clean
## up. Every failure path lands in the callback — no orphaned requests, no
## silent stalls past the timeout.
func _request(url: String, method: HTTPClient.Method, body: String, callback: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
			http.queue_free()
			callback.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, bytes),
		CONNECT_ONE_SHOT)
	var headers: PackedStringArray = PackedStringArray()
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		callback.call(false, PackedByteArray())
