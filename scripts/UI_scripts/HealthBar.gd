extends TextureProgressBar
class_name HealthBar

@onready var healthbar: TextureProgressBar = $"."

func _ready() -> void:
	GameStateManager.health_bar = self
	GameStateManager.connect("health_changed", Callable(self, "_update_health"))

func _update_health(new_health: int, max_health: int) -> void:
	value = float(new_health) / float(max_health) * 100.0  # Convert to percentage
	print("Health Bar Updated: ", value, "%")
