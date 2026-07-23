extends Node
## Background music. Autoloaded as `Music`.
##
## Placeholder synthwave (tools/gen_music.py), swapped for a real track at M9.
## An autoload so it survives scene changes — the track keeps playing across the
## hub<->delve transition instead of restarting every time.
##
## Two tracks: a driving one for the delve, a calmer one for the hub. Switching
## is a soft fade so it does not jump-cut.

## The delve owns three moods; one is drawn per descent so back-to-back runs
## do not share a soundtrack. The reroll is free: the hub track plays between
## runs, so every entry into the mine is a fresh pick. Plain randomness —
## ambience is not gameplay and must not touch the seeded streams.
const DELVE_VARIANTS: Array[String] = [
	"res://assets/audio/music_delve.wav",
	"res://assets/audio/music_delve_b.wav",
	"res://assets/audio/music_delve_c.wav",
	"res://assets/audio/music_delve_d.wav",
	"res://assets/audio/music_delve_e.wav",
]
const HUB: String = "res://assets/audio/music_hub.wav"
## The title bed: calmer and fuller than the hub, so the menu is its own place
## rather than "the hub, arrived at early".
const TITLE: String = "res://assets/audio/music_title.wav"
## The boss vamp: cut in when a boss engages, cut back out when it dies or you
## leave the room.
const BOSS: String = "res://assets/audio/music_boss.wav"

## One-shot stings, fired over the bed at the two moments a run ENDS. The extract
## cue is the one unambiguously hopeful sound in the game; the death cue is the
## punish. Non-looping — a dedicated player fires them and lets them ring out.
const EXTRACT_STING: AudioStream = preload("res://assets/audio/music_extract.wav")
const DEATH_STING: AudioStream = preload("res://assets/audio/music_death.wav")

## Chance to drift to a DIFFERENT delve mood on a room change, so a long run's
## soundtrack breathes instead of looping one bed for five rooms.
@export_range(0.0, 1.0) var room_shuffle_chance: float = 0.35

## Master music level in dB. Music sits under the SFX; -12 is a starting point.
@export var volume_db: float = -12.0
@export var fade_time: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: StringName = &""
var _muted: bool = false
## Context attenuation in dB, set per play() call by the scene that owns the
## moment (0 title, quieter in the hub, quieter still in the delve).
var _attenuation: float = 0.0
## The delve variant currently underground, so the boss fight can hand back to
## the same mood it interrupted.
var _delve_path: String = ""
## The current zone's track pool. While it is non-empty, every delve pick —
## the run-start draw and the room-change drift — comes from HERE, so each
## stratum keeps its own voice for its whole band. Set by zone_entered,
## cleared only by the next zone.
var _zone_tracks: PackedStringArray = PackedStringArray()
var _boss_active: bool = false
## The boss node the active vamp belongs to, so it can be matched back on death.
## Not typed Enemy: the tutorial's TutorialBoss is a separate, non-Enemy class
## that shares the same boss_engaged/enemy_died signals.
var _boss_node: Node2D = null
var _mix_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## A separate player for the one-shot run-end stings, so they ring over the bed's
## crossfade instead of interrupting it.
var _sting: AudioStreamPlayer = null


func _ready() -> void:
	_mix_rng.randomize()
	# Two players so we can crossfade one out while the other comes in. On the
	# Music bus, so the music slider scales the whole score independently of SFX.
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Music"
	add_child(_sting)
	# The mix reacts to the run: bosses cut in their own vamp, and room changes
	# sometimes drift the delve to another mood. Ambience only — unseeded, and
	# nothing here ever feeds back into gameplay.
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.enemy_died.connect(_on_enemy_died)
	Events.room_entered.connect(_on_room_entered)
	Events.zone_entered.connect(_on_zone_entered)
	# The run-end stings — the emotional punctuation of the loop.
	Events.run_extracted.connect(_on_run_extracted)
	Events.run_lost.connect(_on_run_lost)


func _on_boss_engaged(enemy: Node2D) -> void:
	if _boss_active or _current != &"delve":
		return
	_boss_active = true
	_boss_node = enemy
	_crossfade_to(BOSS)


func _on_enemy_died(enemy: Node2D) -> void:
	if not _boss_active or enemy != _boss_node:
		return
	_boss_active = false
	_boss_node = null
	_crossfade_to(_delve_path)


## Extracted alive: the hopeful lift, played a touch above the bed so it reads as
## a win over whatever transition is happening.
func _on_run_extracted(_amount: int) -> void:
	_play_sting(EXTRACT_STING, 0.0)


## Died in the mine: the sinking punish.
func _on_run_lost(_amount: int) -> void:
	_play_sting(DEATH_STING, -2.0)


func _play_sting(stream: AudioStream, offset_db: float) -> void:
	if stream == null:
		return
	_sting.stream = stream
	_sting.volume_db = volume_db + _attenuation + offset_db
	_sting.play()


## The mine changed stratum: adopt the zone's track pool. If the current bed
## already belongs to the new zone, keep playing it — no needless crossfade —
## otherwise glide to one of the zone's own tracks.
func _on_zone_entered(zone: ZoneData) -> void:
	_zone_tracks = zone.music_tracks
	if _current != &"delve" or _boss_active or _zone_tracks.is_empty():
		return
	if _zone_tracks.has(_delve_path):
		return
	_delve_path = _zone_tracks[_mix_rng.randi_range(0, _zone_tracks.size() - 1)]
	_crossfade_to(_delve_path)


## The drift pool: the current zone's tracks when a zone owns the run,
## otherwise the full variant list.
func _delve_pool() -> Array[String]:
	var pool: Array[String] = []
	if _zone_tracks.is_empty():
		pool.assign(DELVE_VARIANTS)
	else:
		for path: String in _zone_tracks:
			pool.append(path)
	return pool


func _on_room_entered(_index: int, _id: String) -> void:
	if _current != &"delve":
		return
	if _boss_active:
		# Fled the boss room with the boss alive: the vamp does not follow you.
		_boss_active = false
		_boss_node = null
		_crossfade_to(_delve_path)
		return
	var pool: Array[String] = _delve_pool()
	if _mix_rng.randf() < room_shuffle_chance and pool.size() > 1:
		pool.erase(_delve_path)
		_delve_path = pool[_mix_rng.randi_range(0, pool.size() - 1)]
		_crossfade_to(_delve_path)


## Play a named track, looping, at a per-context attenuation below the tuned
## bed: the title runs the hub track at full bed, the hub runs it quieter, the
## delve quieter still (Dustin's mix call — menus can be loud, play cannot).
## Re-playing the current track does not restart it, but it DOES fade to the
## new attenuation, which is exactly the title -> hub transition.
func play(track: StringName, attenuation_db: float = 0.0) -> void:
	_attenuation = attenuation_db
	if track == _current:
		if not _players.is_empty():
			_fade(_players[_active], _players[_active].volume_db, _target_db())
		return
	_current = track
	_boss_active = false
	var path: String = HUB
	if track == &"title":
		path = TITLE
	elif track == &"delve":
		# Drop last run's zone pool — this pick is a placeholder for the beat
		# until zone_entered lands (a frame later) and redirects into the new
		# run's first stratum. Without the clear, a run could open on the
		# PREVIOUS run's Deadlight dread.
		_zone_tracks = PackedStringArray()
		path = DELVE_VARIANTS[_mix_rng.randi_range(0, DELVE_VARIANTS.size() - 1)]
		_delve_path = path
	_crossfade_to(path)


## The actual player swap. Everything that changes what is playing goes
## through here — play(), the boss cuts, the room-change drift.
func _crossfade_to(path: String) -> void:
	var stream: AudioStreamWAV = _looped(path)
	if stream == null:
		return

	var incoming: AudioStreamPlayer = _players[1 - _active]
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active

	incoming.stream = stream
	incoming.play()
	_fade(incoming, -80.0, _target_db())
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
	_fade(_players[_active], _players[_active].volume_db, _target_db())


## The level the active player should sit at: the tuned bed plus the per-context
## attenuation, or silence when muted. The user's music slider now lives on the
## Music BUS (Settings drives it), so it no longer folds in here — that keeps the
## player-level mix (fades, boss cuts, attenuation) cleanly separate from volume.
func _target_db() -> float:
	if _muted:
		return -80.0
	return volume_db + _attenuation


func _fade(player: AudioStreamPlayer, from_db: float, to_db: float) -> void:
	player.volume_db = from_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, fade_time)
	if to_db <= -79.0:
		tween.tween_callback(player.stop)
