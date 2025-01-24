extends Control

@onready var stars = [$"1", $"2", $"3", $"4"]
@onready var progress_bar: ProgressBar = $ProgressNoto

func _ready() -> void:
	for star in stars:
		star.visible = false 

	# Properly connect the signal
	GameStateManager.connect("notoriety_changed", Callable(self, "_update_notoriety"))
	_update_notoriety(GameStateManager.notoriety, GameStateManager.max_stars)

func _update_notoriety(current_notoriety: int, max_stars: int) -> void:
	progress_bar.value = current_notoriety
	progress_bar.max_value = GameStateManager.max_progress

	for i in range(len(stars)):
		stars[i].visible = i < (4 - max_stars)  
