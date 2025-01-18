extends Node2D

@export var navigation_agent: NavigationAgent2D  # Assign the NavigationAgent2D from the Wielder
@export var navigation_region: NavigationRegion2D  # Assign the NavigationRegion2D

func _ready() -> void:
	if navigation_agent:
		navigation_agent.path_changed.connect(_on_path_changed)

func _on_path_changed() -> void:
	queue_redraw()  # Request a redraw of the path

func _draw() -> void:
	if navigation_agent and navigation_region:
		var start = navigation_agent.global_position
		var target = navigation_agent.get_target_position()
		var path = navigation_region.get_simple_path(start, target, true)  # Recalculate the path
		for i in range(path.size() - 1):
			draw_line(path[i], path[i + 1], Color(1, 0, 0), 2)
