extends Control

@onready var lines: AnimatedSprite2D = $Lines
@onready var noise: AnimatedSprite2D = $Noise

func _ready() -> void:
	GameStateManager.connect("sanity_changed", Callable(self, "_on_sanity_changed"))
	_on_sanity_changed(GameStateManager.current_sanity)  

func _on_sanity_changed(sanity: int) -> void:
	var alpha = 1.0 - float(sanity) / GameStateManager.max_sanity
	alpha = clamp(alpha, 0.0, 1.0)

	lines.modulate = Color(lines.modulate.r, lines.modulate.g, lines.modulate.b, alpha)
	noise.modulate = Color(noise.modulate.r, noise.modulate.g, noise.modulate.b, alpha)

	if alpha > 0.0:  
		if not lines.is_playing():
			lines.play("lines")
		if not noise.is_playing():
			noise.play("noise")
	else:  
		lines.stop()
		noise.stop()
