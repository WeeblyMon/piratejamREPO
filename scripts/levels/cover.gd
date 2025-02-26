extends Node2D

@export var max_health: int = 100  # Max health of the cover
@export var sprite_frames: Array[Texture2D] = []  # Different cover sprites
@export var explosion_scene: PackedScene  # Explosion effect to spawn on destruction
@export var sprite_index: int = 0  # Index for the current sprite
@export var radius: float = 50.0  # Default radius for safe positioning
@onready var sprite: Sprite2D = $Sprite2D
@export var health_bar: ProgressBar

var current_health: int


signal cover_destroyed

func _ready() -> void:
	current_health = max_health
	health_bar.visible = false
	health_bar.value = current_health
	health_bar.max_value = max_health
	update_sprite()
	
func get_radius() -> float:
	return radius

func take_damage(amount: int) -> void:
	health_bar.visible = true
	current_health -= amount
	current_health = max(0, current_health)  
	health_bar.value = current_health

	if current_health <= 0:
		destroy_cover()
	else:
		print("Cover health:", current_health)

func destroy_cover() -> void:
	emit_signal("cover_destroyed")

	if sprite_index == 1:
		AudioManager.play_sfx("wood_break_1")
	else:
		AudioManager.play_sfx("explosion_2")

	spawn_explosion()
	queue_free()

func spawn_explosion() -> void:
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		get_tree().current_scene.add_child(explosion)

# Dynamically switch cover sprite
func update_sprite() -> void:
	if sprite_index >= 0 and sprite_index < sprite_frames.size():
		sprite.texture = sprite_frames[sprite_index]
	else:
		push_warning("Invalid sprite index: %d".format(sprite_index))
