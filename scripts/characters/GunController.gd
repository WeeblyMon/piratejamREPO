extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5  # Time between shots in seconds

var time_since_last_shot: float = 0.0

# Reference to the RayCast2D node
@onready var barrel: RayCast2D = $RayCast2D

func _process(delta: float) -> void:
	time_since_last_shot += delta
	if Input.is_action_just_pressed("fire") and time_since_last_shot >= fire_rate:
		fire_bullet()
		time_since_last_shot = 0.0

func fire_bullet() -> void:
	if bullet_scene:
		var bullet: Node2D = bullet_scene.instantiate() as Node2D
		bullet.position = to_global(barrel.position)
		bullet.rotation = barrel.global_rotation 
		get_tree().root.add_child(bullet)
		print("Bullet fired at:", bullet.position)
