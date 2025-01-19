extends Node

signal game_loaded
signal game_saved

var wielder  
var current_level: int = 1
var current_scene: Node

var current_weapon: String = "shotgun"  

var current_save: Dictionary = {
	"current_scene_path": "",
	"sanity": 1,
	"morality": 1,
	"health": 1
}

@onready var sanity_bar
@onready var health_bar

func set_weapon(weapon_name: String) -> void:
	current_weapon = weapon_name
	print("Weapon switched to:", current_weapon)

func get_weapon() -> String:
	return current_weapon

func set_sanity(sanity_amount: int, operation) -> void:
	current_save = _update_dict_int_value(Constants.SANITY, sanity_amount, operation)
	sanity_bar.update_bar(operation, sanity_amount)
	print(JSON.stringify(current_save))


func set_health(health_amount: int, operation) -> void:
	current_save = _update_dict_int_value(Constants.HEALTH, health_amount, operation)
	health_bar.update_bar(operation, health_amount)
	print(JSON.stringify(current_save))


func _update_dict_int_value(key: String, value, operation) -> Dictionary:
	var new_save = current_save.duplicate()
	if operation == Constants.OPERATIONS.ADD:
		new_save[key] = new_save[key] + value
	elif operation == Constants.OPERATIONS.SUB:
		new_save[key] = new_save[key] - value
	else:
		assert(operation in Constants.OPERATIONS, "Not an implemented method")
	return new_save


func switch_scene(new_scene_path: String) -> void:
	assert(new_scene_path != "", "Scene path cannot be empty.")

	var new_scene: PackedScene = load(new_scene_path)
	assert(new_scene, "Failed to load scene: %s".format(new_scene_path))

	var new_scene_instance: Node = new_scene.instantiate()

	get_tree().root.add_child(new_scene_instance)

	if current_scene != null:
		current_scene.queue_free()

	current_scene = new_scene_instance
	print("Switched to new scene: %s".format(new_scene_path))
