extends Node

signal game_loaded
signal game_saved
signal sanity_changed(sanity: int)
signal wielder_phase_changed(new_phase: int)
signal ammo_changed

signal weapon_changed(new_weapon: String)
signal jam_state_changed(is_jammed: bool)
signal notoriety_changed(current_notoriety: int, max_stars: int)

var notoriety: int = 0
var max_stars: int = 0
var max_progress: int = 25
var is_jammed: bool = false
var reload_timer: Timer = null
var is_reloading: bool = false
var wielder
var current_level: int = 1
var current_scene: Node
var max_resource: float = 100.0
var resource_regen_rate: float = 10.0  # Resource regenerated per second
var current_resource: float = max_resource
var current_weapon: String = "handgun"
var max_sanity: int = 100
var current_sanity: int = max_sanity
var fire_rate: float = 0.0  # Default fire rate in seconds per shot (600 BPM)
var is_tv_static_playing: bool = false
var weapon_data = {
	"handgun": {"fire_rate": 0.5, "position": Vector2(163, 44), "direction": Vector2(1, 0)},  # 120 BPM
	"rifle": {"fire_rate": 0.1, "position": Vector2(181, 36), "direction": Vector2(1, 0)},    # 600 BPM
	"shotgun": {"fire_rate": 1.0, "position": Vector2(186, 37), "direction": Vector2(1, 0)}   # 60 BPM
}

var weapon_ammo = {
	"handgun": {"current": 8, "max": 8},
	"rifle": {"current": 30, "max": 30},
	"shotgun": {"current": 6, "max": 6}
}

func get_weapon_data() -> Dictionary:
	return weapon_data

func get_weapon_ammo() -> Dictionary:
	return weapon_ammo

var current_save: Dictionary = {
	"current_scene_path": "",
	"sanity": 1,
	"morality": 1,
	"health": 1
}

@onready var sanity_bar
@onready var health_bar



func _process(delta: float) -> void:
	current_resource = min(max_resource, current_resource + resource_regen_rate * delta)
	check_sanity()
# ---------------------------------------
# WEAPON GET/SET
# ---------------------------------------
func set_weapon(weapon_name: String) -> void:
	if weapon_data.has(weapon_name):
		# Update weapon and related properties
		current_weapon = weapon_name
		fire_rate = weapon_data[weapon_name]["fire_rate"]

		# Update ammunition for the new weapon
		if weapon_ammo.has(current_weapon):
			emit_signal("ammo_changed", weapon_ammo[current_weapon]["current"], weapon_ammo[current_weapon]["max"])
		else:
			print("Warning: No ammo data for weapon:", current_weapon)

		# Emit signal for weapon change
		emit_signal("weapon_changed", current_weapon)

		print("Weapon switched to:", current_weapon, "Fire rate:", fire_rate, "Seconds per shot")
	else:
		push_warning("Invalid weapon: %s".format(weapon_name))

func get_weapon() -> String:
	return current_weapon
	
func get_fire_rate() -> float:
	return fire_rate / Engine.time_scale


func set_jam_state(state: bool) -> void:
	is_jammed = state
	print("GameStateManager: Jam state changed to:", is_jammed)
	
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
# SANITY / HEALTH 
# ---------------------------------------
func set_sanity(sanity_amount: int, operation: String = "set") -> void:
	match operation:
		"add":
			current_sanity = clamp(current_sanity + sanity_amount, 0, max_sanity)
		"sub":
			current_sanity = clamp(current_sanity - sanity_amount, 0, max_sanity)
		"set":
			current_sanity = clamp(sanity_amount, 0, max_sanity)
		_:
			push_warning("Invalid operation for set_sanity: %s".format(operation))

	emit_signal("sanity_changed", current_sanity)
	AudioManager.play_sfx("sanity_heartbeat_1")

	# Update the SanityBar if it exists
	if sanity_bar:
		sanity_bar.update_sanity_bar(current_sanity, max_sanity)

			
func check_sanity() -> void:
	if current_sanity < 30:
		if not is_tv_static_playing:
			AudioManager.play_sfx("tv_static_1", 0.3, true)
			is_tv_static_playing = true
	else:
		if is_tv_static_playing:
			AudioManager.stop_sfx("tv_static_1")  # Stop the sound if sanity recovers
			is_tv_static_playing = false


func set_health(health_amount: int, operation) -> void:
	current_save = _update_dict_int_value(Constants.HEALTH, health_amount, operation)
	health_bar.update_bar(operation, health_amount)
	print(JSON.stringify(current_save))
	
func adjust_sanity(amount: int) -> void:
	current_sanity = clamp(current_sanity + amount, 0, max_sanity)
	emit_signal("sanity_changed", current_sanity)
	

func _update_dict_int_value(key: String, value, operation) -> Dictionary:
	var new_save = current_save.duplicate()
	if operation == Constants.OPERATIONS.ADD:
		new_save[key] = new_save[key] + value
	elif operation == Constants.OPERATIONS.SUB:
		new_save[key] = new_save[key] - value
	else:
		assert(operation in Constants.OPERATIONS, "Not an implemented method")
	return new_save
	
func consume_resource(amount: float) -> bool:
	if current_resource >= amount:
		current_resource -= amount
		return true
	return false

# ---------------------------------------
# AI PHASE & CHECKPOINT SYSTEM
# ---------------------------------------
enum WielderPhase { MOVEMENT, COMBAT }

var current_wielder_phase: int = WielderPhase.MOVEMENT

func set_wielder_phase(new_phase: int) -> void:
	if current_wielder_phase != new_phase:
		current_wielder_phase = new_phase
		emit_signal("wielder_phase_changed", new_phase)
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
		for cp in path_checkpoints:
			print("Sorted checkpoint -> ID:", cp.checkpoint_id, "pos:", cp.global_position)

func init_checkpoints_for_ai(ai_position: Vector2) -> void:
	# Clear any previously stored checkpoints
	path_checkpoints.clear()
	current_checkpoint_index = 0

	# Get all nodes in the 'checkpoints' group
	var all_cp = get_tree().get_nodes_in_group("checkpoints")
	if all_cp.is_empty():
		print("No checkpoints found in the 'checkpoints' group!")
		return

	# Debugging: Log all checkpoints
	print("Found checkpoints:")
	for cp in all_cp:
		print("- Label:", cp.path_label, "ID:", cp.checkpoint_id, "Position:", cp.global_position)

	# Get unique path labels
	var unique_labels = []
	for cp in all_cp:
		if cp.path_label not in unique_labels:
			unique_labels.append(cp.path_label)

	# Debugging: Log unique labels
	print("Unique path labels found:", unique_labels)

	# Select a random path label and filter checkpoints by it
	if unique_labels.size() > 0:
		var random_index = randi() % unique_labels.size()
		chosen_path_label = unique_labels[random_index]
		print("Chosen path label:", chosen_path_label)

		for cp in all_cp:
			if cp.path_label == chosen_path_label:
				path_checkpoints.append(cp)

	# Debugging: Log unsorted checkpoints
	print("Unsorted checkpoints for label", chosen_path_label, ":")
	for cp in path_checkpoints:
		print("- ID:", cp.checkpoint_id, "Position:", cp.global_position)

	# Debugging: Log sorted checkpoints
	print("Sorted checkpoints for label", chosen_path_label, ":")
	for cp in path_checkpoints:
		print("- ID:", cp.checkpoint_id, "Position:", cp.global_position)

	# Find the nearest checkpoint to the AI
	var nearest_index = 0
	var nearest_dist = INF
	for i in range(path_checkpoints.size()):
		var dist = ai_position.distance_to(path_checkpoints[i].global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_index = i

	current_checkpoint_index = nearest_index
	print("Nearest checkpoint is index =", nearest_index,
		  "ID =", path_checkpoints[nearest_index].checkpoint_id,
		  "dist =", nearest_dist)

func get_current_checkpoint_position() -> Vector2:
	if current_checkpoint_index >= path_checkpoints.size():
		return Vector2.ZERO
	var cp = path_checkpoints[current_checkpoint_index]
	return cp.global_position

func next_checkpoint() -> void:
	# Increment the checkpoint index
	current_checkpoint_index += 1

	# Check if there are more checkpoints
	if current_checkpoint_index >= path_checkpoints.size():
		print("GameStateManager: All checkpoints visited.")
	else:
		print("GameStateManager: Moving to checkpoint index =", current_checkpoint_index,
			  "Position =", path_checkpoints[current_checkpoint_index].global_position)


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
	
# ---------------------------------------
# AMMO MANAGEMENT
# ---------------------------------------
func get_current_ammo() -> int:
	if weapon_ammo.has(current_weapon):
		return weapon_ammo[current_weapon]["current"]
	return 0
	
func consume_ammo() -> bool:
	if is_reloading:
		return false

	if weapon_ammo.has(current_weapon):
		var ammo_data = weapon_ammo[current_weapon]
		if ammo_data["current"] > 0:
			ammo_data["current"] -= 1
			emit_signal("ammo_changed", ammo_data["current"], ammo_data["max"])  # Emit signal
			print("Ammo consumed. Remaining:", ammo_data["current"])
			return true
		else:
			print("Out of ammo!")
			return false
	else:
		print("No ammo data for weapon:", current_weapon)
		return false



func reload_weapon() -> void:
	if is_reloading:
		return  # Already reloading, do nothing

	if not weapon_ammo.has(current_weapon):
		return  # No ammo data for this weapon?

	var ammo_data = weapon_ammo[current_weapon]

	# Handle shotgun reload (one shell at a time)
	if current_weapon == "shotgun":
		if ammo_data["current"] < ammo_data["max"]:
			AudioManager.play_sfx("reload_1")
			if reload_timer == null:
				reload_timer = Timer.new()
				reload_timer.one_shot = true
				add_child(reload_timer)

				# Connect only once
				if not reload_timer.timeout.is_connected(Callable(self, "_on_shotgun_reload_step")):
					reload_timer.timeout.connect(Callable(self, "_on_shotgun_reload_step"))
			else:
				reload_timer.stop()
			reload_timer.wait_time = 0.5  # 0.5 seconds for shotgun (reload one shell per tick)
			reload_timer.start()
			is_reloading = true
		else:
			is_reloading = false

	# Handle handgun and rifle reload (entire clip at once)
	elif current_weapon == "handgun" or current_weapon == "rifle":
		AudioManager.play_sfx("reload_1")
		if reload_timer == null:
			reload_timer = Timer.new()
			reload_timer.one_shot = true
			add_child(reload_timer)

			if not reload_timer.timeout.is_connected(Callable(self, "_on_full_reload_complete")):
				reload_timer.timeout.connect(Callable(self, "_on_full_reload_complete"))
		else:
			reload_timer.stop()
		reload_timer.wait_time = 1.5  
		reload_timer.start()
		is_reloading = true
	else:
		print("No reload logic defined for weapon:", current_weapon)


func _on_shotgun_reload_step() -> void:
	var ammo_data = weapon_ammo[current_weapon]
	ammo_data["current"] += 1
	print("Shotgun reloaded 1 shell. Current ammo:", ammo_data["current"])

	if ammo_data["current"] < ammo_data["max"]:
		reload_timer.start()  # Continue reloading
		AudioManager.play_sfx("reload_1")
	else:
		is_reloading = false
		reload_timer.stop()
		reload_timer.queue_free()
		reload_timer = null
		print("Shotgun fully reloaded.")

func _on_full_reload_complete() -> void:
	var ammo_data = weapon_ammo[current_weapon]
	ammo_data["current"] = ammo_data["max"] 
	print("Reloaded", current_weapon, "to max ammo:", ammo_data["max"])
	is_reloading = false
	reload_timer.stop()
	reload_timer.queue_free()
	reload_timer = null

func add_notoriety(amount: int) -> void:
	notoriety += amount
	if notoriety >= max_progress:
		notoriety -= max_progress
		emit_signal("notoriety_changed", notoriety, max_stars)  # Notify HUD
		add_star()
	else:
		emit_signal("notoriety_changed", notoriety, max_stars)

func add_star() -> void:
	if notoriety >= max_progress:
		notoriety -= max_progress  # Reset progression bar
		emit_signal("notoriety_changed", notoriety, max_stars)  # Notify HUD

		# Cap stars at 4
		if max_stars < 4:
			max_stars += 1  # Increment stars
			emit_signal("notoriety_changed", notoriety, max_stars)  # Notify HUD again for star change

			# Assign weapons or handle logic based on the current star count
			match max_stars:
				1:
					set_weapon("rifle")  # Switch to rifle
				2:
					set_weapon("shotgun")  # Switch to shotgun
				3:
					print("Star 3 earned. No weapon defined yet.")
				4:
					print("Star 4 earned. No weapon defined yet.")
		else:
			print("Max stars reached. No further weapon upgrades available.")
	else:
		emit_signal("notoriety_changed", notoriety, max_stars)  # Partial progress updates
