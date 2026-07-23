extends Node
## Global signal bus. Autoloaded as `Events`.
##
## Systems announce what happened here instead of reaching across the tree for
## each other. A shot of decoupling: the player does not know the HUD exists, it
## just reports that it took damage, and whoever cares connects.
##
## Conventions:
## - Signals are past-tense reports of fact, never commands. `player_died`, not
##   `kill_player`. A command signal is just `get_node("../../..")` wearing a hat.
## - Every parameter is statically typed.
## - Add a signal here only when a second system actually needs to hear it.
##   Speculative signals rot.

## A parry landed. M2's hitstop (6 frames, per the feel spec) hangs off this.
signal parry_succeeded

## Any attack connected. `was_riposte` marks the parry payoff so M2 can give it
## heavier hitstop than a normal 3-frame hit. `impact` is the weapon class that
## swung (&"pick"/&"blade"/&"blunt") and `material` is what it hit
## (&"flesh"/&"armor"/&"bone"/&"stone"/&"wood"/&"ecto"). The Sfx layer plays the
## two as separate stacked one-shots — the Dead Cells trick — so a Maul on Armour
## sounds nothing like a Dagger on Flesh. Listeners that don't care (camera,
## shake) simply bind the first two args; Godot drops the rest.
signal hit_landed(damage: float, was_riposte: bool, impact: StringName, material: StringName)

## The player took a hit and entered hitstun.
signal player_hurt(damage: float)

## Movement beats. These exist because Sfx listens to them — the player should
## not have to know audio exists in order to make a sound.
signal player_jumped
## Touchdown, carrying the peak fall speed of the drop just ended (px/s) so the
## Sfx layer can pick a soft scuff for a short hop vs a hard thud for a real fall.
signal player_landed(fall_speed: float)
signal player_rolled

## The player's health changed — current and max, so a listener can act on the
## RATIO without polling. The Sfx layer runs the low-health heartbeat off this;
## fired on damage, healing, and respawn (where it restores to full and stops it).
signal player_health_changed(current: float, max_value: float)

## A swing STARTED (independent of whether it connects). Carries the weapon sound
## class so the Sfx layer plays the matching whoosh — a whiff you can hear is a
## whiff you can learn spacing from, and heavy swings should cut the air heavier.
signal player_attacked(impact: StringName)

## An enemy's poise gave out mid-attack and it was knocked off balance.
signal poise_broken(enemy: Node2D)

## An enemy's health hit zero.
signal enemy_died(enemy: Node2D)

## A boss noticed the player and the fight is on. The HUD raises the big named
## health bar; it lowers itself when the boss dies or stops existing.
signal boss_engaged(enemy: Node2D)

## The player's health hit zero. M5 owns the real run-loss consequences; for now
## the room just puts you back.
signal player_died

## Someone asked for a restart on this seed. The Delve listens, so the pause menu
## does not need to know how a run is assembled.
signal run_restart_requested(seed_value: int)

## Carried haul changed this run. The delve HUD polls carried_haul directly, so
## this is spare capacity for anything that wants the change without polling.
signal haul_changed(carried: int)
## Banked (meta) haul changed — earned by extracting, spent at the shops. The hub
## card listens so it stays live no matter which path moved the number.
signal banked_changed(banked: int)
## Extracted alive: this much haul was banked.
signal run_extracted(amount: int)
## Died in the mine: this much carried haul was lost.
signal run_lost(amount: int)
## A haul pickup was collected in the world.
signal haul_collected(amount: int, at: Vector2)
## The player recovered health (a heart pickup). Amount actually restored, after
## the cap — a heart at full health heals 0 and emits nothing.
signal player_healed(amount: float)
## An upgrade was bought at the vendor.
signal upgrade_purchased(id: StringName, new_level: int)

## A temporary buff was picked up, or expired. The HUD listens.
signal buff_gained(buff: BuffData)
signal buff_expired(id: StringName)

## The player picked up and equipped a weapon this run.
signal weapon_equipped(weapon: WeaponData)
## A picked-up weapon went into the free slot WITHOUT switching hands.
signal weapon_stowed(weapon: WeaponData)

## A shrine bargain was accepted. The HUD lists it; PickupFeedback toasts it.
signal shrine_accepted(shrine: ShrineData)

## A run began, from this seed. The seed is shareable and reproduces the delve.
signal run_started(seed_value: int)
## The run crossed into a new stratum of the mine. Fired by the Delve when the
## depth band changes (including the first room). MineAtmosphere regrades the
## world, Music swaps to the zone's tracks, and the zone title card announces
## it — none of them need a reference to the Delve.
signal zone_entered(zone: ZoneData)
## The player entered room `index` of the plan.
signal room_entered(index: int, room_id: String)
## The last living enemy in the current room fell. The payoff beat: loose loot
## vacuums to the player and the HUD calls it.
signal room_cleared
## Every room in the plan is done.
signal delve_completed
