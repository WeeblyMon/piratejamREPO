extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5

@onready var raycast: RayCast2D = $RayCast2D

# Updated to include fire rate along with position and direction
var weapon_data = {
	"handgun": {"position": Vector2(163, 44), "direction": Vector2(1, 0), "fire_rate": 0.5},
	"rifle": {"position": Vector2(181, 36), "direction": Vector2(1, 0), "fire_rate": 0.2},
	"shotgun": {"position": Vector2(186, 37), "direction": Vector2(1, 0), "fire_rate": 1.0}
}

var current_fire_rate: float = 0.5
var time_since_last_shot: float = 0.0

func _ready() -> void:
	# Set the initial weapon raycast position and direction
	var current_weapon = GameStateManager.get_weapon()
	update_raycast(current_weapon)
	update_weapon(current_weapon)

func _process(delta: float) -> void:
	# Increment the cooldown timer every frame
	time_since_last_shot += delta

func fire_bullet() -> Node:
	# Check if we can fire based on the cooldown
	if bullet_scene and time_since_last_shot >= current_fire_rate:
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
	else:
		# Debug output for cooldown
		if time_since_last_shot < current_fire_rate:
			print("Cannot fire: cooldown active (remaining:", current_fire_rate - time_since_last_shot, "s)")
		return null

func switch_weapon(new_weapon: String) -> void:
	# Update the weapon in the GameStateManager
	GameStateManager.set_weapon(new_weapon)

	# Update the RayCast2D for the new weapon
	update_raycast(new_weapon)
	update_weapon(new_weapon)

func update_raycast(current_weapon: String) -> void:
	# Dynamically adjust the RayCast2D position and direction for the current weapon
	if weapon_data.has(current_weapon):
		var weapon = weapon_data[current_weapon]
		raycast.position = weapon["position"]
		raycast.target_position = weapon["direction"] * 100  # Adjust the length of the ray
		raycast.enabled = true
		print("RayCast2D updated for weapon:", current_weapon)
	else:
		print("No raycast data found for weapon:", current_weapon)

func update_weapon(weapon_name: String) -> void:
	# Update fire rate based on weapon data
	if weapon_data.has(weapon_name):
		current_fire_rate = weapon_data[weapon_name]["fire_rate"]
		print("Updated weapon:", weapon_name, "Fire rate:", current_fire_rate)
	else:
		print("No weapon data found for:", weapon_name)
