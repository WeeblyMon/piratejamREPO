extends Node2D

@export var speed: float = 500.0
@export var damage: int = 1
@export var lifetime: float = 3.0  # Bullet will disappear after 3 seconds

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $RifleP

var time_alive: float = 0.0

func _ready() -> void:
	# Connect collision signal
	area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Move the bullet forward
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

	# Handle lifetime expiration
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Check if the body has a take_damage method
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Destroy the bullet upon collision
	queue_free()
