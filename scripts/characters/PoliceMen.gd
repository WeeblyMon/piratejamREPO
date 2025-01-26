extends CharacterBody2D

@export var health: int = 10 
@export var detection_radius: float = 300.0  
@onready var sprite: Sprite2D = $PoliceEnemy
@onready var ray_cast = $RayCast2D
@onready var timer: Timer = $Timer
@export var eBullet : PackedScene
var Wielder

func _ready():
	Wielder = get_parent().find_child("Wielder")

func _physics_process(_delta):
	_aim()
	_check_player_collision()

func _aim():
	ray_cast.target_position = to_local(Wielder.position)

func _check_player_collision():
	pass



func take_damage(damage: int) -> void:
	health -= damage
	sprite.modulate = Color(1, 0, 0)  
	flash_color()
	if health <= 0:
		die()

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
	GameStateManager.add_notoriety(1)
	AudioManager.play_sfx("enemy_hit_and_blood_1", +10.0)
	queue_free()  
