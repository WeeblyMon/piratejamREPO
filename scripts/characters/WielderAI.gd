extends Node2D

@export var speed: float = 150.0  # Movement speed
@export var fire_rate: float = 1.0  # Time between shots
@export var gun: Node2D  # Reference to the gun node

var direction: Vector2 = Vector2.ZERO  # Current movement direction
var time_since_last_shot: float = 0.0  # Timer for shooting
var is_paused: bool = false  # Flag to pause shooting

func _ready() -> void:
	# Set an initial random direction
	direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

func _process(delta: float) -> void:
	if is_paused:
		return
	position += direction * speed * delta

	if randi() % 100 == 0:
		direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func shoot() -> void:
	if gun and gun.has_method("fire_bullet"):
		gun.fire_bullet()

func pause_shooting() -> void:
	is_paused = true

func resume_shooting() -> void:
	is_paused = false
