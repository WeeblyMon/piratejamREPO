extends Node2D

@export var speed: float = 150.0  # Movement speed
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set an initial random direction
	direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

func _process(delta: float) -> void:
	# Move in the current direction
	position += direction * speed * delta

	# Change direction occasionally
	if randi() % 100 == 0:  # Random chance to change direction
		direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
