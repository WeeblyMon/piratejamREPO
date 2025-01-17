extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5  # Time between shots in seconds

var time_since_last_shot = 0.0

func _process(delta):
	time_since_last_shot += delta

	# Check for firing input
	if Input.is_action_just_pressed("fire") and time_since_last_shot >= fire_rate:
		fire_bullet()
		time_since_last_shot = 0.0

func fire_bullet():
	if bullet_scene:
		# Spawn and fire a bullet from the gun's position
		var bullet = bullet_scene.instantiate()
		bullet.position = global_position
		bullet.rotation = global_rotation
		get_parent().add_child(bullet)
