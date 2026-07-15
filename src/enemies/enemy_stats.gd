class_name EnemyStats
extends Resource
## Everything that makes one enemy differ from another by numbers rather than by
## code. Per the hard rule: adding content means adding a `.tres`, not editing a
## system. A new melee variant should never require touching a script.
##
## Behaviour that genuinely cannot be a number — a stationary swing versus a dash
## across the room — lives in an Enemy subclass instead. The dividing line is:
## if it is a value, it belongs here; if it is a verb, it belongs in a subclass.

@export var display_name: String = "Enemy"

@export_group("Health")
@export var max_health: float = 60.0
## How long the hurt reaction locks the enemy up. Long enough to read, short
## enough that it is not a free stunlock.
@export var hurt_ms: int = 160
@export var knockback: float = 170.0

@export_group("Movement")
@export var move_speed: float = 95.0
@export var acceleration: float = 700.0
## Stop approaching once this close. Roughly where the attack lands.
@export var attack_range: float = 62.0
## Notice the player at this distance.
@export var aggro_range: float = 620.0

@export_group("Attack")
@export var damage: float = 10.0
## THE parry knob. Long = generous and readable, the parry teacher. Short = you
## must already know the tell. GDD: telegraph everything, readability over surprise.
@export var telegraph_ms: int = 450
@export var swing_active_ms: int = 90
## The punish window after a swing. Long recovery = safe to greed a hit in.
@export var recover_ms: int = 420
## Beat between attacks once in range.
@export var idle_ms: int = 420
## How long a parry staggers it. This is the riposte window in practice, so it
## must comfortably exceed the player's riposte_window_ms or the reward is a lie.
@export var stagger_ms: int = 850

@export_group("Dash", "dash_")
## Used only by DartEnemy; ignored by melee types. The lunge travels
## dash_speed x swing_active_ms, so those two together set the overshoot. It must
## carry PAST the player: landing behind you is what makes the dash rollable
## rather than a wall you eat.
@export var dash_speed: float = 0.0

@export_group("Readability")
## In gray-box a colour IS the telegraph, so these are not decoration.
@export var colour_idle: Color = Color(0.75, 0.4, 0.4)
@export var colour_telegraph: Color = Color(0.95, 0.78, 0.25)
@export var colour_attack: Color = Color(0.95, 0.2, 0.2)
@export var colour_recover: Color = Color(0.5, 0.35, 0.35)
@export var colour_stagger: Color = Color(0.35, 0.65, 1.0)

@export_group("Death")
## How long the corpse lingers before fading out and freeing itself. Long enough
## that the kill registers, short enough that the room does not fill with debris.
@export var corpse_linger_ms: int = 260
@export var corpse_fade_ms: int = 420

@export_group("Body")
@export var body_size: Vector2 = Vector2(32, 64)
@export var hitbox_size: Vector2 = Vector2(70, 56)
@export var hitbox_offset: Vector2 = Vector2(46, -32)
