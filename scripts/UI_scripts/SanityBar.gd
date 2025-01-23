extends TextureProgressBar
class_name SanityBar

func _init() -> void:
	GameStateManager.sanity_bar = self
	
func update_sanity_bar(sanity: int, max_sanity: int) -> void:
	self.value = float(sanity) / float(max_sanity) * self.max_value
