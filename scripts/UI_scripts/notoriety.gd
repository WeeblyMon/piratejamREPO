extends Control

@onready var stars = [$"1", $"2", $"3", $"4"]
@onready var progress_bar: ProgressBar = $ProgressNoto

func _ready() -> void:
	# Initialize all stars to invisible
	for star in stars:
		star.visible = false

	# Connect notoriety change signal and update the UI initially
	GameStateManager.connect("notoriety_changed", Callable(self, "_update_notoriety"))
	_update_notoriety(GameStateManager.notoriety, GameStateManager.max_stars)

func _update_notoriety(current_notoriety: int, max_stars: int) -> void:
	# Update progress bar
	progress_bar.value = current_notoriety
	progress_bar.max_value = GameStateManager.max_progress

	for i in range(len(stars)):
		stars[i].visible = i < max_stars  # Show stars up to the current max_stars count
