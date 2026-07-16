class_name HitSpark
extends CPUParticles2D
## A one-shot burst on impact. Theme-neutral on purpose: sparks and dust read as
## "something connected" whether this turns out to be a mine, a ship or a crypt.
## Whatever the M9 art pass decides, this does not have to be thrown away.
##
## Frees itself once the burst is done.


static func burst(parent: Node, at: Vector2, direction: int, is_riposte: bool) -> void:
	var scene: PackedScene = load("res://src/systems/hit_spark.tscn") as PackedScene
	var spark: HitSpark = scene.instantiate() as HitSpark
	parent.add_child(spark)
	spark.global_position = at
	spark.fire(direction, is_riposte)


func fire(direction: int, is_riposte: bool) -> void:
	# Spray back the way the hit came from — the direction is what sells it as an
	# impact rather than a puff.
	self.direction = Vector2(float(direction), -0.35)
	amount = 18 if is_riposte else 9
	initial_velocity_min = 130.0 if is_riposte else 80.0
	initial_velocity_max = 340.0 if is_riposte else 200.0
	scale_amount_max = 3.5 if is_riposte else 2.2
	color = Color(1.0, 0.85, 0.35) if is_riposte else Color(0.95, 0.95, 1.0)
	emitting = true


func _ready() -> void:
	# Free on the engine's own "the burst is done" signal rather than an awaited
	# timer. An await parks a reference to this node inside the timer, which the
	# engine then reports as a leaked resource if the game quits mid-burst.
	finished.connect(queue_free)
