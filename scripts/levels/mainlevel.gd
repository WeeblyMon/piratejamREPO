extends Node2D

@export var wielder: CharacterBody2D

func _input(event: InputEvent) -> void:
	# Check for addSanity input
	if event.is_action_pressed("addSanity"):
		GameStateManager.set_sanity(10, "add")  # Adjust the value (e.g., 10) as needed

	# Check for removeSanity input
	if event.is_action_pressed("removeSanity"):
		GameStateManager.set_sanity(10, "sub")  # Adjust the value (e.g., 10) as needed
