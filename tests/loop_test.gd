extends Node
## The M5 run-loop economy: extract banks, death forfeits, the vendor spends,
## and meta state persists. This is the greed pillar as code — if extract ever
## stops banking or death stops costing, the whole game's tension is gone and
## nothing else would catch it.
##
## Run: godot --headless --path . res://tests/loop_test.tscn

var _failures: PackedStringArray = []

func _check(c: bool, m: String) -> void:
	if c: print("  PASS  " + m)
	else: _failures.append(m); print("  FAIL  " + m)

func _ready() -> void:
	GameState.reset_save()

	print("extract banks carried haul")
	GameState.begin_run(1, [&"a"])
	GameState.add_haul(10)
	GameState.add_haul(5)
	_check(GameState.carried_haul == 15, "carried accumulates (15)")
	GameState.extract()
	_check(GameState.banked_haul == 15, "extract banks it (15)")
	_check(GameState.carried_haul == 0, "carried cleared on extract")

	print("death forfeits carried, never banked")
	GameState.begin_run(2, [&"a"])
	GameState.add_haul(30)
	GameState.lose_run()
	_check(GameState.carried_haul == 0, "death clears carried")
	_check(GameState.banked_haul == 15, "death does not touch banked")

	print("the vendor spends banked haul")
	GameState.begin_run(3, [&"a"]); GameState.add_haul(100); GameState.extract()
	var up: UpgradeData = load("res://src/systems/upgrades/max_health.tres")
	_check(not GameState.buy_upgrade(up.id, 99999), "cannot buy what you cannot afford")
	var before_bank: int = GameState.banked_haul
	var cost: int = up.cost_for_level(0)
	_check(GameState.buy_upgrade(up.id, cost), "buy level 1")
	_check(GameState.upgrade_level(up.id) == 1, "level becomes 1")
	_check(GameState.banked_haul == before_bank - cost, "banked debited by the cost")
	_check(up.cost_for_level(1) > up.cost_for_level(0), "each level costs more (escalating)")
	_check(up.value_at_level(2) == up.value_at_level(1) * 2.0, "upgrade value scales with level")

	print("meta persists, run state does not")
	var saved: int = GameState.banked_haul
	GameState.banked_haul = -1
	GameState.upgrade_levels.clear()
	GameState.load_game()
	_check(GameState.banked_haul == saved, "banked survives save/reload")
	_check(GameState.upgrade_level(up.id) == 1, "upgrades survive save/reload")

	GameState.reset_save()
	_check(GameState.banked_haul == 0 and GameState.upgrade_level(up.id) == 0, "reset_save wipes meta")

	print("upgrades change gameplay, and depth pays")
	var player: Player = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	await get_tree().physics_frame
	var base_hp: float = player.effective_max_health()
	GameState.upgrade_levels[&"damage"] = 2
	GameState.upgrade_levels[&"armor"] = 3
	GameState.upgrade_levels[&"max_health"] = 1
	_check(is_equal_approx(player.damage_multiplier(), 1.30), "damage upgrade raises outgoing damage")
	_check(player.incoming_multiplier() < 1.0, "armor upgrade lowers incoming damage")
	_check(player.effective_max_health() > base_hp, "max-health upgrade raises max health")
	GameState.upgrade_levels[&"armor"] = 9999
	_check(player.incoming_multiplier() > 0.0, "armor can never reach full invulnerability")
	player.queue_free()

	GameState.depth = 0
	_check(is_equal_approx(GameState.depth_haul_multiplier(), 1.0), "depth 0 pays 1x")
	GameState.depth = 4
	_check(GameState.depth_haul_multiplier() > 2.0, "deep rooms pay more (the pull downward)")
	GameState.reset_save()

	if _failures.is_empty():
		print("\nLOOP TEST OK")
		get_tree().quit(0)
	else:
		printerr("\n%d loop assertion(s) failed" % _failures.size())
		get_tree().quit(1)
