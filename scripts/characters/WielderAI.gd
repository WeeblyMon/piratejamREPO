extends CharacterBody2D

@export var speed: float = 150.0
@export var fire_rate: float = 1.0
@export var stop_distance: float = 5.0
@export var gun: Node2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var path_debug: Node2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0
var is_paused: bool = false

# Bullet control
var last_fired_bullet: Node = null
var bullet_controlled: bool = false  # Tells if the bullet is currently under player control

func _ready() -> void:
	if not navigation_agent:
		push_warning("NavigationAgent2D node not found!")
		return

	if path_debug and path_debug.has_method("set"):
		path_debug.navigation_agent = navigation_agent

	navigation_agent.velocity_computed.connect(_on_velocity_computed)

	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())

func _process(delta: float) -> void:
	# 1) Check if user is holding "control_bullet"
	var is_control_button_down = Input.is_action_pressed("control_bullet") and last_fired_bullet != null
	
	# If the current bullet_controlled state is different from the user's input,
	# we either enable or disable bullet control:
	if is_control_button_down != bullet_controlled:
		bullet_controlled = is_control_button_down
		if bullet_controlled:
			_enable_bullet_control()
		else:
			_disable_bullet_control()

	# 2) If bullet is controlled, skip normal wielder logic
	if bullet_controlled:
		return

	# 3) If paused for other reasons (e.g. reloading), do nothing
	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	# 4) Normal movement with NavigationAgent2D
	var next_position = navigation_agent.get_next_path_position()
	var distance_to_target = global_position.distance_to(next_position)

	if distance_to_target > stop_distance and next_position != Vector2.ZERO:
		velocity = (next_position - global_position).normalized() * speed
		play_animation("move")
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)
	else:
		velocity = Vector2.ZERO
		play_animation("idle")

	move_and_slide()

	# 5) Shooting logic
	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

	# 6) Optional weapon swaps
	if Input.is_action_just_pressed("swap_to_handgun"):
		switch_weapon("handgun")
	elif Input.is_action_just_pressed("swap_to_rifle"):
		switch_weapon("rifle")
	elif Input.is_action_just_pressed("swap_to_shotgun"):
		switch_weapon("shotgun")


#
# ---------------- PUBLIC METHODS ----------------
#

func set_target(target: Vector2) -> void:
	navigation_agent.set_target_position(target)
	print("Target set to:", target)

func switch_weapon(new_weapon: String) -> void:
	GameStateManager.set_weapon(new_weapon)
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(new_weapon)
	play_animation("idle")

func shoot() -> void:
	if is_playing_animation:
		return
	if gun and gun.has_method("fire_bullet"):
		var bullet = gun.fire_bullet()
		if bullet:
			last_fired_bullet = bullet
	play_animation("shoot")

func reload() -> void:
	play_animation("reload")
	is_paused = true
	await("animation_finished")
	is_paused = false

func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)
	play_animation("idle")

func resume_shooting() -> void:
	is_paused = false

func _on_velocity_computed(agent_velocity: Vector2) -> void:
	# If needed, handle dynamic velocity
	pass

#
# ---------------- ANIMATION HELPERS -----------
#

func play_animation(state: String) -> void:
	var weapon_name = GameStateManager.get_weapon()
	var animation_name = state + "_" + weapon_name
	if animated_sprite and animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
			is_playing_animation = (state == "shoot")
	else:
		push_warning("Animation not found: %s" % animation_name)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "shoot_" + GameStateManager.get_weapon():
		is_playing_animation = false

#
# -------------- BULLET CONTROL ----------------
#

func _enable_bullet_control() -> void:
	Engine.time_scale = 0.2
	pause_shooting()  # Stop the wielder from moving/shooting
	if last_fired_bullet and last_fired_bullet.has_method("enable_player_control"):
		last_fired_bullet.enable_player_control()
	else:
		print("Bullet has no 'enable_player_control' method!")

func _disable_bullet_control() -> void:
	Engine.time_scale = 1.0
	resume_shooting()
	if last_fired_bullet and last_fired_bullet.has_method("disable_player_control"):
		last_fired_bullet.disable_player_control()
