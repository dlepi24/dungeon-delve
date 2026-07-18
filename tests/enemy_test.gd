extends Node2D
## Poise, attack selection and jumping.
##
## Poise exists because attack-spam beat everything, which made parry decorative
## and broke a GDD pillar. That regression is invisible — the game still plays,
## it just stops being the game it is supposed to be — so it gets pinned here.
##
## Run: godot --headless --path . res://tests/enemy_test.tscn

const ENEMY: PackedScene = preload("res://src/enemies/enemy.tscn")
const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const GRUNT: String = "res://src/enemies/data/grunt.tres"
const BRUTE: String = "res://src/enemies/data/brute.tres"
const DART: String = "res://src/enemies/data/dart.tres"

var _failures: PackedStringArray = []


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _build_floor() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(6000, 80)
	shape.shape = rect
	shape.position = Vector2(0, 40)
	body.add_child(shape)
	add_child(body)


func _spawn(stats_path: String, at: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY.instantiate()
	enemy.stats = load(stats_path) as EnemyStats
	enemy.global_position = at
	add_child(enemy)
	return enemy


func _poke(enemy: Enemy, poise_damage: float = 12.0) -> void:
	var box: Hitbox = Hitbox.new()
	box.damage = 1.0
	box.poise_damage = poise_damage
	box.global_position = enemy.global_position + Vector2(-30, -20)
	add_child(box)
	enemy.get_node("Hurtbox").take_hit(box)


## How many player-sized pokes it takes to break an attack's poise.
func _pokes_to_break(stats_path: String, attack_index: int) -> int:
	var enemy: Enemy = _spawn(stats_path, Vector2(0, 0))
	await get_tree().physics_frame
	enemy._begin_attack(enemy.stats.attacks[attack_index])
	await get_tree().physics_frame
	var pokes: int = 0
	for i: int in 40:
		if enemy.get_state_name() != "TELEGRAPH" and enemy.get_state_name() != "ATTACK":
			break
		_poke(enemy)
		pokes += 1
		await get_tree().physics_frame
	var broke: bool = enemy.get_state_name() == "STAGGER"
	enemy.queue_free()
	await get_tree().physics_frame
	return pokes if broke else -1


func _ready() -> void:
	_build_floor()
	await _test_poise_scales_with_weight()
	await _test_brute_cannot_be_poked_out_in_real_time()
	await _test_parry_always_breaks_poise()
	await _test_poise_break_gives_no_riposte()
	await _test_flinches_when_not_attacking()
	await _test_flinch_fatigue()
	await _test_attacks_vary_by_range()
	await _test_enemies_jump_for_a_player_above()
	_report()


func _test_poise_scales_with_weight() -> void:
	print("poise scales with weight")
	var dart: int = await _pokes_to_break(DART, 0)
	var grunt: int = await _pokes_to_break(GRUNT, 0)
	var brute: int = await _pokes_to_break(BRUTE, 0)
	print("    pokes to break: dart=%d grunt=%d brute=%d" % [dart, grunt, brute])
	_check(dart > 0 and grunt > 0 and brute > 0, "every attack's poise can be broken eventually")
	_check(dart < grunt and grunt < brute, "light breaks easier than medium breaks easier than heavy")
	_check(dart <= 1, "a single poke interrupts the Dart (got %d)" % dart)


## The real test of the whole mechanic. Poise numbers mean nothing in the
## abstract — what matters is whether you can chip them inside the window the
## attack actually gives you.
func _test_brute_cannot_be_poked_out_in_real_time() -> void:
	print("the Brute cannot be poked out of its swing")
	var stats: EnemyStats = load(BRUTE) as EnemyStats
	var player: Player = PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame

	var attack: EnemyAttackData = stats.attacks[0]
	var window_ms: float = float(attack.telegraph_ms + attack.active_ms)
	var cycle_ms: float = float(player.attack_startup_ms + player.attack_active_ms + player.attack_recovery_ms)
	var swings: float = window_ms / cycle_ms
	var poise_dealt: float = swings * player.attack_poise_damage
	print("    window %.0f ms / attack cycle %.0f ms = %.1f swings = %.0f poise vs %.0f needed" % [window_ms, cycle_ms, swings, poise_dealt, attack.poise])
	_check(poise_dealt < attack.poise,
		"you cannot chip enough poise during the Brute's window — parry or roll is forced")
	player.queue_free()
	await get_tree().physics_frame


func _test_parry_always_breaks_poise() -> void:
	print("a parry breaks poise outright")
	var brute: Enemy = _spawn(BRUTE, Vector2(600, 0))
	await get_tree().physics_frame
	brute._begin_attack(brute.stats.attacks[0])
	await get_tree().physics_frame
	brute._on_parried()
	await get_tree().physics_frame
	_check(brute.get_state_name() == "STAGGER",
		"the heaviest attack in the game still staggers on a parry (state=%s)" % brute.get_state_name())
	brute.queue_free()
	await get_tree().physics_frame


## If breaking poise also opened a riposte, parry would just be a worse attack.
func _test_poise_break_gives_no_riposte() -> void:
	print("a poise break is not a parry")
	var player: Player = PLAYER.instantiate()
	add_child(player)
	var dart: Enemy = _spawn(DART, Vector2(900, 0))
	await get_tree().physics_frame
	player.consume_riposte()
	dart._begin_attack(dart.stats.attacks[0])
	await get_tree().physics_frame
	_poke(dart, 999.0)
	await get_tree().physics_frame
	_check(dart.get_state_name() == "STAGGER", "the poise break staggered it")
	_check(not player.is_riposte_open(), "breaking poise does NOT open a riposte — that is parry's alone")
	player.queue_free()
	dart.queue_free()
	await get_tree().physics_frame


## Poise only covers committed attacks. Outside them the enemy must still flinch,
## or the game drifts from Dead Cells pace to Dark Souls weight.
func _test_flinches_when_not_attacking() -> void:
	print("enemies still flinch when not attacking")
	var brute: Enemy = _spawn(BRUTE, Vector2(1200, 0))
	await get_tree().physics_frame
	_check(brute.get_state_name() == "IDLE", "brute is idle")
	_poke(brute)
	await get_tree().physics_frame
	_check(brute.get_state_name() == "HURT",
		"an idle Brute flinches from one poke despite 90 poise on its swing (state=%s)" % brute.get_state_name())
	brute.queue_free()
	await get_tree().physics_frame


## Dustin's stunlock call (2026-07-17): chaining flinches beat everything
## heavier than a grunt. Only flinch_limit hits may interrupt per window; the
## rest still damage. If this fails, the poke-chain is back and weapon choice
## against heavies is meaningless again.
func _test_flinch_fatigue() -> void:
	print("flinch fatigue stops the infinite poke-chain")
	var brute: Enemy = _spawn(BRUTE, Vector2(600, 0))
	await get_tree().physics_frame
	var start_health: float = brute.health
	var flinches: int = 0
	for i: int in 6:
		_poke(brute, 0.0)
		await get_tree().physics_frame
		if brute.get_state_name() == "HURT":
			flinches += 1
		# Let each flinch expire so the NEXT hit could legally flinch again —
		# what we are proving is the budget, not the hurt-state duration.
		for j: int in 12:
			await get_tree().physics_frame
	_check(flinches == brute.stats.flinch_limit,
		"only the first %d hits interrupt (got %d flinches)" % [brute.stats.flinch_limit, flinches])
	_check(brute.health <= start_health - 5.9, "fatigued hits still deal full damage")
	brute.queue_free()
	await get_tree().physics_frame


func _test_attacks_vary_by_range() -> void:
	print("attacks are chosen by range")
	var grunt: Enemy = _spawn(GRUNT, Vector2(1500, 0))
	var player: Player = PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame

	# Close: only the jab fits. Far: only the lunge.
	player.global_position = grunt.global_position + Vector2(40, 0)
	await get_tree().physics_frame
	var close: EnemyAttackData = grunt._pick_attack()
	player.global_position = grunt.global_position + Vector2(150, 0)
	await get_tree().physics_frame
	var far: EnemyAttackData = grunt._pick_attack()
	print("    at 40 px -> %s;  at 150 px -> %s" % [close.display_name if close else "none", far.display_name if far else "none"])
	_check(close != null and close.display_name == "jab", "close range picks the jab")
	_check(far != null and far.display_name == "lunge", "long range picks the lunge")

	# Out of every band entirely: no attack, so it keeps closing rather than
	# swinging at thin air.
	player.global_position = grunt.global_position + Vector2(400, 0)
	await get_tree().physics_frame
	_check(grunt._pick_attack() == null, "out of range picks nothing")
	grunt.queue_free()
	player.queue_free()
	await get_tree().physics_frame


func _test_enemies_jump_for_a_player_above() -> void:
	print("enemies jump to reach a player above them")
	var grunt: Enemy = _spawn(GRUNT, Vector2(2000, 0))
	var player: Player = PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame
	for i: int in 5:
		await get_tree().physics_frame

	# Park the player well above and to the side; the grunt should leave the floor.
	player.global_position = grunt.global_position + Vector2(60, -160)
	var left_ground: bool = false
	for i: int in 90:
		player.global_position = grunt.global_position + Vector2(60, -160)
		await get_tree().physics_frame
		if not grunt.is_on_floor():
			left_ground = true
			break
	_check(left_ground, "a grunt jumps when the player is on a ledge above it")

	# And the Brute, which cannot jump, must stay put — that is its character.
	var brute: Enemy = _spawn(BRUTE, Vector2(2600, 0))
	await get_tree().physics_frame
	for i: int in 5:
		await get_tree().physics_frame
	var brute_jumped: bool = false
	for i: int in 90:
		player.global_position = brute.global_position + Vector2(60, -160)
		await get_tree().physics_frame
		if not brute.is_on_floor():
			brute_jumped = true
			break
	_check(not brute_jumped, "the Brute cannot jump, so a ledge is a genuine escape from it")
	grunt.queue_free()
	brute.queue_free()
	player.queue_free()
	await get_tree().physics_frame


func _report() -> void:
	if _failures.is_empty():
		print("\nENEMY TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d enemy assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
