extends Node2D

@export var speed: float = 500.0
@export var damage: int = 1
@export var lifetime: float = 3.0  # Bullet will disappear after 3 seconds

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $RifleP  # Ensure this node exists in the scene

var time_alive: float = 0.0

func _ready() -> void:
	# Add to enemy bullets group
	add_to_group("enemy_bullets")
	area.collision_layer = 4  
	area.collision_mask = (1 << 0) | (1 << 2) | (1 << 4)  # Layers 1, 3, and 5 => 1 | 4 | 16 = 21
	
	# Connect collision signal using Callable syntax for Area2D
	if not area.is_connected("area_entered", Callable(self, "_on_area_entered")):
		area.connect("area_entered", Callable(self, "_on_area_entered"))

func _process(delta: float) -> void:
	# Move the bullet forward manually
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

	# Handle lifetime expiration
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

func _on_area_entered(area_other: Area2D) -> void:
	if area_other.is_in_group("controlled_bullets") or area_other.is_in_group("bullet"):
		queue_free()  # Destroy enemy bullet
	elif area_other.has_method("take_damage"):
		area_other.take_damage(damage)
		queue_free()  # Destroy enemy bullet


func _on_area_2d_body_entered(body: Node2D) -> void:
		if body.is_in_group("wielder"):
			if body.has_method("take_damage"):
				body.take_damage(damage)  # Apply damage to the enemy
			queue_free()  # Destroy th
