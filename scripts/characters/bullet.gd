extends Node2D

@export var speed: float = 500.0  # Bullet speed
@export var lifetime: float = 5.0  # Bullet lifetime in seconds

var time_alive: float = 0.0

func _process(delta: float) -> void:
	# Increment the time the bullet has been alive
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()  # Destroy the bullet after its lifetime
		return

	# Steering logic (rotate bullet with input)
	if Input.is_action_pressed("rotate_left"):
		rotation -= deg_to_rad(120 * delta)  # Turn left
	if Input.is_action_pressed("rotate_right"):
		rotation += deg_to_rad(120 * delta)  # Turn right

	# Move bullet forward based on its rotation
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
