extends Node
## Background music. Autoloaded as `Music`.
##
## Placeholder synthwave (tools/gen_music.py), swapped for a real track at M9.
## An autoload so it survives scene changes — the track keeps playing across the
## hub<->delve transition instead of restarting every time.
##
## Two tracks: a driving one for the delve, a calmer one for the hub. Switching
## is a soft fade so it does not jump-cut.

const DELVE: String = "res://assets/audio/music_delve.wav"
const HUB: String = "res://assets/audio/music_hub.wav"

## Master music level in dB. Music sits under the SFX; -12 is a starting point.
@export var volume_db: float = -12.0
@export var fade_time: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: StringName = &""
var _muted: bool = false


func _ready() -> void:
	# Two players so we can crossfade one out while the other comes in.
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## Play a named track, looping. No-op if it is already the current one, so
## re-entering the hub does not restart its music.
func play(track: StringName) -> void:
	if track == _current:
		return
	_current = track
	var path: String = DELVE if track == &"delve" else HUB
	var stream: AudioStreamWAV = _looped(path)
	if stream == null:
		return

	var incoming: AudioStreamPlayer = _players[1 - _active]
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active

	incoming.stream = stream
	incoming.play()
	_fade(incoming, -80.0, volume_db if not _muted else -80.0)
	_fade(outgoing, outgoing.volume_db, -80.0)


## Load a WAV and force it to loop. Imported WAVs default to no loop; setting it
## at runtime avoids fiddling with .import files that Godot regenerates.
func _looped(path: String) -> AudioStreamWAV:
	var base: AudioStreamWAV = load(path) as AudioStreamWAV
	if base == null:
		push_error("Music: no stream at %s — run python3 tools/gen_music.py" % path)
		return null
	var stream: AudioStreamWAV = base.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# 16-bit mono: two bytes per frame.
	stream.loop_end = stream.data.size() / 2
	return stream


func set_muted(muted: bool) -> void:
	_muted = muted
	_fade(_players[_active], _players[_active].volume_db, -80.0 if muted else volume_db)


func _fade(player: AudioStreamPlayer, from_db: float, to_db: float) -> void:
	player.volume_db = from_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, fade_time)
	if to_db <= -79.0:
		tween.tween_callback(player.stop)
