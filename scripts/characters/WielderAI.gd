extends CharacterBody2D

@export var speed: float = 150.0
var fire_rate = GameStateManager.get_fire_rate()
@export var gun: Node2D
@onready var jammed_sprite: Sprite2D = $JammedSprite
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var max_cover_distance: float = 400.0
var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0
var is_paused: bool = false
var last_fired_bullet: Node = null
var bullet_controlled: bool = false
var last_known_enemy: Node = null
var cover_locked: bool = false
var locked_cover_node: Node2D = null
var cover_locked_position: Vector2 = Vector2.ZERO
var saved_path_target: Vector2 = Vector2.ZERO
var current_weapon = GameStateManager.get_weapon()
var has_saved_path: bool = false 
var combat_cooldown: float = 0.0
var combat_cooldown_duration: float = 1.0
@export var fov_angle: float = 130  # Degrees
@export var detection_range: float = 500.0
var has_killed_enemy: bool = false
var cover_timeout: float = 5.0  # Maximum time in cover
var cover_timer: float = 0.0
@onready var detection_area: Area2D = Area2D.new()
@export var health: int = 100  # Wielder's health
var target: Node = null

# Enemy Position History for Movement Detection
var enemy_position_history: Array = []
var enemy_history_length: int = 5  # Number of previous positions to store
var enemy_movement_threshold: float = 50.0  # Distance moved to trigger re-evaluation

func _ready() -> void:
	_create_detection_area()
	jammed_sprite.visible = false
	GameStateManager.connect("sanity_changed", Callable(self, "_on_sanity_changed"))
	GameStateManager.connect("jam_state_changed", Callable(self, "_on_jam_state_changed"))

	if not navigation_agent:
		push_warning("NavigationAgent2D node not found!")
		return
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())
	GameStateManager.init_checkpoints_for_ai(global_position)
	var first_cp_pos = GameStateManager.get_current_checkpoint_position()
	if first_cp_pos != Vector2.ZERO:
		print("Initial checkpoint pos:", first_cp_pos)
		navigation_agent.set_target_position(first_cp_pos)

func _process(delta: float) -> void:
	# Handle bullet control input
	if Input.is_action_pressed("control_bullet"):
		if GameStateManager.consume_resource(20 * delta):
			_enable_bullet_control()
		else:
			_disable_bullet_control()
	else:
		_disable_bullet_control()

	# Handle paused state
	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	# Handle combat cooldown
	if combat_cooldown > 0.0:
		combat_cooldown -= delta
		if combat_cooldown < 0.0:
			combat_cooldown = 0.0

	# Phase-based AI behavior
	match GameStateManager.get_wielder_phase():
		GameStateManager.WielderPhase.MOVEMENT:
			_process_movement_phase(delta)
			if combat_cooldown == 0.0 and _is_enemy_detected():
				GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.COMBAT)

		GameStateManager.WielderPhase.COMBAT:
			# Use unscaled delta to ensure AI operates correctly during slow motion
			var unscaled_delta = delta / Engine.time_scale
			_process_combat_phase(unscaled_delta)

# ---------------------------------------------
#           MOVEMENT PHASE
# ---------------------------------------------
var footstep_timer: float = 0.0  # Timer to control footstep sounds

func _process_movement_phase(delta: float) -> void:
	# Check if the navigation agent has a valid path
	if navigation_agent.is_navigation_finished():
		# Set a new path to the next checkpoint
		_reset_navigation_target()

	var next_pos = navigation_agent.get_next_path_position()
	if next_pos == Vector2.ZERO:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	var direction = (next_pos - global_position).normalized()
	velocity = direction * (speed * get_speed_multiplier())
	rotation = lerp_angle(rotation, direction.angle(), 10.0 * delta)

	play_animation("move")
	
	# Handle footstep sounds based on `is_sfx_playing`
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		if not AudioManager.is_sfx_playing("footsteps_asphalt_1_1"):
			AudioManager.play_sfx("footsteps_asphalt_1_1", 0.5)
		elif not AudioManager.is_sfx_playing("footsteps_asphalt_1_2"):
			AudioManager.play_sfx("footsteps_asphalt_1_2", 0.5)
		footstep_timer = 0.5  # Adjust delay between steps as needed

	move_and_slide()

	_check_if_reached_checkpoint()

func _check_if_reached_checkpoint() -> void:
	var cp_pos = GameStateManager.get_current_checkpoint_position()
	if cp_pos == Vector2.ZERO:
		return
	var dist = global_position.distance_to(cp_pos)
	if dist <= GameStateManager.stop_distance:

		GameStateManager.next_checkpoint()
		var next_cp = GameStateManager.get_current_checkpoint_position()
		if next_cp != Vector2.ZERO:
			navigation_agent.set_target_position(next_cp)
		else:
			print("No more checkpoints to visit.")

# ---------------------------------------------
#           COMBAT PHASE
# ---------------------------------------------
func _process_combat_phase(delta: float) -> void:
	if has_killed_enemy:
		has_killed_enemy = false
		last_known_enemy = null  # Clear the killed enemy
		GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
		
		# Reset navigation to the next checkpoint
		_reset_navigation_target()
		combat_cooldown = combat_cooldown_duration
		return

	# Handle combat cooldown logic
	if combat_cooldown > 0.0:
		combat_cooldown -= delta
		if combat_cooldown > 0.0:
			velocity = Vector2.ZERO
			play_animation("idle")
			move_and_slide()
			return

	# Revalidate last_known_enemy or find a new one
	if not is_instance_valid(last_known_enemy):
		last_known_enemy = _find_nearest_enemy()

		# If no valid enemy, switch back to movement
		if not is_instance_valid(last_known_enemy):
			_reset_cover_lock()
			GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
			return

	# Check if enemy is within detection range
	var dist_to_enemy = global_position.distance_to(last_known_enemy.global_position)
	if dist_to_enemy > detection_range:
		last_known_enemy = null
		GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
		return

	# Monitor enemy movement and re-evaluate cover if necessary
	if is_instance_valid(last_known_enemy):
		enemy_position_history.append(last_known_enemy.global_position)
		if enemy_position_history.size() > enemy_history_length:
			enemy_position_history.pop_front()  # Use pop_front() in Godot 4.x
			# If using an older version, use:
			# enemy_position_history.erase(enemy_position_history[0])
		
		var avg_enemy_pos = Vector2.ZERO
		for pos in enemy_position_history:
			avg_enemy_pos += pos
		avg_enemy_pos /= enemy_position_history.size()
		
		var enemy_move_dist = avg_enemy_pos.distance_to(last_known_enemy.global_position)
		if enemy_move_dist >= enemy_movement_threshold:
			_reset_cover_lock()

	# Aim and rotate towards the enemy
	var aim_dir = (last_known_enemy.global_position - global_position).normalized()
	aim_dir = aim_dir.rotated(get_accuracy_offset())
	rotation = lerp_angle(rotation, aim_dir.angle(), 8.0 * delta)

	# Respect reload state
	if GameStateManager.is_reloading:
		play_animation("reload")
		return

	# Handle shooting with unscaled delta
	var facing_threshold = deg_to_rad(10)
	var angle_difference = abs(rotation - aim_dir.angle())
	if angle_difference <= facing_threshold and time_since_last_shot >= GameStateManager.get_fire_rate():
		shoot(last_known_enemy)
		if has_killed_enemy:
			return
		time_since_last_shot = 0.0
	else:
		time_since_last_shot += delta

	# Handle cover behavior
	if should_use_cover():
		if not cover_locked:
			var cover_pos = find_best_cover_position(global_position, last_known_enemy.global_position)
			var dist_to_cover = cover_pos.distance_to(global_position)
			if dist_to_cover <= max_cover_distance:
				cover_locked_position = cover_pos
				cover_locked = true
			else:
				velocity = Vector2.ZERO
				play_animation("idle")
				move_and_slide()
				return
		_go_to_cover_and_shoot(cover_locked_position, last_known_enemy, delta)
		move_and_slide()
	else:
		# Fallback to standing still and idling if no cover
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()

func _go_to_cover_and_shoot(cover_pos: Vector2, enemy: Node, delta: float) -> void:
	cover_timer += delta

	if cover_timer > cover_timeout:
		_reset_cover_lock()
		cover_timer = 0.0
		return

	var dist_to_cover = cover_pos.distance_to(global_position)
	if dist_to_cover > 50.0:
		# Move closer to cover
		if not navigation_agent.is_navigation_finished():
			navigation_agent.set_target_position(cover_pos)  # Ensure target is set
		
		var next_pos = navigation_agent.get_next_path_position()
		if next_pos != Vector2.ZERO:
			var dir = (next_pos - global_position).normalized()
			velocity = dir * speed
			rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)
			play_animation("move")
		else:
			velocity = Vector2.ZERO
			play_animation("idle")
	else:
		velocity = Vector2.ZERO
		play_animation("idle")
		cover_timer = 0.0  # Reset timer once cover is reached

# ---------------------------------------------
#           SHOOTING & WEAPON
# ---------------------------------------------
func shoot(target: Node) -> void:
	if is_playing_animation or GameStateManager.is_reloading:
		return

	# Check if target is within detection range
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > detection_range:
		return

	if gun and gun.has_method("fire_bullet"):
		var bullet = gun.fire_bullet()
		if bullet:
			last_fired_bullet = bullet

	if target and target.has_method("take_damage"):
		target.take_damage(1)
		if target.has_method("is_dead") and target.is_dead():
			has_killed_enemy = true
			last_known_enemy = null
			_reset_cover_lock()
			play_animation("shoot")
			return  # Exit early

	play_animation("shoot")

func _find_nearest_enemy() -> Node:
	var all_enemies = get_alive_enemies()
	if all_enemies.is_empty():
		return null  # No enemies found

	var nearest = null
	var min_dist = detection_range
	for enemy in all_enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			nearest = enemy
			min_dist = dist

	return nearest

func _shoot_enemy_direct(enemy: Node, delta: float) -> void:
	velocity = Vector2.ZERO
	var direction = (enemy.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, direction.angle(), 10.0 * delta)

	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		# If current weapon is shotgun, fire volley instead of a single bullet
		if current_weapon == "shotgun":
			gun.fire_shotgun_volley()
		else:
			if gun and gun.has_method("fire_bullet"):
				var bullet = gun.fire_bullet()
		time_since_last_shot = 0.0

	play_animation("idle")

func switch_weapon(new_weapon: String) -> void:
	GameStateManager.set_weapon(new_weapon)
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(new_weapon)
	play_animation("idle")

# ---------------------------------------------
#           BULLET CONTROL
# ---------------------------------------------
func _enable_bullet_control() -> void:
	# If we're already controlling bullets, do nothing
	if bullet_controlled:
		return

	bullet_controlled = true

	# If we are in MOVEMENT phase and haven't saved a path yet
	if GameStateManager.get_wielder_phase() == GameStateManager.WielderPhase.MOVEMENT and not has_saved_path:
		saved_path_target = navigation_agent.get_target_position()
		has_saved_path = true

	Engine.time_scale = 0.2
	pause_shooting()

	# If not shotgun, possibly spawn a bullet
	if current_weapon != "shotgun":
		if not last_fired_bullet or not is_instance_valid(last_fired_bullet):
			if gun and gun.has_method("fire_bullet"):
				last_fired_bullet = gun.fire_bullet()
				if last_fired_bullet:
					time_since_last_shot = 0.0
					print("AI fired bullet in slow motion")

	# Enable control if bullet exists
	if last_fired_bullet and is_instance_valid(last_fired_bullet):
		if last_fired_bullet.has_method("enable_player_control"):
			last_fired_bullet.enable_player_control()

func _disable_bullet_control() -> void:
	# If we weren't controlling bullets, do nothing
	if not bullet_controlled:
		return

	bullet_controlled = false

	Engine.time_scale = 1.0
	resume_shooting()

	# Restore the path if we had saved it
	if has_saved_path and GameStateManager.get_wielder_phase() == GameStateManager.WielderPhase.MOVEMENT:
		if saved_path_target != Vector2.ZERO:
			navigation_agent.set_target_position(saved_path_target)
			print("Restored path:", saved_path_target)

	# Clear bullet control
	if last_fired_bullet and is_instance_valid(last_fired_bullet):
		if last_fired_bullet.has_method("disable_player_control"):
			last_fired_bullet.disable_player_control()
	last_fired_bullet = null

	has_saved_path = false  # Reset to allow saving next time
	saved_path_target = Vector2.ZERO

func pause_shooting() -> void:
	is_paused = true
	play_animation("idle")

func resume_shooting() -> void:
	is_paused = false

# ---------------------------------------------
#           ANIMATION
# ---------------------------------------------
func play_animation(state: String) -> void:
	var weapon_name = GameStateManager.get_weapon()
	var anim = state + "_" + weapon_name
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		if animated_sprite.animation != anim:
			animated_sprite.play(anim)
			is_playing_animation = (state == "shoot")
	else:
		push_warning("Animation not found: %s" % anim)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "shoot_" + GameStateManager.get_weapon():
		is_playing_animation = false

# ---------------------------------------------
#           Cover System
# ---------------------------------------------

func find_best_cover_position(ai_pos: Vector2, enemy_pos: Vector2) -> Vector2:
	var covers = get_tree().get_nodes_in_group("cover")
	print("AI searching for covers. Total covers found:", covers.size())
	if covers.is_empty():
		print("No covers available.")
		return ai_pos

	# Determine AI's facing direction
	var facing_dir = Vector2(cos(rotation), sin(rotation)).normalized()
	print("AI facing direction (degrees):", rad_to_deg(facing_dir.angle()))

	var best_spot: Node2D = null
	var best_score = -INF

	# Define weights for scoring
	var enemy_weight = 2.0
	var ai_weight = 1.0
	# Removed cover_quality_weight since all covers are same

	for cover in covers:
		for child in cover.get_children():
			if child is Node2D and child.name.begins_with("Position"):
				var cover_pos = child.global_position
				var dir_to_cover = (cover_pos - ai_pos).normalized()
				var dot = facing_dir.dot(dir_to_cover)
				print("Evaluating cover at:", cover_pos, "Dot Product:", dot)

				# Prefer cover spots in front or to the sides (dot >= 0)
				if dot < 0:
					print("Skipping cover behind the AI.")
					continue  # Skip cover spots behind the AI

				var dist_to_enemy = cover_pos.distance_to(enemy_pos)
				var dist_to_ai = cover_pos.distance_to(ai_pos)

				# Define minimum and maximum distances
				var min_enemy_distance = 100.0  # Adjust as needed
				var max_ai_distance = 300.0  # Adjust as needed

				if dist_to_enemy < min_enemy_distance:
					print("Cover too close to enemy. Skipping.")
					continue  # Skip covers too close to the enemy

				if dist_to_ai > max_ai_distance:
					print("Cover too far from AI. Skipping.")
					continue  # Skip covers too far from the AI

				# Since all covers are same, assign a constant score component
				var cover_score = 1.0  # Equal weight for all covers

				# Scoring Mechanism
				var score = (dist_to_enemy * enemy_weight) - (dist_to_ai * ai_weight) + cover_score
				print("Cover score (weighted):", score)

				# Check if cover effectively blocks LoS
				if _is_cover_effective(cover_pos, ai_pos, enemy_pos):
					print("Cover at", cover_pos, "is effective.")
					if score > best_score:
						best_score = score
						best_spot = child
						print("New best cover found:", cover_pos)
				else:
					print("Cover at", cover_pos, "does not block LoS.")

	if best_spot:
		print("Selected cover at:", best_spot.global_position)
		_lock_cover_node(best_spot.get_parent())
		return best_spot.global_position

	# Second Pass: Fallback to any cover spot with LoS check
	best_spot = null
	best_score = -INF
	print("No suitable cover found in front. Performing fallback search.")

	for cover in covers:
		for child in cover.get_children():
			if child is Node2D and child.name.begins_with("Position"):
				var cover_pos = child.global_position
				var dist_to_enemy = cover_pos.distance_to(enemy_pos)
				var dist_to_ai = cover_pos.distance_to(ai_pos)
				var cover_score = 1.0  # Equal weight for all covers

				# Scoring Mechanism
				var score = (dist_to_enemy * enemy_weight) - (dist_to_ai * ai_weight) + cover_score

				if _is_cover_effective(cover_pos, ai_pos, enemy_pos):
					if score > best_score:
						best_score = score
						best_spot = child
	if best_spot:
		_lock_cover_node(best_spot.get_parent())
		return best_spot.global_position

	# If no cover spots are effective, stay in current position
	return ai_pos

func _is_cover_effective(cover_pos: Vector2, ai_pos: Vector2, enemy_pos: Vector2) -> bool:
	# Cast a ray from enemy to cover to check for obstacles
	var space_state = get_world_2d().direct_space_state
	
	# Create and configure the PhysicsRayQueryParameters2D object
	var ray_params = PhysicsRayQueryParameters2D.new()
	ray_params.from = enemy_pos
	ray_params.to = cover_pos
	ray_params.exclude = [self]  # Exclude the AI itself from collision detection
	
	# Optional: Specify collision layers/masks if needed
	# ray_params.collision_mask = 1 << 2  # Example: Only detect layer 3
	
	# Perform the raycast
	var collision = space_state.intersect_ray(ray_params)
	
	return false

# Helper function to lock onto the selected cover node
func _lock_cover_node(cover_node: Node2D) -> void:
	if locked_cover_node and locked_cover_node.has_signal("cover_destroyed"):
		locked_cover_node.disconnect("cover_destroyed", Callable(self, "_on_cover_destroyed"))
	
	locked_cover_node = cover_node
	
	if locked_cover_node and locked_cover_node.has_signal("cover_destroyed"):
		locked_cover_node.connect("cover_destroyed", Callable(self, "_on_cover_destroyed"))

func _on_cover_destroyed() -> void:
	_reset_cover_lock()
	locked_cover_node = null

func _reset_cover_lock() -> void:
	cover_locked = false
	cover_locked_position = Vector2.ZERO

func trigger_jam() -> void:
	if GameStateManager.is_jammed:
		return  # Already jammed, ignore
	GameStateManager.set_jam_state(true)
	AudioManager.play_sfx("gun_jam_1")
	jammed_sprite.visible = true
	GameStateManager.reload_weapon()
	await get_tree().create_timer(2.0).timeout  # Replace yield with await
	GameStateManager.set_jam_state(false)
	jammed_sprite.visible = false

func clear_jam():
	GameStateManager.set_jam_state(false)

func _on_jam_state_changed(is_jammed: bool) -> void:
	jammed_sprite.visible = is_jammed

#
# -------------- SANITY-BASED SECTION --------------
#

func get_sanity_fraction() -> float:
	var fraction = float(GameStateManager.current_sanity) / float(GameStateManager.max_sanity)
	return clamp(fraction, 0.0, 1.0)

# 1) Decide whether to use cover
func should_use_cover() -> bool:
	# Avoid cover entirely when sanity drops below 30
	return GameStateManager.current_sanity > 30

func get_speed_multiplier() -> float:
	var fraction = get_sanity_fraction()
	# If fraction=1 => speed=1.0, fraction=0 => speed=2.0 (twice as fast)
	return lerp(2.0, 1.0, fraction)

# 3) Adjust reload speed (slower with less sanity)
func get_reload_time_multiplier() -> float:
	var fraction = get_sanity_fraction()
	# fraction=1 => normal reload, fraction=0 => +100% time (2.0)
	return lerp(2.0, 1.0, fraction)

# 4) Lower accuracy: random aim offset
func get_accuracy_offset() -> float:
	var fraction = get_sanity_fraction()
	var max_degrees = 10.0  # Max inaccuracy at 0 sanity
	var spread = lerp(max_degrees, 0.0, fraction)
	return deg_to_rad(randf_range(-spread, spread))

# 5) Possibly attack civilians too
func should_attack_civilians() -> bool:
	# AI attacks civilians when sanity drops below 40
	return GameStateManager.current_sanity < 40

func _is_enemy_detected() -> bool:
	# Check if there is a valid target detected by the Area2D
	if target and target.is_in_group("enemy"):
		if target.has_method("is_dead") and target.is_dead():
			return false  # Enemy is dead, no valid target
		else:
			return true  # Valid enemy detected
	else:
		return false

func _reset_navigation_target() -> void:
	# Get the current checkpoint position
	var cp_pos = GameStateManager.get_current_checkpoint_position()

	# If the checkpoint position is valid, set it as the target
	if cp_pos != Vector2.ZERO:
		print("Resetting navigation target to checkpoint:", cp_pos)
		navigation_agent.set_target_position(cp_pos)
	else:
		# If no checkpoint is available, stop the agent
		print("No checkpoint available. Stopping navigation.")
		navigation_agent.set_target_position(global_position)  # Prevent unintended movement

# ---------------------------------------------
# HEALTH AND DAMAGE MANAGEMENT
# ---------------------------------------------
func take_damage(damage: int) -> void:
	health -= damage
	print("Wielder took damage! Health:", health)
	animated_sprite.modulate = Color(1, 0, 0)  # Flash red on damage
	_flash_color()
	if health <= 0:
		die()

func _flash_color() -> void:
	var flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1
	add_child(flash_timer)
	flash_timer.start()
	await flash_timer.timeout
	animated_sprite.modulate = Color(1, 1, 1)  # Reset color
	flash_timer.queue_free()
	AudioManager.play_sfx("pain_1")

func die() -> void:
	print("Wielder died!")
	AudioManager.play_sfx("death_1")
	queue_free()
	if AudioManager.is_music_playing("level_music"):
		AudioManager.stop_all_music()

# ---------------------------------------------
# DETECTION AREA
# ---------------------------------------------
func _create_detection_area() -> void:
	detection_area.name = "DetectionArea"
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	collision_shape.shape.radius = detection_range  # Use detection_range here
	detection_area.add_child(collision_shape)

	detection_area.collision_layer = 1  # Wielder's layer
	detection_area.collision_mask = 2  # Detect enemies
	detection_area.monitoring = true
	detection_area.connect("body_entered", Callable(self, "_on_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_body_exited"))
	add_child(detection_area)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		target = body
		print("Enemy detected:", target.name)

func _on_body_exited(body: Node) -> void:
	if body == target:
		target = null
		print("Enemy out of range.")

# ---------------------------------------------
#           Utility Functions
# ---------------------------------------------

# Function to retrieve all alive enemies
func get_alive_enemies() -> Array:
	var alive_enemies = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead"):
			if not enemy.is_dead():
				alive_enemies.append(enemy)
		else:
			# If the enemy doesn't have an 'is_dead()' method, assume it's alive
			alive_enemies.append(enemy)
	return alive_enemies
