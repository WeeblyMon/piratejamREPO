extends Node2D

@export var speed: float = 150.0  # Movement speed
var direction = Vector2.ZERO

func _ready():
	# Set an initial random direction
	direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

func _process(delta):
	# Move in the current direction
	position += direction * speed * delta

	# Change direction occasionally (to prevent vibration)
	if randi() % 100 == 0:  # Random chance to change direction
		direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
