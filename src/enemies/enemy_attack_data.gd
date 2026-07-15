class_name EnemyAttackData
extends Resource
## One attack an enemy can perform. Enemies pick between these by range.
##
## This exists because every enemy had exactly one swing on a loop, which read as
## a metronome rather than a fight. Attacks being data means variety is a resource
## file, and it also folded the Dart's lunge back into the base enemy — a dash is
## `dash_speed` during the active window, not a different kind of creature.

@export var display_name: String = "swing"

@export_group("Selection")
## Chosen when the player is within this band, in px. Overlapping bands are fine
## — the enemy picks randomly among everything that fits, which is where the
## unpredictability comes from. Order matters only for ties.
@export var min_range: float = 0.0
@export var max_range: float = 70.0
## Relative likelihood among the attacks that fit the current range.
@export var weight: float = 1.0

@export_group("Timing")
## THE parry knob for this attack. Long = generous and readable.
@export var telegraph_ms: int = 450
@export var active_ms: int = 90
## The punish window afterwards. Longer recovery = safer to greed a hit in.
@export var recover_ms: int = 420

@export_group("Effect")
@export var damage: float = 10.0
## Lunge speed during the active window. 0 is a stationary swing. Direction locks
## when the attack starts, so a dash always commits to a readable line.
@export var dash_speed: float = 0.0

@export_group("Poise")
## Damage this attack can absorb before the enemy is knocked off balance.
##
## Poise applies ONLY from the start of the telegraph to the end of the active
## window — outside that the enemy flinches freely, which is what keeps combat at
## the Dead Cells pace rather than Dark Souls weight (see the GDD decision log).
##
## Set it against the player's hit: ~12 normal, ~36 on a riposte. A value of 12
## means a single poke interrupts. 80 means you will not poke through it at all
## and must parry or roll — which is the entire point of the heavy enemies.
@export var poise: float = 30.0

@export_group("Readability")
## In gray-box a colour IS the telegraph, so a distinct colour per attack is how
## the player learns to tell them apart before they land.
@export var colour_telegraph: Color = Color(0.95, 0.78, 0.25)
@export var colour_attack: Color = Color(0.95, 0.2, 0.2)

@export_group("Hitbox")
@export var hitbox_size: Vector2 = Vector2(70, 56)
@export var hitbox_offset: Vector2 = Vector2(46, -32)
