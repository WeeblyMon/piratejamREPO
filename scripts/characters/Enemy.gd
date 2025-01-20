extends Node2D

@export var health: int = 10  # Enemy's starting health
@export var detection_radius: float = 300.0  # Radius for the AI to detect this enemy

func _ready() -> void:
	add_to_group("enemies")  # Add to the "enemies" group so the AI can detect it

func take_damage(damage: int) -> void:
	health -= damage
	if health <= 0:
		die()

func die() -> void:
	queue_free()  # Remove the enemy from the scene
	print("Enemy defeated!")
