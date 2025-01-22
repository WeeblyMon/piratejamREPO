extends CharacterBody2D

@export var speed: float = 150.0
@export var fire_rate: float = 1.0
@export var gun: Node2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var path_debug: Node2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0
var is_paused: bool = false
var last_fired_bullet: Node = null
var bullet_controlled: bool = false

func _ready() -> void:
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
	# A) Bullet control check
	var is_control_button_down = Input.is_action_pressed("control_bullet") and last_fired_bullet != null
	if is_control_button_down != bullet_controlled:
		bullet_controlled = is_control_button_down
		if bullet_controlled:
			_enable_bullet_control()
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
			# If we detect enemies, switch to combat
			if GameStateManager.is_enemy_in_range(global_position):
				GameStateManager.set_wielder_phase(GameStateManager.WielderPhase.COMBAT)

		GameStateManager.WielderPhase.COMBAT:
			_process_combat_phase(delta)
			# If enemies are cleared, return to movement
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
	velocity = direction * speed
	rotation = lerp_angle(rotation, direction.angle(), 10.0 * delta)

	play_animation("move")
	move_and_slide()

	_check_if_reached_checkpoint()



func _check_if_reached_checkpoint() -> void:
	var cp_pos = GameStateManager.get_current_checkpoint_position()
	if cp_pos == Vector2.ZERO:
		return

	# Check distance to the current checkpoint
	var dist = global_position.distance_to(cp_pos)

	# If the AI has reached the current checkpoint
	if dist <= GameStateManager.stop_distance:
		print("Reached checkpoint index =", GameStateManager.current_checkpoint_index)
		GameStateManager.next_checkpoint()

		# Set the next checkpoint as the target
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
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		velocity = Vector2.ZERO
		play_animation("idle")
		return

	# Find the nearest enemy
	var nearest_enemy = enemies[0]
	var min_dist = global_position.distance_to(nearest_enemy.global_position)
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			nearest_enemy = e
			min_dist = d

	# Find best cover relative to that enemy
	var cover_pos = find_best_cover_position(global_position, nearest_enemy.global_position)
	var dist_to_cover = cover_pos.distance_to(global_position)

	# CHANGED: If cover is too far, skip cover and just shoot
	var max_cover_dist = 400.0
	if dist_to_cover <= max_cover_dist:
		_go_to_cover_and_shoot(cover_pos, nearest_enemy, delta)
	else:
		_shoot_enemy_direct(nearest_enemy, delta)

	move_and_slide()


func _go_to_cover_and_shoot(cover_pos: Vector2, enemy: Node, delta: float) -> void:
	if cover_pos.distance_to(global_position) > 30:
		# Move towards cover
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
		# Once near cover, shoot at the enemy
		velocity = Vector2.ZERO
		var dir2 = (enemy.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, dir2.angle(), 10.0 * delta)
		time_since_last_shot += delta
		if time_since_last_shot >= fire_rate:
			var b = gun.fire_bullet()
			if b:
				print("Shooting at:", enemy.name)
			time_since_last_shot = 0.0
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

	# Reduce target's health if it has a `take_damage` method
	if target and target.has_method("take_damage"):
		target.take_damage(1)

	play_animation("shoot")
	
func _shoot_enemy_direct(enemy: Node, delta: float) -> void:
	velocity = Vector2.ZERO
	var dir = (enemy.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)

	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		var b = gun.fire_bullet()
		if b:
			print("Shooting directly at:", enemy.name)
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
	Engine.time_scale = 0.2
	pause_shooting()
	if last_fired_bullet and last_fired_bullet.has_method("enable_player_control"):
		last_fired_bullet.enable_player_control()

func _disable_bullet_control() -> void:
	Engine.time_scale = 1.0
	resume_shooting()
	if last_fired_bullet and last_fired_bullet.has_method("disable_player_control"):
		last_fired_bullet.disable_player_control()

func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)
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

	var best_cover = covers[0]
	var best_dist = ai_pos.distance_to(best_cover.global_position)
	for c in covers:
		var d = ai_pos.distance_to(c.global_position)
		if d < best_dist:
			best_cover = c
			best_dist = d

	var dir_away = (best_cover.global_position - enemy_pos).normalized()
	return best_cover.global_position + dir_away * best_cover.get_radius()
