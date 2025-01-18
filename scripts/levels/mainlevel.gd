extends Node2D

@onready var wielder: CharacterBody2D = $Wielder  # Reference the wielder

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var target_position = event.position
		if wielder:
			wielder.set_target(target_position)  # Set target position on click
