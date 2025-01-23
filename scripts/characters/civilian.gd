extends Node2D

@export var health: int = 10 
@export var detection_radius: float = 300.0  
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("civilian")  

func take_damage(damage: int) -> void:
	health -= damage
	sprite.modulate = Color(1, 0, 0)  
	flash_color()
	if health <= 0:
		die()
		GameStateManager.set_sanity(1, "sub")

func flash_color() -> void:
	var flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1
	add_child(flash_timer)
	flash_timer.start()
	AudioManager.play_sfx_varied("grunt_2", -0.5, false, 0.9, 1.1)
	await flash_timer.timeout
	sprite.modulate = Color(1, 1, 1)  
	flash_timer.queue_free()  

func die() -> void:
	GameStateManager.set_sanity(14, "sub")
	queue_free()  
