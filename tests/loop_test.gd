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

	print("weapon upgrade changes feel; buffs stack and expire")
	var pl: Player = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	add_child(pl)
	await get_tree().physics_frame
	var base_swing: int = pl.attack_startup_ticks()
	GameState.upgrade_levels[&"damage"] = 5
	_check(pl.attack_speed_multiplier() > 1.0, "weapon upgrade adds attack speed, not just damage")
	_check(pl.attack_startup_ticks() <= base_swing, "faster swing shortens the wind-up")
	GameState.upgrade_levels.clear()
	pl.apply_buff(load("res://src/systems/buffs/might.tres") as BuffData)
	_check(is_equal_approx(pl.damage_multiplier(), 2.0), "Might buff doubles damage")
	pl.reset_for_new_run()
	_check(pl.active_buffs().is_empty(), "buffs clear on a new run")
	pl.queue_free()
	GameState.reset_save()

	print("meta stats track the career")
	GameState.reset_save()
	_check(GameState.total_runs == 0 and GameState.deepest_room == 0
		and GameState.best_haul == 0 and GameState.total_kills == 0, "a fresh save starts at zero")
	GameState.begin_run(7, [&"a", &"b", &"c"])
	GameState.depth = 2
	GameState.add_haul(40)
	Events.enemy_died.emit(null)
	GameState.extract()
	_check(GameState.total_runs == 1, "an extract counts as a finished run")
	_check(GameState.deepest_room == 3, "deepest room recorded, 1-based")
	_check(GameState.best_haul == 40, "best single extract recorded")
	_check(GameState.total_kills == 1, "kills counted via enemy_died")
	GameState.begin_run(8, [&"a"])
	GameState.add_haul(500)
	GameState.lose_run()
	_check(GameState.total_runs == 2, "a death still counts as a finished run")
	_check(GameState.best_haul == 40, "haul lost to death never beats the best extract")
	GameState.total_runs = -1
	GameState.total_kills = -1
	GameState.load_game()
	_check(GameState.total_runs == 2 and GameState.total_kills == 1, "stats survive save/reload")
	GameState.reset_save()
	_check(GameState.total_runs == 0 and GameState.best_haul == 0, "reset_save wipes the stats")

	print("shrine bargains shape the run, then die with it")
	GameState.reset_save()
	GameState.begin_run(11, [&"a"])
	var pl3: Player = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	add_child(pl3)
	await get_tree().physics_frame
	var base_max: float = pl3.effective_max_health()
	var vein: ShrineData = load("res://src/systems/shrines/vein_of_greed.tres")
	GameState.apply_modifier(vein)
	_check(is_equal_approx(GameState.depth_haul_multiplier(), 1.4), "ore bargain multiplies haul at depth 0")
	_check(pl3.effective_max_health() < base_max, "the bane cuts max health")
	GameState.apply_modifier(load("res://src/systems/shrines/blood_pact.tres") as ShrineData)
	_check(pl3.damage_multiplier() > 1.4 and pl3.incoming_multiplier() > 1.0, "bargains stack, boon and bane")
	GameState.add_haul(50)
	_check(GameState.spend_carried(30) and GameState.carried_haul == 20, "pay-now shrines spend carried ore")
	_check(not GameState.spend_carried(999), "cannot pay ore you do not carry")
	GameState.begin_run(12, [&"a"])
	_check(GameState.active_modifiers.is_empty(), "a new run starts unbargained")
	_check(is_equal_approx(pl3.effective_max_health(), base_max), "stats recover when the bargains clear")
	pl3.queue_free()

	print("runs leave a history record")
	GameState.begin_run(13, [&"a", &"b"])
	GameState.depth = 1
	GameState.add_haul(25)
	GameState.extract()
	_check(FileAccess.file_exists(GameState.HISTORY_PATH), "history file exists after a run")
	var reader: FileAccess = FileAccess.open(GameState.HISTORY_PATH, FileAccess.READ)
	var last: String = ""
	while not reader.eof_reached():
		var line: String = reader.get_line()
		if not line.is_empty():
			last = line
	var rec: Dictionary = JSON.parse_string(last)
	_check(rec["outcome"] == "extracted" and int(rec["amount"]) == 25 and int(rec["room"]) == 2,
		"the record carries outcome, amount and depth")
	GameState.reset_save()
	_check(not FileAccess.file_exists(GameState.HISTORY_PATH), "reset_save wipes the history")

	print("mine heat: the extract streak raises stakes, death cools it")
	GameState.reset_save()
	_check(GameState.mine_heat == 0 and is_equal_approx(GameState.heat_health_multiplier(), 1.0),
		"a cold mine scales nothing")
	GameState.begin_run(20, [&"a"]); GameState.extract()
	GameState.begin_run(21, [&"a"]); GameState.extract()
	_check(GameState.mine_heat == 2, "each extraction heats the mine")
	_check(GameState.heat_health_multiplier() > 1.0 and GameState.heat_damage_multiplier() > 1.0,
		"heat toughens enemies")
	_check(GameState.heat_promote_bonus() > 0.0, "heat promotes spawns")
	GameState.depth = 0
	_check(GameState.depth_haul_multiplier() > 1.0, "a hot mine pays for its danger")
	var heat_saved: int = GameState.mine_heat
	GameState.mine_heat = -1
	GameState.load_game()
	_check(GameState.mine_heat == heat_saved, "heat survives save/reload (it is a streak, not a session)")
	GameState.begin_run(22, [&"a"]); GameState.lose_run()
	_check(GameState.mine_heat == 0, "death cools the mine to zero")
	GameState.mine_heat = 999
	_check(GameState.heat_level() == 999, "heat is uncapped (2026-07-23): scaling never stops compounding")
	_check(GameState.past_vein_threshold(), "a streak this hot is past the Vein threshold")
	GameState.reset_save()

	print("the Threshold: Varok's death plus a live heat streak opens the Hollow Below")
	GameState.reset_save()
	_check(not GameState.threshold_open(), "closed with neither the boss kill nor the heat")
	GameState.overseer_defeated = true
	_check(not GameState.threshold_open(), "the boss kill alone is not enough")
	GameState.mine_heat = GameState.heat_threshold_gate
	_check(GameState.threshold_open(), "boss kill plus a live streak at the gate opens it")
	GameState.begin_run(30, [&"a"]); GameState.lose_run()
	_check(not GameState.threshold_open(), "losing the streak closes it again; the boss kill stays permanent")
	_check(GameState.overseer_defeated, "beating Varok never has to happen twice")
	GameState.reset_save()

	print("depth scaling: enemies toughen with THIS run's depth, apart from heat")
	GameState.reset_save()
	GameState.depth = 0
	_check(is_equal_approx(GameState.depth_health_multiplier(), 1.0), "no depth, no bonus")
	GameState.depth = 4
	_check(GameState.depth_health_multiplier() > 1.0 and GameState.depth_damage_multiplier() > 1.0,
		"depth toughens enemies independent of heat")
	GameState.depth = 0
	GameState.reset_save()

	print("zone ore bonus: a zone can charge a premium on top of depth/heat (2026-07-23)")
	GameState.reset_save()
	var base_multiplier: float = GameState.depth_haul_multiplier()
	GameState.zone_ore_bonus = 0.5
	_check(is_equal_approx(GameState.depth_haul_multiplier(), base_multiplier * 1.5),
		"a zone's ore_bonus multiplies on top of the existing depth/heat/modifier math")
	GameState.end_run()
	_check(is_equal_approx(GameState.zone_ore_bonus, 0.0), "end_run resets the zone bonus, same as depth")
	GameState.reset_save()

	print("the keystone system: nothing is locked, but only your path goes past baseline (2026-07-23)")
	GameState.reset_save()
	var damage: UpgradeData = load("res://src/systems/upgrades/damage.tres") as UpgradeData
	var armor: UpgradeData = load("res://src/systems/upgrades/armor.tres") as UpgradeData
	_check(damage.effective_max_level(&"") == 5, "no keystone chosen: damage caps at baseline")
	_check(damage.effective_max_level(&"ironback") == 5, "the WRONG keystone still only grants baseline")
	_check(damage.effective_max_level(&"powderhand") == 10, "the MATCHING keystone unlocks the extended cap")
	_check(armor.effective_max_level(&"powderhand") == 5,
		"picking powderhand does not touch armor's cap — nothing is locked, but nothing else is boosted either")
	_check(GameState.respec_cost() == 0, "picking a keystone for the first time is free")
	_check(GameState.respec_keystone(&"powderhand"), "the first pick succeeds with zero banked haul")
	_check(GameState.active_keystone == &"powderhand", "active_keystone is set")
	_check(GameState.respec_cost() == 0, "still free to switch again before investing anything")
	GameState.upgrade_levels[&"damage"] = 8  # 3 levels past the 5-level baseline
	_check(GameState.extended_levels_bought() == 3, "extended_levels_bought counts only levels past baseline")
	_check(GameState.respec_cost() == GameState.respec_base_cost + GameState.respec_cost_per_level * 3,
		"respec cost scales with how much is invested past baseline")
	GameState.banked_haul = 0
	_check(not GameState.respec_keystone(&"ironback"), "cannot respec without enough banked haul")
	_check(GameState.active_keystone == &"powderhand", "a failed respec leaves the active keystone untouched")
	GameState.banked_haul = GameState.respec_cost()
	_check(GameState.respec_keystone(&"ironback"), "affording the cost lets the respec through")
	_check(GameState.active_keystone == &"ironback", "active_keystone actually switched")
	_check(GameState.banked_haul == 0, "the respec cost was actually spent")
	_check(GameState.upgrade_level(&"damage") == 8,
		"levels already bought are never lost or refunded by a respec")
	_check(damage.effective_max_level(GameState.active_keystone) == 5,
		"but no FURTHER damage levels are buyable now that powderhand is no longer active")
	GameState.end_run()
	GameState.reset_save()
	_check(GameState.active_keystone == &"", "reset_save clears the active keystone")

	print("the starting-class instant bonus: picking a path does something the moment you pick it (2026-07-23)")
	GameState.reset_save()
	GameState.respec_keystone(&"powderhand")
	_check(GameState.upgrade_level(&"damage") == 4, "powderhand grants damage straight to 4/10")
	_check(GameState.upgrade_level(&"armor") == 0 and GameState.upgrade_level(&"mobility") == 0,
		"every other stat is untouched by the bonus")
	GameState.reset_save()
	GameState.upgrade_levels[&"damage"] = 2
	GameState.respec_keystone(&"powderhand")
	_check(GameState.upgrade_level(&"damage") == 4,
		"a player who already bought below the bonus floor gets topped up to it")
	GameState.reset_save()
	GameState.upgrade_levels[&"damage"] = 5
	GameState.respec_keystone(&"powderhand")
	_check(GameState.upgrade_level(&"damage") == 5,
		"a player who already bought PAST the bonus floor keeps their real levels — maxi, never a downgrade")
	GameState.reset_save()
	GameState.respec_keystone(&"ironback")
	_check(GameState.upgrade_level(&"armor") == 2 and GameState.upgrade_level(&"max_health") == 2,
		"ironback splits its bonus across both stats it governs, 2 each")
	GameState.reset_save()
	GameState.respec_keystone(&"tunnel_rat")
	_check(GameState.upgrade_level(&"mobility") == 4, "tunnel_rat grants mobility straight to 4/10")
	GameState.reset_save()

	print("the bonus cannot be farmed by respeccing away and back")
	GameState.reset_save()
	GameState.respec_keystone(&"powderhand")
	GameState.upgrade_levels[&"damage"] = 9  # simulate real purchases past the bonus floor
	GameState.banked_haul = 100000
	GameState.respec_keystone(&"tunnel_rat")
	GameState.respec_keystone(&"powderhand")
	_check(GameState.upgrade_level(&"damage") == 9,
		"switching back to an already-unlocked keystone does not re-grant or touch the bonus")
	_check(GameState.keystones_unlocked.get(&"powderhand", false) and GameState.keystones_unlocked.get(&"tunnel_rat", false),
		"both keystones visited this save are marked unlocked")
	var unlocked_before: bool = GameState.keystones_unlocked.get(&"powderhand", false)
	GameState.save_game()
	GameState.keystones_unlocked.clear()
	GameState.load_game()
	_check(GameState.keystones_unlocked.get(&"powderhand", false) == unlocked_before,
		"keystones_unlocked survives save/reload — the farming guard is not just an in-memory fluke")
	GameState.reset_save()
	_check(GameState.keystones_unlocked.is_empty(), "reset_save wipes keystones_unlocked, same as active_keystone")

	print("has_extracted: the progress gate for the vendor's keystone row (2026-07-23)")
	GameState.reset_save()
	_check(not GameState.has_extracted, "a fresh save has not extracted")
	GameState.begin_run(20, [&"a"]); GameState.lose_run()
	_check(not GameState.has_extracted, "dying does not count — only a real extraction opens the gate")
	GameState.begin_run(21, [&"a"]); GameState.extract()
	_check(GameState.has_extracted, "extracting sets the flag")
	GameState.save_game()
	GameState.has_extracted = false
	GameState.load_game()
	_check(GameState.has_extracted, "has_extracted survives save/reload")
	GameState.reset_save()
	_check(not GameState.has_extracted, "reset_save wipes has_extracted, same as every other permanent flag")

	print("the daily delve is one clean ranked shot")
	GameState.reset_save()
	GameState.mine_heat = 5
	var pl4: Player = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	add_child(pl4)
	await get_tree().physics_frame
	var stash: Array[WeaponData] = [load("res://src/systems/weapons/dagger.tres") as WeaponData]
	GameState.store_loadout(stash, 0)
	GameState.pending_mode = &"daily"
	GameState.begin_run(99, [&"a"])
	_check(GameState.run_mode == &"daily" and GameState.run_ranked, "first daily of the day is the ranked attempt")
	_check(GameState.heat_level() == 0 and is_equal_approx(GameState.heat_health_multiplier(), 1.0),
		"the daily plays at heat 0 whatever the streak")
	pl4.reset_for_new_run()
	_check(pl4.held_weapons.is_empty() and pl4.weapon_name() == "Pickaxe",
		"the daily starts on the bare pickaxe")
	_check(GameState.session_weapons.size() == 1, "the session stash waits untouched for free play")
	GameState.extract()
	_check(GameState.mine_heat == 5, "daily extraction leaves the heat streak alone")
	GameState.pending_mode = &"daily"
	GameState.begin_run(99, [&"a"])
	_check(not GameState.run_ranked, "a second daily today is practice, not ranked")
	GameState.lose_run()
	_check(GameState.mine_heat == 5, "daily death does not cool the mine")
	_check(GameState.session_weapons.size() == 1, "daily death does not spend the free-play loadout")
	pl4.queue_free()
	GameState.reset_save()
	_check(GameState.daily_available(), "reset_save returns the daily attempt")

	if _failures.is_empty():
		print("\nLOOP TEST OK")
		get_tree().quit(0)
	else:
		printerr("\n%d loop assertion(s) failed" % _failures.size())
		get_tree().quit(1)
