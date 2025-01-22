# SanityEffects.gd

extends Node2D

@onready var lines: AnimatedSprite2D = $Lines
@onready var noise: AnimatedSprite2D = $Noise

func _ready() -> void:
	# Use Callable to connect the signal
	GameStateManager.connect("sanity_changed", Callable(self, "_on_sanity_changed"))
	_on_sanity_changed(GameStateManager.current_sanity)  # Initialize the effect based on current sanity

# Adjust alpha based on sanity level
func _on_sanity_changed(sanity: int) -> void:
	var alpha = 1.0 - float(sanity) / GameStateManager.max_sanity
	alpha = clamp(alpha, 0.0, 1.0)  # Ensure alpha is between 0 and 1

	# Apply alpha to lines and noise
	lines.modulate = Color(lines.modulate.r, lines.modulate.g, lines.modulate.b, alpha)
	noise.modulate = Color(noise.modulate.r, noise.modulate.g, noise.modulate.b, alpha)
