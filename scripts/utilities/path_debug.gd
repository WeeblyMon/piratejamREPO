extends Node2D

@export var navigation_agent: NavigationAgent2D  # Assign the NavigationAgent2D from the Wielder
@export var navigation_region: NavigationRegion2D  # Assign the NavigationRegion2D

var is_map_ready: bool = false  # Track if the navigation map is ready

func _ready() -> void:
	if navigation_agent:
		# Connect the path_changed signal
		var callable = Callable(self, "_on_navigation_agent_path_changed")
		if not navigation_agent.is_connected("path_changed", callable):
			navigation_agent.path_changed.connect(callable)
			print("Connected to path_changed signal!")
		else:
			print("Already connected to path_changed signal.")
	else:
		print("NavigationAgent2D is not assigned!")

	# Connect the NavigationServer2D 'map_changed' signal to handle map synchronization
	NavigationServer2D.map_changed.connect(_on_navigation_map_changed)

func _on_navigation_map_changed(map) -> void:
	print("Navigation map synchronized for map:", map)
	is_map_ready = true
	queue_redraw()  # Redraw after the map is synchronized

func _draw() -> void:
	if not is_map_ready:
		print("Navigation map is not ready yet!")
		return

	if navigation_agent and navigation_region:
		# Get the start and target positions
		var start = to_local(navigation_agent.get_parent().global_position)
		var target = to_local(navigation_agent.get_target_position())

		# Get the navigation map from NavigationRegion2D
		var nav_map = navigation_region.get_world_2d().navigation_map
		if nav_map == null:
			print("NavigationRegion2D does not have a valid navigation map!")
			return

		# Calculate the path using the navigation map
		var path = NavigationServer2D.map_get_path(
			nav_map,
			navigation_agent.get_parent().global_position,  # Keep these in global space for pathfinding
			navigation_agent.get_target_position(),
			false  # Do not allow partial paths
		)
		print("Drawing path:", path)

		# Draw the calculated path, converting each point to local space
		if path.size() > 1:
			for i in range(path.size() - 1):
				var local_start = to_local(path[i])
				var local_end = to_local(path[i + 1])
				draw_line(local_start, local_end, Color(0, 0, 1), 1)  # Bright green with thickness 5
		else:
			print("Path is empty or invalid.")


func _on_navigation_agent_path_changed() -> void:
	if is_map_ready:
		print("Path changed! Redrawing...")
		queue_redraw()
	else:
		print("Map not ready yet, cannot redraw path.")
