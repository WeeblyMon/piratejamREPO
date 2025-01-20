extends Node

signal game_loaded
signal game_saved

var wielder
var current_level: int = 1
var current_scene: Node

var current_weapon: String = "shotgun"

var current_save: Dictionary = {
	"current_scene_path": "",
	"sanity": 1,
	"morality": 1,
	"health": 1
}

@onready var sanity_bar
@onready var health_bar

# ---------------------------------------
# WEAPON GET/SET
# ---------------------------------------
func set_weapon(weapon_name: String) -> void:
	current_weapon = weapon_name
	print("Weapon switched to:", current_weapon)

func get_weapon() -> String:
	return current_weapon

# ---------------------------------------
# SCENE SWITCHING
# ---------------------------------------
func switch_scene(new_scene_path: String) -> void:
	assert(new_scene_path != "", "Scene path cannot be empty.")

	var new_scene: PackedScene = load(new_scene_path)
	assert(new_scene, "Failed to load scene: %s".format(new_scene_path))

	var new_scene_instance: Node = new_scene.instantiate()

	get_tree().root.add_child(new_scene_instance)

	if current_scene != null:
		current_scene.queue_free()

	current_scene = new_scene_instance
	print("Switched to new scene: %s".format(new_scene_path))

# ---------------------------------------
# SANITY / HEALTH (unchanged)
# ---------------------------------------
func set_sanity(sanity_amount: int, operation) -> void:
	current_save = _update_dict_int_value(Constants.SANITY, sanity_amount, operation)
	sanity_bar.update_bar(operation, sanity_amount)
	print(JSON.stringify(current_save))

func set_health(health_amount: int, operation) -> void:
	current_save = _update_dict_int_value(Constants.HEALTH, health_amount, operation)
	health_bar.update_bar(operation, health_amount)
	print(JSON.stringify(current_save))

func _update_dict_int_value(key: String, value, operation) -> Dictionary:
	var new_save = current_save.duplicate()
	if operation == Constants.OPERATIONS.ADD:
		new_save[key] = new_save[key] + value
	elif operation == Constants.OPERATIONS.SUB:
		new_save[key] = new_save[key] - value
	else:
		assert(operation in Constants.OPERATIONS, "Not an implemented method")
	return new_save

# ---------------------------------------
# AI PHASE & CHECKPOINT SYSTEM
# ---------------------------------------
enum WielderPhase { MOVEMENT, COMBAT }

var current_wielder_phase: int = WielderPhase.MOVEMENT

func set_wielder_phase(new_phase: int) -> void:
	current_wielder_phase = new_phase
	print("GameStateManager: Phase changed to:", new_phase)

func get_wielder_phase() -> int:
	return current_wielder_phase


# For the random path logic:
var chosen_path_label: String = ""
var path_checkpoints: Array = []
var current_checkpoint_index: int = 0
var stop_distance: float = 5.0

func init_checkpoints() -> void:
	path_checkpoints.clear()
	current_checkpoint_index = 0

	var all_cp = get_tree().get_nodes_in_group("checkpoints")
	var unique_labels = []
	for cp in all_cp:
		if cp.path_label not in unique_labels:
			unique_labels.append(cp.path_label)

	if unique_labels.size() > 0:
		var random_index = randi() % unique_labels.size()
		chosen_path_label = unique_labels[random_index]
		print("GameStateManager: chosen path label:", chosen_path_label)

		for cp in all_cp:
			if cp.path_label == chosen_path_label:
				path_checkpoints.append(cp)

		path_checkpoints.sort_custom(Callable(self, "_compare_cp_by_id"))

		# --- Debug print the final order ---
		for cp in path_checkpoints:
			print("Sorted checkpoint -> ID:", cp.checkpoint_id, "pos:", cp.global_position)

func get_current_checkpoint_position() -> Vector2:
	if current_checkpoint_index >= path_checkpoints.size():
		return Vector2.ZERO
	var cp = path_checkpoints[current_checkpoint_index]
	return cp.global_position

func next_checkpoint() -> void:
	current_checkpoint_index += 1
	if current_checkpoint_index >= path_checkpoints.size():
		print("GameStateManager: All path checkpoints done.")

func _compare_cp_by_id(a, b) -> int:
	# We want ID=1 to appear before ID=2, etc. => ascending order.
	if a.checkpoint_id < b.checkpoint_id:
		return -1   # "a" is smaller => put a first
	elif a.checkpoint_id > b.checkpoint_id:
		return 1    # "a" is bigger => put a after b
	else:
		return 0    # same ID

# ---------------------------------------
# COMBAT HELPERS (stubs)
# ---------------------------------------
func is_enemy_in_range(ai_position: Vector2, range_dist: float = 300.0) -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if ai_position.distance_to(e.global_position) < range_dist:
			return true
	return false

func all_enemies_cleared() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	return enemies.is_empty()

func find_nearest_cover(ai_position: Vector2) -> Vector2:
	var covers = get_tree().get_nodes_in_group("cover")
	if covers.is_empty():
		return ai_position  # fallback
	var best_dist = INF
	var best_cover
	for c in covers:
		var d = ai_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best_cover = c
	return best_cover.global_position
