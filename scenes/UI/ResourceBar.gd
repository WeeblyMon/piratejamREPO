extends ProgressBar

func _process(delta: float) -> void:
	# Update the value of the ProgressBar directly
	self.value = GameStateManager.current_resource
