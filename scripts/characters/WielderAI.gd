extends CharacterBody2D

@export var speed: float = 150.0  # Movement speed
@export var fire_rate: float = 1.0  # Shooting rate (seconds)
@export var stop_distance: float = 5.0  # Distance to stop at the target
@export var gun: Node2D  # Reference to a Gun node, which presumably instantiates bullets

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var path_debug: Node2D  # Optional PathDebug node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0
var is_paused: bool = false

# -- Control Bullet Mechanic Variables --
var last_fired_bullet: Node = null
var bullet_controlled: bool = false  # Is the player currently controlling a bullet?

func _ready() -> void:
	if not navigation_agent:
		push_warning("NavigationAgent2D node not found!")
		return

	# If your path_debug script has a "navigation_agent" property, assign it:
	if path_debug and path_debug.has_method("set"):
		path_debug.navigation_agent = navigation_agent

	# Connect signal if you want velocity_computed for dynamic movement (optional)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

	# Initialize the gun’s current weapon from GameStateManager
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())

func _process(delta: float) -> void:
	# 1) If the player pressed the bullet-control action:
	if Input.is_action_just_pressed("control_bullet"):
		_control_bullet_pressed()

	# If the bullet is under control, skip normal wielder logic
	if bullet_controlled:
		# The bullet is being steered by the player; time is slowed.
		return

	# If paused (e.g., reloading, manual pause, etc.), do nothing but idle
	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	# 2) Movement Logic with NavigationAgent2D
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

	# 3) Shooting logic
	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

	# 4) Optional weapon swaps
	if Input.is_action_just_pressed("swap_to_handgun"):
		switch_weapon("handgun")
	elif Input.is_action_just_pressed("swap_to_rifle"):
		switch_weapon("rifle")
	elif Input.is_action_just_pressed("swap_to_shotgun"):
		switch_weapon("shotgun")

#
# -------------------------- Public Methods -------------------------------
#

func set_target(target: Vector2) -> void:
	# Move toward target by setting NavigationAgent2D's destination
	navigation_agent.set_target_position(target)
	print("Target set to:", target)

func switch_weapon(new_weapon: String) -> void:
	# Update the weapon in GameStateManager
	GameStateManager.set_weapon(new_weapon)

	# Notify the gun about the new weapon
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(new_weapon)

	play_animation("idle")

func shoot() -> void:
	if is_playing_animation:
		# Avoid interrupting a shooting animation in progress
		return

	if gun and gun.has_method("fire_bullet"):
		# Fire the bullet and store reference to the last bullet
		var bullet = gun.fire_bullet()
		if bullet:
			last_fired_bullet = bullet

		play_animation("shoot")  # Animate the wielder

func reload() -> void:
	play_animation("reload")
	is_paused = true
	await("animation_finished")  # If you have a custom signal or logic
	is_paused = false

func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)  # Force the agent to stand still
	play_animation("idle")

func resume_shooting() -> void:
	is_paused = false

#
# ----------------- Navigation Agent / Velocity Signal --------------------
#

func _on_velocity_computed(agent_velocity: Vector2) -> void:
	# Optional if you want dynamic velocity from agent
	pass

#
# ----------------- Animation Helpers --------------------
#

func play_animation(state: String) -> void:
	# Use GameStateManager.get_weapon() to get the current weapon name
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
# ----------------- Bullet Control Logic --------------------
#

func _control_bullet_pressed() -> void:
	# Only if we have a bullet to control
	if last_fired_bullet == null:
		print("No bullet to control.")
		return

	# 1) Slow down time
	Engine.time_scale = 0.2

	# 2) Pause the wielder
	pause_shooting()

	# 3) Mark bullet_controlled so we skip normal logic
	bullet_controlled = true

	# 4) Tell the bullet it’s under player control
	if last_fired_bullet.has_method("enable_player_control"):
		last_fired_bullet.enable_player_control()
	else:
		print("Bullet has no 'enable_player_control' method!")

func release_bullet_control() -> void:
	# Called when done controlling or bullet hits something
	bullet_controlled = false
	Engine.time_scale = 1.0  # Reset normal time
	resume_shooting()

	if last_fired_bullet and last_fired_bullet.has_method("disable_player_control"):
		last_fired_bullet.disable_player_control()

	last_fired_bullet = null
