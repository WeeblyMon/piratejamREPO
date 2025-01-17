extends Node2D

@export var speed: float = 500.0  
@export var lifetime: float = 2.0  

var time_alive = 0.0

func _process(delta):
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return

	# Steering logic
	if Input.is_action_pressed("rotate_left"):
		rotation -= deg_to_rad(120 * delta)
	if Input.is_action_pressed("rotate_right"):
		rotation += deg_to_rad(120 * delta)

	# Move bullet forward
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
