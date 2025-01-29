extends Parallax2D

@export var parallax_strength: float = 0.05  # Adjust to control movement speed

func _process(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Normalize mouse position (-1 to 1) relative to center screen
	var normalized_mouse_pos = (mouse_pos - viewport_size / 2) / viewport_size

	# Apply to `scroll_offset` for parallax effect
	scroll_offset = normalized_mouse_pos * parallax_strength * viewport_size
