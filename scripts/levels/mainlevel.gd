extends Node2D

@export var wielder: CharacterBody2D

func _ready() -> void:
	AudioManager.play_music("level_music")
	AudioManager.play_sfx("crowd_chatter_1")

func _input(event: InputEvent) -> void:
	# Check for addSanity input
	if event.is_action_pressed("addSanity"):
		GameStateManager.set_sanity(10, "add")  # Adjust the value (e.g., 10) as needed

	# Check for removeSanity input
	if event.is_action_pressed("removeSanity"):
		GameStateManager.set_sanity(10, "sub")  # Adjust the value (e.g., 10) as needed
		
	if event.is_action_pressed("jam_ability"):
		if wielder and wielder.has_method("trigger_jam"):
			wielder.trigger_jam()
