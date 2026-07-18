class_name Player
extends CharacterBody2D
## Gray-box player: move, jump, roll. Combat verbs land after the M1 feel gate.
##
## DETERMINISM: every timing window here is counted in physics ticks, never in
## wall-clock milliseconds. The GDD requires identical output from identical
## inputs so daily seeds and ghost replays work, and Time.get_ticks_msec() drifts
## with framerate. The @export knobs are still in milliseconds, because that is
## how the feel spec is written and how it is easiest to reason about — the
## conversion to ticks happens here, in ms_to_ticks().
##
## TUNING: derived values (gravity, tick windows) are recomputed every physics
## frame rather than cached in _ready. That costs a few multiplies and means
## editing an export in the inspector changes the feel instantly, mid-play,
## without a restart. That live loop is the entire point of the workflow.

## Actions that queue instead of being dropped. Movement is not buffered — you
## hold a direction, you do not fire it.
const BUFFERED_ACTIONS: PackedStringArray = ["jump", "roll", "attack", "parry"]

@export_group("Run")
## Top horizontal speed, px/s.
@export var max_run_speed: float = 340.0
## Acceleration toward top speed on the ground, px/s². Higher = twitchier start.
@export var ground_acceleration: float = 2600.0
## Deceleration on the ground with no input, px/s². Higher = less ice-skating.
@export var ground_friction: float = 3200.0
## Air control authority, px/s².
@export var air_acceleration: float = 1900.0
## Drag in the air with no input, px/s². Keep low or the air feels sticky.
@export var air_friction: float = 500.0

@export_group("Jump")
## Peak height of a full-hold jump, px. Gravity is derived from this and the two
## timings below, so you tune the shape of the arc you want rather than guessing
## at a gravity constant.
@export var jump_height: float = 104.0
## Seconds from leaving the ground to the top of a full-hold jump.
@export var jump_time_to_peak: float = 0.36
## Seconds from the peak back down to ground height. Setting this lower than
## time_to_peak gives the classic snappy platformer arc: floaty up, quick down.
@export var jump_time_to_fall: float = 0.28
## Fraction of upward velocity kept when you release jump early. Lower = more
## height variation between a tap and a hold.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
## Terminal velocity, px/s.
@export var max_fall_speed: float = 1000.0

@export_group("Feel")
## GDD feel spec: 100 ms. Presses fire when they become legal instead of dropping.
@export var input_buffer_ms: int = 100
## GDD feel spec: 80 ms. Jump stays legal briefly after walking off a ledge.
@export var coyote_ms: int = 80

@export_group("Roll")
## GDD feel spec: ~350 ms total.
@export var roll_duration_ms: int = 350
## GDD feel spec: i-frames cover roughly the middle 200 ms, i.e. 75..275 of 350.
@export var roll_iframe_start_ms: int = 75
@export var roll_iframe_duration_ms: int = 200
## Roll speed, px/s.
@export var roll_speed: float = 480.0
## OPEN DESIGN QUESTION — Dustin's call, not mine. The GDD says roll is "always
## available", which read literally includes mid-air, but air-rolling changes
## platforming substantially and the GDD never actually says so. Defaulting to
## off. Flip it, feel both, and whichever wins goes in the GDD decision log.
@export var allow_air_roll: bool = false

@export_group("Attack")
## Wind-up before the hitbox opens. This is the "weight" the GDD asks for: raise
## it and attacks commit harder, lower it and they get twitchy.
@export var attack_startup_ms: int = 90
## How long the hitbox stays open.
@export var attack_active_ms: int = 80
## Tail you are locked into after the hitbox closes. This is the punish window.
@export var attack_recovery_ms: int = 180
## When cancel-into-roll becomes legal, measured from the start of the attack.
## The GDD calls where this window sits a PRIMARY TUNING KNOB. Default 170 ms is
## exactly when the hitbox closes: swing, connect, bail. Push it later and
## attacking gets genuinely committal; pull it earlier and you can cancel out of
## your own active frames, which usually feels cheap.
@export var attack_cancel_start_ms: int = 170
@export var attack_damage: float = 12.0
## How much enemy poise a swing chips. Equal to damage by default, so the poise
## numbers on enemies read directly as "how many pokes to break". Lower it to
## make enemies harder to stagger without making them tankier.
@export var attack_poise_damage: float = 12.0
## Fraction of run speed you keep while swinging. Low values plant your feet.
@export_range(0.0, 1.0) var attack_move_control: float = 0.15
## Hitbox position relative to the player, mirrored by facing.
@export var attack_hitbox_offset: Vector2 = Vector2(34, -28)

@export_group("Parry")
## GDD feel spec: 120 ms. The greedy window.
@export var parry_active_ms: int = 120
## GDD feel spec: ~300 ms. Whiff this and you are punishable — roll deliberately
## does NOT cancel it, or the whiff would carry no risk and parry would stop
## being a decision.
@export var parry_whiff_recovery_ms: int = 300
## How long the riposte stays open after a successful parry.
@export var riposte_window_ms: int = 700
## Damage multiplier on a riposte attack. Set to 1.0 to feel a stagger-only
## parry with no damage reward.
@export var riposte_damage_multiplier: float = 3.0

@export_group("Health")
## Base max health before permanent upgrades. The vendor's max_health upgrade
## adds to this, so a player who has banked haul into it starts tougher.
@export var max_health: float = 100.0
## The max-health upgrade resource, so the bonus per level stays data, not a magic
## number here. Optional — if unset (e.g. the gym), only base health applies.
@export var max_health_upgrade: UpgradeData
## Permanent damage upgrade. Multiplies outgoing attack damage. Data, not a magic
## number, so the vendor and the effect read from the same resource.
@export var damage_upgrade: UpgradeData
## Permanent armor upgrade. Reduces incoming damage. Capped below 100% by the
## resource's max_level, so armor can never make you invincible.
@export var armor_upgrade: UpgradeData
## Attack-speed granted by the DAMAGE upgrade, per level. This is the fix for
## "the weapon upgrade does more damage but feels the same": a Honed Pick also
## swings faster, so upgrading it changes the feel of combat, not just the number
## over an enemy's head. Kept modest so five levels is +30%, not a machine gun.
@export var weapon_speed_per_level: float = 0.06
## How long the death beat lasts before the run hands off to the hub. Long enough
## that a death registers, short enough that it does not drag.
@export var death_beat_ms: int = 900

@export_group("Hitstun")
@export var hitstun_ms: int = 250
@export var hitstun_knockback: float = 220.0
@export var hitstun_pop: float = 120.0

@export_group("Juice")
## GDD feel spec: 3 frames on a normal hit, 6 on a parry. "Half of crunchy lives
## here." Counted in physics ticks, which at the locked 60 Hz are frames.
@export var hitstop_hit_frames: int = 3
@export var hitstop_parry_frames: int = 6
@export var hitstop_hurt_frames: int = 4
## Squash on landing: wide and short. Scales from the feet.
@export var land_squash: Vector2 = Vector2(1.3, 0.72)
## Stretch on take-off: tall and thin.
@export var jump_stretch: Vector2 = Vector2(0.76, 1.28)
## Held for the duration of a roll, on top of the tumble.
@export var roll_squash: Vector2 = Vector2(1.22, 0.78)
## Squash when you connect with something.
@export var attack_punch: Vector2 = Vector2(1.18, 0.86)

## +1 right, -1 left. Combat will read this for attack direction.
var facing: int = 1
## Driven by the roll's i-frame window. Nothing can hurt us yet; the overlay
## draws it so the window can be tuned before enemies exist to test it against.
var invulnerable: bool = false

## Direction the last hit came from, +1 if it pushed us right. Hitstun reads it.
var last_hit_direction: int = 1
## 0..1 through the current roll. Written by the Roll state, read by _process to
## drive the tumble. Visual only.
var roll_progress: float = 0.0

var _tick: int = 0
## Deliberately far in the past so we do not start the game holding a coyote jump.
var _last_grounded_tick: int = -10000
var _riposte_until_tick: int = -10000
var _buffer: InputBuffer

var _jump_velocity: float = 0.0
var _jump_gravity: float = 0.0
var _fall_gravity: float = 0.0

var health: float = 0.0

var _was_on_floor: bool = true
var _spawn_position: Vector2 = Vector2.ZERO
var _dead: bool = false
var _death_handoff_tick: int = 0

@onready var _state_machine: PlayerStateMachine = $StateMachine
@onready var _juice: BodyJuice = $VisualRoot
@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var hurtbox: Hurtbox = $Hurtbox


## Joining the group here rather than in _ready is load-bearing, not style.
##
## Godot runs _enter_tree for EVERY node in a scene before it runs any _ready. A
## sibling whose _ready fires before ours — the Delve does, because it sits above
## us in delve_run.tscn — would look us up and find nothing. That is exactly what
## happened: the Delve, every Room and every Enemy all resolved a null player, so
## enemies never moved, exits never triggered, and the player was never placed at
## the room entry. None of it errored; it just quietly did nothing.
func _enter_tree() -> void:
	add_to_group(&"player")


func _ready() -> void:
	health = effective_max_health()
	_spawn_position = global_position
	_buffer = InputBuffer.new(BUFFERED_ACTIONS)
	_state_machine.setup(self)
	attack_hitbox.deactivate()
	hurtbox.hurt.connect(_on_hurt)
	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)


func _physics_process(delta: float) -> void:
	# Poll the buffer even while frozen, so a press during hitstop is remembered
	# rather than eaten. Everything else stops dead.
	_buffer.poll(_tick)
	if Hitstop.is_frozen():
		return

	_tick += 1
	_recalculate_derived()

	# Once dead, hold still for a beat, then hand off to the run coordinator. The
	# player does NOT decide what death costs — GameState and the run loop do.
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.y += _fall_gravity * delta
		move_and_slide()
		if _tick >= _death_handoff_tick:
			_death_handoff_tick = 0x7FFFFFFF  # fire once
			Events.player_died.emit()
		return

	if is_on_floor():
		_last_grounded_tick = _tick

	_tick_buffs()
	_handle_weapon_select()
	_update_landing_juice()

	var off: Vector2 = weapon_hitbox_offset()
	attack_hitbox.position = Vector2(off.x * float(facing), off.y)

	_state_machine.physics_update(delta)
	move_and_slide()


## The hurtbox reports; the active state decides what a hit means. i-frames are
## checked here because they apply regardless of state.
func _on_hurt(hitbox: Hitbox) -> void:
	if invulnerable or _dead:
		return
	last_hit_direction = 1 if hitbox.global_position.x < global_position.x else -1
	_state_machine.handle_hit(hitbox)
	# Landing in Hitstun is the definition of "that hurt". A parry sends us to
	# Idle instead, so a good read costs nothing — no flash, no shake, no freeze.
	if _state_machine.get_current_name() != &"Hitstun":
		return

	Hitstop.request(hitstop_hurt_frames)
	_juice.flash()
	Rumble.hurt()
	var taken: float = hitbox.damage * incoming_multiplier()
	health = maxf(0.0, health - taken)
	Events.player_hurt.emit(taken)
	# Show the damage you actually took, over your own head — this is how armor
	# becomes visible. Without a number, a 6% reduction is invisible and reads as
	# "armor does nothing".
	var host: Node = get_parent()
	if host != null:
		DamageNumber.spawn(host, global_position - Vector2(0, 70), taken, false)
	if health <= 0.0:
		_die()


## Restore health, capped at the effective maximum. A heart pickup calls this.
## Flashes so a heal reads as a heal, not just a number ticking up.
func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var before: float = health
	health = minf(effective_max_health(), health + amount)
	_juice.flash()
	if health > before:
		Events.player_healed.emit(health - before)


## Base health plus whatever the persistent max-health upgrade adds, scaled by
## any shrine bargain that traded max health away. Reading it through the
## resource keeps the per-level value as data, not a constant here.
func effective_max_health() -> float:
	return (max_health + _upgrade_value(max_health_upgrade)) * GameState.modifier_product(&"max_health_mult")


## Outgoing damage: permanent upgrade times buffs times shrine bargains.
## Central so the attack, the buffs and the vendor all agree.
func damage_multiplier() -> float:
	return (1.0 + _upgrade_value(damage_upgrade)) * _buff_product(&"damage_mult") \
		* GameState.modifier_product(&"damage_mult")


## Fraction of incoming damage that gets through: permanent armor times buff
## armor times shrine banes. Clamped above zero unless a buff grants outright
## invulnerability — a bargain can raise it past 1, that is the price.
func incoming_multiplier() -> float:
	var buffed: float = _buff_product(&"incoming_mult")
	if buffed <= 0.0:
		return 0.0
	return maxf(0.05, (1.0 - _upgrade_value(armor_upgrade)) * buffed * GameState.modifier_product(&"incoming_mult"))


## Move-speed multiplier from active buffs and shrine bargains. 1.0 with none.
func move_speed_multiplier() -> float:
	return _buff_product(&"move_mult") * GameState.modifier_product(&"move_mult")


## Attack-speed multiplier: the weapon upgrade's per-level bonus, times buffs,
## times bargains. Higher = faster swings. Attack states divide timings by this.
func attack_speed_multiplier() -> float:
	var weapon: float = 1.0 + float(GameState.upgrade_level(&"damage")) * weapon_speed_per_level
	return weapon * _buff_product(&"attack_speed_mult") * GameState.modifier_product(&"attack_speed_mult")


## Attack timing helpers: the equipped weapon's ms, scaled by attack speed, to
## ticks. The attack state reads these so a heavy Maul is genuinely slow and a
## Dagger genuinely fast, and so speed buffs and the weapon upgrade shorten both.
func attack_startup_ticks() -> int:
	return ms_to_ticks(roundi(float(_w_startup()) / attack_speed_multiplier()))
func attack_active_ticks() -> int:
	return ms_to_ticks(roundi(float(_w_active()) / attack_speed_multiplier()))
func attack_recovery_ticks() -> int:
	return ms_to_ticks(roundi(float(_w_recovery()) / attack_speed_multiplier()))
func attack_cancel_ticks() -> int:
	return ms_to_ticks(roundi(float(_w_cancel()) / attack_speed_multiplier()))


# --- Weapons ---
# The player's own exports ARE the base pickaxe. Equipping a WeaponData overrides
# them for the run; a null equipped_weapon means the pickaxe. Found weapons are
# run-scoped: reset_for_new_run drops back to the pickaxe, while permanent stat
# upgrades persist. That is the roguelite split — the weapon is this run's flavour.
#
# M7: you hold up to TWO found weapons (a loadout) and swap live with ONE key
# (skill_1, Q by default) that toggles between them — one verb, like Dead
# Cells' backpack swap, rather than one key per slot you have to remember.
# equipped_weapon stays the single source of truth for "what am I swinging";
# held_weapons is just where the inactive one waits.

## Base pickaxe hitbox size when no weapon is equipped. Matches player.tscn.
@export var base_hitbox_size: Vector2 = Vector2(46, 44)

const MAX_HELD_WEAPONS: int = 2

var equipped_weapon: WeaponData = null
## Found weapons this run, in slot order. Empty = pickaxe only.
var held_weapons: Array[WeaponData] = []
## Which slot of held_weapons is in hand. Meaningless while held_weapons is empty.
var active_slot: int = 0


## Take a weapon (Dustin's inventory call, 2026-07-17 evening):
## - Bare pickaxe: it goes straight to hand — anything beats nothing.
## - Free second slot: it is STOWED quietly. Your hand is never switched by
##   walking over loot; the stowed square and a toast say it arrived.
## - Loadout full: replaces the STOWED weapon and comes up in hand. Pickups
##   only reach this branch deliberately (a full loadout stops auto-collect
##   and demands an interact press over the weapon — see pickup.gd), so a
##   honed blade can no longer be vacuumed away mid-fight.
func equip_weapon(weapon: WeaponData) -> void:
	if held_weapons.is_empty():
		held_weapons.append(weapon)
		active_slot = 0
		_wield(weapon)
		return
	if held_weapons.size() < MAX_HELD_WEAPONS:
		held_weapons.append(weapon)
		GameState.store_loadout(held_weapons, active_slot)
		Events.weapon_stowed.emit(weapon)
		return
	active_slot = 1 - active_slot
	held_weapons[active_slot] = weapon
	_wield(weapon)


func loadout_full() -> bool:
	return held_weapons.size() >= MAX_HELD_WEAPONS


## What a full-loadout pickup would discard: the weapon you are NOT holding.
func stowed_weapon() -> WeaponData:
	if held_weapons.size() < MAX_HELD_WEAPONS:
		return null
	return held_weapons[1 - active_slot]


## Swap to a loadout slot. No-op on an empty slot or the slot already in hand.
func select_weapon_slot(slot: int) -> void:
	if slot < 0 or slot >= held_weapons.size() or slot == active_slot:
		return
	active_slot = slot
	_wield(held_weapons[slot])


func _wield(weapon: WeaponData) -> void:
	equipped_weapon = weapon
	_resize_attack_hitbox()
	_juice.flash()
	# Every loadout change is mirrored to the session stash, so extraction
	# "banks" weapons for free — the next scene's player rebuild reads it back.
	GameState.store_loadout(held_weapons, active_slot)
	Events.weapon_equipped.emit(weapon)


## Blacksmith service: sharpen the weapon in hand. Mutates a DUPLICATE of the
## resource — the .tres on disk is shared by every future drop and shop rack
## and must never change. The honed copy rides the session stash like any
## weapon: banked by extraction, lost to death.
func hone_equipped_weapon() -> bool:
	if equipped_weapon == null:
		return false
	var honed: WeaponData = equipped_weapon.duplicate() as WeaponData
	honed.damage *= 1.15
	honed.poise_damage *= 1.15
	honed.hone_level += 1
	var base_name: String = equipped_weapon.display_name.split(" +")[0]
	honed.display_name = "%s +%d" % [base_name, honed.hone_level]
	held_weapons[active_slot] = honed
	_wield(honed)
	return true


## Swap is a physics-tick input like every other verb (determinism: ghost
## replays must see it). Blocked mid-swing on purpose: the attack state reads
## its timing windows LIVE each tick, so swapping Maul -> Dagger mid-recovery
## would shrink the remaining recovery and become a swap-cancel — free escape
## from the commitment the GDD makes attacks carry. Swap first, then swing.
func _handle_weapon_select() -> void:
	if _state_machine.get_current_name() == &"Attack":
		return
	if Input.is_action_just_pressed(&"skill_1"):
		select_weapon_slot(1 - active_slot)


func weapon_name() -> String:
	return equipped_weapon.display_name if equipped_weapon != null else "Pickaxe"


func weapon_damage() -> float:
	return equipped_weapon.damage if equipped_weapon != null else attack_damage
func weapon_poise_damage() -> float:
	return equipped_weapon.poise_damage if equipped_weapon != null else attack_poise_damage
func weapon_move_control() -> float:
	return equipped_weapon.move_control if equipped_weapon != null else attack_move_control
func weapon_hitbox_offset() -> Vector2:
	return equipped_weapon.hitbox_offset if equipped_weapon != null else attack_hitbox_offset
func weapon_hitbox_size() -> Vector2:
	return equipped_weapon.hitbox_size if equipped_weapon != null else base_hitbox_size
func weapon_swing_colour() -> Color:
	return equipped_weapon.swing_colour if equipped_weapon != null else Color(0.85, 0.95, 1.0, 0.85)

func _w_startup() -> int:
	return equipped_weapon.startup_ms if equipped_weapon != null else attack_startup_ms
func _w_active() -> int:
	return equipped_weapon.active_ms if equipped_weapon != null else attack_active_ms
func _w_recovery() -> int:
	return equipped_weapon.recovery_ms if equipped_weapon != null else attack_recovery_ms
func _w_cancel() -> int:
	return equipped_weapon.cancel_start_ms if equipped_weapon != null else attack_cancel_start_ms


## Resize the physical hitbox and its swing arc to the equipped weapon, so a
## Spear really does reach further than a Dagger.
func _resize_attack_hitbox() -> void:
	var size: Vector2 = weapon_hitbox_size()
	var shape: RectangleShape2D = attack_hitbox.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape != null:
		shape.size = size
	var swing: ColorRect = attack_hitbox.visual as ColorRect
	if swing != null:
		swing.size = size
		swing.position = -size * 0.5
		swing.color = weapon_swing_colour()


func _upgrade_value(upgrade: UpgradeData) -> float:
	if upgrade == null:
		return 0.0
	return upgrade.value_at_level(GameState.upgrade_level(upgrade.id))


# --- Temporary buffs ---
# Buffs are timed power-ups that end with the run. Stored as id -> expiry tick,
# so they are deterministic (tick-counted) like everything else. The product of a
# named multiplier across all active buffs is what folds into the stats above.

var _buffs: Dictionary[StringName, BuffData] = {}
var _buff_expiry: Dictionary[StringName, int] = {}


func apply_buff(buff: BuffData) -> void:
	if buff == null:
		return
	_buffs[buff.id] = buff
	_buff_expiry[buff.id] = _tick + ms_to_ticks(buff.duration_ms)
	_juice.flash()
	Events.buff_gained.emit(buff)


## Called each physics tick to expire buffs. Returns nothing; the HUD reads state.
func _tick_buffs() -> void:
	for id: StringName in _buff_expiry.keys():
		if _tick >= _buff_expiry[id]:
			_buffs.erase(id)
			_buff_expiry.erase(id)
			Events.buff_expired.emit(id)


## Active buffs, for the HUD: {buff, fraction_remaining}.
func active_buffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in _buffs:
		var buff: BuffData = _buffs[id]
		var total: int = ms_to_ticks(buff.duration_ms)
		var left: int = maxi(0, _buff_expiry[id] - _tick)
		out.append({"buff": buff, "fraction": float(left) / maxf(1.0, float(total))})
	return out


func _buff_product(field: StringName) -> float:
	var product: float = 1.0
	for id: StringName in _buffs:
		product *= _buffs[id].get(field)
	return product


func is_dead() -> bool:
	return _dead


## The run ends. Death costs you every carried haul (GDD): the run coordinator
## handles that when it hears player_died. Here we just enter the death beat — a
## short, uncontrollable moment before the handoff, so a death lands rather than
## cutting instantly to a menu.
func _die() -> void:
	_dead = true
	invulnerable = true
	consume_riposte()
	_death_handoff_tick = _tick + ms_to_ticks(death_beat_ms)
	Sfx.play(Sfx.HURT, 0.7, 4.0)
	_juice.punch(Vector2(1.6, 0.4))
	Rumble.death()


## Full reset for a fresh run: health, riposte, death state. Called when a run
## starts, so replaying a seed compares like with like and a new delve after
## death starts you whole.
func reset_for_new_run() -> void:
	_dead = false
	_death_handoff_tick = 0
	health = effective_max_health()
	invulnerable = false
	velocity = Vector2.ZERO
	consume_riposte()
	# Buffs are per-run: a fresh run starts with none.
	_buffs.clear()
	_buff_expiry.clear()
	# Weapons are SESSION-scoped (GDD 2026-07-17): surviving a run banks the
	# loadout, dying cleared the stash before we got here. Either way, the stash
	# is the truth and we just re-arm whatever it says is ours.
	held_weapons = GameState.session_weapons.duplicate()
	active_slot = clampi(GameState.session_active_slot, 0, maxi(0, held_weapons.size() - 1))
	equipped_weapon = held_weapons[active_slot] if not held_weapons.is_empty() else null
	_resize_attack_hitbox()
	if _state_machine != null:
		_state_machine.transition_to(&"Idle")


## Drop the player somewhere with a clean slate. Used by the Delve when moving
## between rooms: carrying velocity or a half-finished roll across a transition
## would make you arrive already moving, which reads as losing control.
func teleport_to(destination: Vector2) -> void:
	global_position = destination
	_spawn_position = destination
	velocity = Vector2.ZERO
	consume_riposte()
	_was_on_floor = true
	_state_machine.transition_to(&"Idle")


## We landed a hit on something.
func _on_hit_landed(_damage: float, was_riposte: bool) -> void:
	Hitstop.request(hitstop_parry_frames if was_riposte else hitstop_hit_frames)
	_juice.punch(attack_punch)
	if was_riposte:
		Rumble.riposte()
	else:
		Rumble.hit()


func _on_parry_succeeded() -> void:
	Hitstop.request(hitstop_parry_frames)
	_juice.flash()
	Rumble.parry()


## Squash on touchdown, stretch on take-off. Requested from physics, animated in
## _process — the request is a fact, the animation is a visual.
func _update_landing_juice() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		_juice.punch(land_squash)
		_dust(10, 75.0)
		Events.player_landed.emit()
	elif not on_floor and _was_on_floor and velocity.y < 0.0:
		_juice.punch(jump_stretch)
	_was_on_floor = on_floor


## Visuals only, per the hard rule. Reads gameplay state, never writes it.
var _roll_fx_clock: float = 0.0

@onready var _sprite: AnimatedSprite2D = $VisualRoot/Sprite


func _process(delta: float) -> void:
	if _state_machine.get_current_name() == &"Roll":
		# A capsule that tumbles reads as a roll; one that slides reads as a
		# slide. This is the cheapest possible "it looks like a roll" in gray-box.
		_juice.hold_spin(roll_progress * TAU * float(facing))
		_juice.hold_scale(roll_squash)
		# The roll's identity pass: fading afterimages plus kicked-up dust.
		_roll_fx_clock += delta
		if _roll_fx_clock >= 0.045:
			_roll_fx_clock = 0.0
			_spawn_afterimage()
			_dust(3, 40.0)
	else:
		_roll_fx_clock = 0.0
		_juice.release_spin()
		_juice.release_scale()


## A ghost of the current sprite frame, frozen mid-tumble and fading fast.
func _spawn_afterimage() -> void:
	var host: Node = get_parent()
	if host == null or _sprite.sprite_frames == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	ghost.centered = false
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(0.7, 0.85, 1.0, 0.4)
	host.add_child(ghost)
	ghost.global_transform = _sprite.global_transform
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


## A one-shot puff of mine dust at the feet. Frees itself when spent.
func _dust(amount: int, spread: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.one_shot = true
	puff.emitting = true
	puff.amount = amount
	puff.lifetime = 0.45
	puff.direction = Vector2(0, -1)
	puff.spread = spread
	puff.initial_velocity_min = 25.0
	puff.initial_velocity_max = 85.0
	puff.gravity = Vector2(0, 220)
	puff.scale_amount_min = 1.5
	puff.scale_amount_max = 3.0
	puff.color = Color(0.66, 0.58, 0.46, 0.55)
	host.add_child(puff)
	puff.global_position = global_position
	puff.finished.connect(puff.queue_free)


## Godot's y axis points down: a negative velocity is upward, gravity is positive.
## Standard kinematics for "reach this height in this time": v = 2h/t, g = 2h/t².
func _recalculate_derived() -> void:
	_jump_velocity = -2.0 * jump_height / maxf(jump_time_to_peak, 0.001)
	_jump_gravity = 2.0 * jump_height / pow(maxf(jump_time_to_peak, 0.001), 2.0)
	_fall_gravity = 2.0 * jump_height / pow(maxf(jump_time_to_fall, 0.001), 2.0)


func ms_to_ticks(ms: int) -> int:
	return Ticks.from_ms(ms)


## Called on a successful parry. The payoff is a window, not an instant effect,
## so cashing it in is still a decision you can fumble.
func open_riposte() -> void:
	_riposte_until_tick = _tick + ms_to_ticks(riposte_window_ms)


func is_riposte_open() -> bool:
	return _tick <= _riposte_until_tick


func consume_riposte() -> void:
	_riposte_until_tick = -10000


func riposte_ticks_left() -> int:
	return maxi(0, _riposte_until_tick - _tick)


func get_input_direction() -> float:
	return Input.get_axis(&"move_left", &"move_right")


func update_facing(direction: float) -> void:
	if direction > 0.0:
		facing = 1
	elif direction < 0.0:
		facing = -1


## When you swing without holding a direction, face the nearest enemy instead of
## your last movement direction. This is the fix for "I clearly meant to hit that
## guy but swung the other way": holding a direction still overrides it, so you
## keep full control — it only helps when you gave no direction at all.
@export var aim_assist_range: float = 220.0
func aim_at_nearest_enemy() -> void:
	var best: Node2D = null
	var best_d: float = aim_assist_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d: float = absf(enemy.global_position.x - global_position.x)
		if d < best_d and absf(enemy.global_position.y - global_position.y) < 120.0:
			best_d = d
			best = enemy
	if best != null:
		facing = 1 if best.global_position.x > global_position.x else -1


## Rising uses jump_gravity, falling uses fall_gravity. The asymmetry is most of
## why a jump reads as snappy rather than floaty.
func apply_gravity(delta: float) -> void:
	var g: float = _jump_gravity if velocity.y < 0.0 else _fall_gravity
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func apply_horizontal(delta: float, direction: float) -> void:
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	var friction: float = ground_friction if is_on_floor() else air_friction
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		# Haste and Frenzy raise top speed through move_speed_multiplier.
		velocity.x = move_toward(velocity.x, direction * max_run_speed * move_speed_multiplier(), accel * delta)


## True while a jump is still legal after walking off a ledge.
func has_coyote() -> bool:
	return not is_on_floor() and _tick - _last_grounded_tick <= ms_to_ticks(coyote_ms)


## Fires a jump if one is buffered and legal, and reports whether it did.
func try_consume_jump() -> bool:
	if not _buffer.is_buffered(&"jump", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	if not is_on_floor() and not has_coyote():
		return false
	_buffer.consume(&"jump")
	# Spend the coyote window too, or it would fund a second jump mid-air.
	_last_grounded_tick = -10000
	velocity.y = _jump_velocity
	Events.player_jumped.emit()
	return true


func try_jump_cut() -> void:
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


## Roll is a pillar: safe, never punished, no stamina, no cooldown. If it is
## legal at all it is legal now. The only gate is the air-roll design question.
func try_consume_roll() -> bool:
	if not _buffer.is_buffered(&"roll", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	if not is_on_floor() and not allow_air_roll:
		return false
	_buffer.consume(&"roll")
	return true


func try_consume_attack() -> bool:
	if not _buffer.is_buffered(&"attack", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	_buffer.consume(&"attack")
	return true


func try_consume_parry() -> bool:
	if not _buffer.is_buffered(&"parry", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	_buffer.consume(&"parry")
	return true


## Read-only accessors for the debug overlay.
func get_tick() -> int:
	return _tick


func get_state_name() -> StringName:
	return _state_machine.get_current_name()


func get_buffer() -> InputBuffer:
	return _buffer
