extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5  # Time between shots in seconds

var time_since_last_shot = 0.0

# Reference to the RayCast2D node
@onready var barrel = $RayCast2D

func _process(delta):
	time_since_last_shot += delta

	# Fire bullets when the "fire" input is pressed
	if Input.is_action_just_pressed("fire") and time_since_last_shot >= fire_rate:
		fire_bullet()
		time_since_last_shot = 0.0

func fire_bullet():
	if bullet_scene:
		var bullet = bullet_scene.instantiate()

		# Convert the barrel's local position to the global position
		bullet.position = to_global(barrel.position)
		bullet.rotation = barrel.global_rotation  # Use global rotation

		get_tree().root.add_child(bullet)  # Ensure the bullet is added globally to the scene tree
		print("Bullet fired at:", bullet.position)
