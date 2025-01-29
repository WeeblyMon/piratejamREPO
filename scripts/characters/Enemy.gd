extends Node2D

@export var health: int = 10
@export var detection_radius: float = 300.0
@export var fire_rate: float = 1.0  # Seconds per shot
@export var bullet_scene: PackedScene  # Assign your bullet scene here
@export var shoot_on_sight: bool = true  # NEW: Toggle to determine if police AI shoots first

@onready var sprite: Sprite2D = $PoliceEnemy
@onready var detection_area: Area2D = Area2D.new()

var target: Node = null
var fire_timer: Timer = null
var is_retaliating: bool = false  # NEW: Track whether AI is in retaliation mode

func _ready() -> void:
	add_to_group("enemy")  # Add to the enemy group
	_create_detection_area()  # Set up the detection radius
	_setup_fire_timer()

# ---------------------------------------------
# HEALTH AND DAMAGE MANAGEMENT
# ---------------------------------------------

func take_damage(damage: int) -> void:
	"""Handles damage taken by the police AI."""
	health -= damage
	sprite.modulate = Color(1, 0, 0)  # Flash red when damaged
	flash_color()

	if health <= 0:
		die()
	else:
		# NEW: If shot, enter retaliation mode and start firing back
		if not is_retaliating:
			is_retaliating = true
			print("🚨 Police AI is now retaliating!")
			fire_timer.start()  # Start shooting only when hit

func flash_color() -> void:
	var flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1
	add_child(flash_timer)
	flash_timer.start()
	AudioManager.play_sfx_varied("grunt_2", -0.5, false, 0.9, 1.1)
	await flash_timer.timeout
	sprite.modulate = Color(1, 1, 1)  # Restore normal color
	flash_timer.queue_free()

func die() -> void:
	"""Handles enemy death."""
	GameStateManager.add_notoriety(40)
	AudioManager.play_sfx("enemy_hit_and_blood_1", +10.0)
	remove_from_group("enemy")  # Remove from group upon death
	queue_free()

func is_dead() -> bool:
	return health <= 0

# ---------------------------------------------
# DETECTION AND SHOOTING LOGIC
# ---------------------------------------------

func _create_detection_area() -> void:
	"""Sets up an area for detecting the Wielder AI."""
	detection_area.name = "DetectionArea"

	# Add a collision shape for detection
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	collision_shape.shape.radius = detection_radius
	detection_area.add_child(collision_shape)

	# Add signals for detecting targets
	detection_area.monitoring = true
	detection_area.connect("body_entered", Callable(self, "_on_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_body_exited"))

	add_child(detection_area)

func _setup_fire_timer() -> void:
	"""Prepares the shooting timer."""
	fire_timer = Timer.new()
	fire_timer.one_shot = false
	fire_timer.wait_time = fire_rate
	fire_timer.connect("timeout", Callable(self, "_fire_bullet"))
	add_child(fire_timer)

func _on_body_entered(body: Node) -> void:
	"""Handles AI detecting an enemy (Wielder AI)."""
	if body.is_in_group("wielder"):
		target = body

		if shoot_on_sight:
			print("🔫 Police AI is shooting immediately!")
			fire_timer.start()
		else:
			print("👀 Police AI is watching but won't shoot unless attacked!")

func _on_body_exited(body: Node) -> void:
	"""Stops shooting when the target leaves detection range."""
	if body == target:
		target = null
		fire_timer.stop()
		is_retaliating = false  # Reset retaliation mode when losing sight

func _fire_bullet() -> void:
	"""Fires a bullet at the Wielder AI if conditions are met."""
	if not target or is_dead():
		return

	# NEW: Only fire if:
	# - `shoot_on_sight = true`, OR
	# - `is_retaliating = true` (i.e., police was shot first)
	if not shoot_on_sight and not is_retaliating:
		return

	# Turn to face the target
	look_at(target.global_position)

	# Instantiate and fire a bullet at the target
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.rotation = (target.global_position - global_position).angle()

	# Exclude police bullets from hitting other police
	if bullet.has_method("set_owner_group"):
		bullet.set_owner_group("enemy")  # Ensure bullets don't hurt friendly units

	get_tree().current_scene.add_child(bullet)

	# Play shooting sound effect
	AudioManager.play_sfx("gunshot_1")
