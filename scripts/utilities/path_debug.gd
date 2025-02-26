extends Node2D

@export var navigation_region: NavigationRegion2D  # Reference to NavigationRegion2D
@export var path_color: Color = Color(0, 1, 0)  # Path line color
@export var path_thickness: float = 2.0
@export var navigation_agent: NavigationAgent2D

var path_points: Array[Vector2] = []  # Stores the path for debugging

func set_navigation_region(region: NavigationRegion2D) -> void:
	navigation_region = region

func set_path(points: Array[Vector2]) -> void:
	path_points = points
	queue_redraw()

func _draw() -> void:
	if path_points.size() > 1:
		# Draw path using global positions
		for i in range(path_points.size() - 1):
			draw_line(
				to_local(path_points[i]), 
				to_local(path_points[i + 1]), 
				path_color, 
				path_thickness
			)
