extends ProgressBar

func _process(delta: float) -> void:
	self.value = GameStateManager.current_resource
