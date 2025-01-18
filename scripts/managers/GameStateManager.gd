extends Node

signal game_loaded
signal game_saved

# Allows wielder to be assigned to this variable for ease of identifying player
var wielder

# Will be able to set whichever level to the current by accessing through here 
# in whichever level nodes _ready function
var current_level: int = 1

var current_scene: Node

var current_save: Dictionary = {
	"current_scene_path": "",
	"sanity": 1,
	"morality": 1,
	"health": 1
}

func set_sanity(sanity_amount: int, operation) -> void:
	current_save = _update_dict_int_value("sanity", sanity_amount, operation)
	print(JSON.stringify(current_save))

func set_morality(morality_amount: int, operation) -> void:
	current_save = _update_dict_int_value("morality", morality_amount, operation)
	print(JSON.stringify(current_save))

func _update_dict_int_value(key: String, value, operation) -> Dictionary:
	var new_save = current_save.duplicate()
	if operation == "add":
		new_save[key] = new_save[key] + value
	elif operation == "subtract":
		new_save[key] = new_save[key] - value
	else:
		assert(operation not in ["add", "subtract"], "Not an implemented method")
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

# Gonna comment this out because i'm not certain we'll be able to use this
# for the web exported version
#func save_game() -> void:
#	var file := FileAccess.open("user://save.sav", FileAccess.WRITE)
#	var save_json = JSON.stringify(current_save)
#	file.store_line(save_json)
#	game_saved.emit()


#func get_save_file() -> FileAccess:
#	return FileAccess.open("user://save.sav", FileAccess.READ)
