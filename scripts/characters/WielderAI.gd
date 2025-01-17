extends Node2D

@export var speed: float = 150.0  # Movement speed
var direction = Vector2.ZERO

func _process(delta):
	# Example: Simple random movement logic
	direction = (Vector2(randf() - 0.5, randf() - 0.5)).normalized()
	position += direction * speed * delta
