extends Node

signal game_loaded
signal game_saved

# Allows wielder to be assigned to this variable for ease of identifying player
var wielder

# Will be able to set whichever level to the current by accessing through here 
# in whichever level nodes _ready function
var current_level: int = 1

var current_save: Dictionary = {
	current_scene_path = "",
	sanity = "",
	morality = ""
}


func save_game() -> void:
	var file := FileAccess.open("user://save.sav", FileAccess.WRITE)
	var save_json = JSON.stringify(current_save)
	file.store_line(save_json)
	game_saved.emit()


func get_save_file() -> FileAccess:
	return FileAccess.open("user://save.sav", FileAccess.READ)
