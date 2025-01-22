extends Node2D

@export var health: int = 10  # Enemy's starting health
@export var detection_radius: float = 300.0  # Radius for the AI to detect this enemy
@onready var sprite: Sprite2D = $PoliceEnemy

func _ready() -> void:
	add_to_group("enemies")  # Add to the "enemies" group so the AI can detect it

func take_damage(damage: int) -> void:
	health -= damage
	sprite.modulate = Color(1, 0, 0)  # Change to red
	flash_color()
	if health <= 0:
		die()

func flash_color() -> void:
	var flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1
	add_child(flash_timer)
	flash_timer.start()
	await flash_timer.timeout
	sprite.modulate = Color(1, 1, 1)  
	flash_timer.queue_free()  

func die() -> void:
	queue_free()  
