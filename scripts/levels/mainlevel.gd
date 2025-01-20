extends Node2D

@export var wielder: CharacterBody2D

#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#var target_position = get_global_mouse_position()
		#if wielder:
			#wielder.set_target(target_position)
