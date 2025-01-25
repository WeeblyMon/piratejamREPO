extends CharacterBody2D

@export var speed: float = 150.0
var fire_rate = GameStateManager.get_fire_rate()
@export var gun: Node2D
@onready var jammed_sprite: Sprite2D = $JammedSprite
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var path_debug: Node2D
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

func _ready() -> void:
	jammed_sprite.visible = false
	GameStateManager.connect("sanity_changed", Callable(self, "_on_sanity_changed"))
	GameStateManager.connect("jam_state_changed", Callable(self, "_on_jam_state_changed"))

	if not navigation_agent:
		push_warning("NavigationAgent2D node not found!")
		return
	if path_debug and path_debug.has_method("set"):
		path_debug.navigation_agent = navigation_agent

	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())
	GameStateManager.init_checkpoints_for_ai(global_position)
	var first_cp_pos = GameStateManager.get_current_checkpoint_position()
	if first_cp_pos != Vector2.ZERO:
		print("Initial checkpoint pos:", first_cp_pos)
		navigation_agent.set_target_position(first_cp_pos)


func _process(delta: float) -> void:
	if Input.is_action_pressed("control_bullet"):
		if GameStateManager.consume_resource(20 * delta): 
			_enable_bullet_control()
		else:
			_disable_bullet_control()  
	else:
		_disable_bullet_control()
	if bullet_controlled:
		return

	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return
		
	match GameStateManager.get_wielder_phase():
		GameStateManager.WielderPhase.MOVEMENT:
			_process_movement_phase(delta)
			if GameStateManager.is_enemy_in_range(global_position):
				GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.COMBAT)

		GameStateManager.WielderPhase.COMBAT:
			_process_combat_phase(delta)
			if GameStateManager.all_enemies_cleared():
				GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
				var cp_pos = GameStateManager.get_current_checkpoint_position()
				if cp_pos != Vector2.ZERO:
					navigation_agent.set_target_position(cp_pos)

# ---------------------------------------------
#           MOVEMENT PHASE
# ---------------------------------------------
func _process_movement_phase(delta: float) -> void:
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
	move_and_slide()

	_check_if_reached_checkpoint()



func _check_if_reached_checkpoint() -> void:
	var cp_pos = GameStateManager.get_current_checkpoint_position()
	if cp_pos == Vector2.ZERO:
		return
	var dist = global_position.distance_to(cp_pos)
	if dist <= GameStateManager.stop_distance:
		print("Reached checkpoint index =", GameStateManager.current_checkpoint_index)
		GameStateManager.next_checkpoint()
		var next_cp = GameStateManager.get_current_checkpoint_position()
		if next_cp != Vector2.ZERO:
			print("Heading to next checkpoint:", next_cp)
			navigation_agent.set_target_position(next_cp)
		else:
			print("No more checkpoints to visit.")

# ---------------------------------------------
#           COMBAT PHASE
# ---------------------------------------------
func _process_combat_phase(delta: float) -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	if should_attack_civilians() and GameStateManager.current_sanity < 40:
		var civs = get_tree().get_nodes_in_group("civilian")
		all_enemies += civs  # Add civilians to the list of targets

	# If no valid enemy, find the nearest target
	if not is_instance_valid(last_known_enemy):
		if all_enemies.is_empty():
			velocity = Vector2.ZERO
			play_animation("idle")
			return
		var nearest = all_enemies[0]
		var min_dist = global_position.distance_to(nearest.global_position)
		for e in all_enemies:
			var dist = global_position.distance_to(e.global_position)
			if dist < min_dist:
				nearest = e
				min_dist = dist
		last_known_enemy = nearest

	# If still invalid or target is dead, return to movement
	if not is_instance_valid(last_known_enemy):
		_reset_cover_lock()
		GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
		return
	if last_known_enemy.has_method("is_dead") and last_known_enemy.is_dead():
		last_known_enemy = null
		_reset_cover_lock()
		GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.MOVEMENT)
		return

	# Adjust aim with accuracy offset
	var aim_dir = (last_known_enemy.global_position - global_position).normalized()
	aim_dir = aim_dir.rotated(get_accuracy_offset())  # Add inaccuracy based on sanity
	rotation = lerp_angle(rotation, aim_dir.angle(), 8.0 * delta)

	# Skip shooting if reloading
	if GameStateManager.is_reloading:
		return

	# Fire logic based on fire rate
	time_since_last_shot += delta
	if time_since_last_shot >= GameStateManager.get_fire_rate():
		if current_weapon == "shotgun":
			gun.fire_shotgun_volley()
		else:
			gun.fire_bullet()
		time_since_last_shot = 0.0

	# Cover logic
	if should_use_cover():
		if not cover_locked:
			var cover_pos = find_best_cover_position(global_position, last_known_enemy.global_position)
			var dist_to_cover = cover_pos.distance_to(global_position)
			if dist_to_cover <= max_cover_distance:
				cover_locked_position = cover_pos
				cover_locked = true
			else:
				move_and_slide()
				play_animation("idle")
				return

		_go_to_cover_and_shoot(cover_locked_position, last_known_enemy, delta)
		move_and_slide()
	else:
		# Avoid cover entirely
		velocity = Vector2.ZERO
		play_animation("idle")

func _go_to_cover_and_shoot(cover_pos: Vector2, enemy: Node, delta: float) -> void:
	var dist_to_cover = cover_pos.distance_to(global_position)
	if dist_to_cover > 50.0:
		# Move closer to cover
		navigation_agent.set_target_position(cover_pos)
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



# ---------------------------------------------
#           SHOOTING & WEAPON
# ---------------------------------------------
func shoot(target: Node) -> void:
	if is_playing_animation:
		return
	if gun and gun.has_method("fire_bullet"):
		var bullet = gun.fire_bullet()
		if bullet:
			last_fired_bullet = bullet
	if target and target.has_method("take_damage"):
		target.take_damage(1)
	play_animation("shoot")
	
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
		return  # <-- ADDED

	bullet_controlled = true

	# If we are in MOVEMENT phase and haven't saved a path yet
	if GameStateManager.get_wielder_phase() == GameStateManager.WielderPhase.MOVEMENT and not has_saved_path:
		saved_path_target = navigation_agent.get_target_position()
		has_saved_path = true
		print("Saved path target:", saved_path_target)

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
		return  # <-- ADDED

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

	has_saved_path = false  # <-- ADDED: reset so next time we can store again
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
	if covers.is_empty():
		return ai_pos

	var best_cover: Node2D = covers[0]
	var best_dist = ai_pos.distance_to(best_cover.global_position)
	for c in covers:
		var d = ai_pos.distance_to(c.global_position)
		if d < best_dist:
			best_cover = c
			best_dist = d

	if locked_cover_node and locked_cover_node.has_signal("cover_destroyed"):
		locked_cover_node.disconnect("cover_destroyed", Callable(self, "_on_cover_destroyed"))
	locked_cover_node = best_cover
	if locked_cover_node and locked_cover_node.has_signal("cover_destroyed"):
		locked_cover_node.connect("cover_destroyed", Callable(self, "_on_cover_destroyed"))
	var best_spot: Node2D = null
	var best_spot_dist = -INF
	for child in best_cover.get_children():
		if child is Node2D and child.name.begins_with("Position"):
			var dist_to_enemy = child.global_position.distance_to(enemy_pos)
			if dist_to_enemy > best_spot_dist:
				best_spot_dist = dist_to_enemy
				best_spot = child
	if best_spot:
		return best_spot.global_position
	else:
		return best_cover.global_position

func _on_cover_destroyed() -> void:
	print("Cover destroyed, AI must pick a new one.")
	_reset_cover_lock()
	locked_cover_node = null

func _reset_cover_lock() -> void:
	cover_locked = false
	cover_locked_position = Vector2.ZERO

func trigger_jam() -> void:
	if GameStateManager.is_jammed:
		return  # Already jammed, ignore
	GameStateManager.set_jam_state(true)
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
