extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5  

var time_since_last_shot: float = 0.0
var last_bullet: Node2D = null

@onready var barrel: RayCast2D = $RayCast2D

func _process(delta: float) -> void:
	time_since_last_shot += delta
	if Input.is_action_just_pressed("fire") and time_since_last_shot >= fire_rate:
		fire_bullet()
		time_since_last_shot = 0.0

func fire_bullet() -> void:
	if bullet_scene:
		var bullet: Node2D = bullet_scene.instantiate()

		var global_transform: Transform2D = barrel.get_global_transform()
		bullet.global_position = global_transform.origin 
		bullet.rotation = global_transform.get_rotation() 

		get_tree().current_scene.add_child(bullet)  
		last_bullet = bullet

		print("Bullet spawned at:", bullet.global_position)


func control_last_bullet() -> void:
	if last_bullet and last_bullet.has_method("set"):
		last_bullet.is_controlled = true
		print("Player now controls the last bullet!")

func _input(event: InputEvent) -> void:
	var wielder = get_parent() as Node2D  
	if event.is_action_pressed("control_bullet"):
		control_last_bullet()
		if wielder.has_method("pause_shooting"):
			wielder.pause_shooting()
	elif event.is_action_released("control_bullet"):
		if wielder.has_method("resume_shooting"):
			wielder.resume_shooting()
