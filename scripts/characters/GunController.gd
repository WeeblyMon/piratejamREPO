extends Node2D

@export var bullet_scene: PackedScene 
@export var fire_rate: float = 0.5  

@onready var raycast: RayCast2D = $RayCast2D  

var weapon_raycast_positions = {
	"handgun": {"position": Vector2(163, 44), "direction": Vector2(1, 0)},
	"rifle": {"position": Vector2(181, 36), "direction": Vector2(1, 0)},
	"shotgun": {"position": Vector2(186, 37), "direction": Vector2(1, 0)}
}

var time_since_last_shot: float = 0.0

func _ready() -> void:

	var current_weapon = GameStateManager.get_weapon()
	update_raycast(current_weapon)

func _process(delta: float) -> void:
	time_since_last_shot += delta

func fire_bullet():
	if bullet_scene and time_since_last_shot >= fire_rate:
		# Instantiate the bullet
		var bullet = bullet_scene.instantiate()
		bullet.global_position = raycast.global_position  # Bullet spawns at the raycast position
		bullet.rotation = raycast.global_rotation         # Bullet uses the raycast's rotation

		# Add the bullet to the current scene
		get_tree().current_scene.add_child(bullet)

		# Reset the timer
		time_since_last_shot = 0.0
		print("Bullet fired from", GameStateManager.get_weapon())
		
		return bullet
			# If we couldn't fire (cooldown not done, etc.), return null
	return null

func switch_weapon(new_weapon: String) -> void:
	# Update the weapon in the GameStateManager
	GameStateManager.set_weapon(new_weapon)

	# Update the RayCast2D for the new weapon
	update_raycast(new_weapon)

func update_raycast(current_weapon: String) -> void:
	# Dynamically adjust the RayCast2D position and direction for the current weapon
	if weapon_raycast_positions.has(current_weapon):
		var weapon_data = weapon_raycast_positions[current_weapon]
		raycast.position = weapon_data["position"]
		raycast.target_position = weapon_data["direction"] * 100  # Adjust the length of the ray
		raycast.enabled = true
		print("RayCast2D updated for weapon:", current_weapon)
	else:
		print("No raycast data found for weapon:", current_weapon)
