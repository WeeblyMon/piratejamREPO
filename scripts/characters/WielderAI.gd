extends CharacterBody2D

@export var speed: float = 150.0  # Movement speed
@export var fire_rate: float = 1.0  # Shooting rate
@export var stop_distance: float = 5.0  # Distance to stop at the target
@export var gun: Node2D  # Reference to the gun node

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var path_debug: Node2D 
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0
var is_paused: bool = false

func _ready() -> void:
	if not navigation_agent:
		push_warning("NavigationAgent2D node not found!")
		return

	# If you have a path_debug script that uses the same agent, you can set it up here.
	if path_debug and path_debug.has_method("set"):
		# Example: path_debug.navigation_agent = navigation_agent
		# or path_debug.set_navigation_agent(navigation_agent)
		path_debug.navigation_agent = navigation_agent

	# Connect velocity_computed signal if you're using dynamic velocity from the agent.
	# (In many cases, you can just call get_next_path_position() directly in _process().)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

	# Notify the gun about the initial weapon from GameStateManager
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())


func _process(delta: float) -> void:
	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()  # Godot 4: uses CharacterBody2D's built-in velocity
		return

	# Move toward the next position in the navigation path
	var next_position = navigation_agent.get_next_path_position()
	var distance_to_target = global_position.distance_to(next_position)

	if distance_to_target > stop_distance and next_position != Vector2.ZERO:
		# Move
		velocity = (next_position - global_position).normalized() * speed
		play_animation("move")
		# Smooth rotate toward the move direction
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)
	else:
		# Idle
		velocity = Vector2.ZERO
		play_animation("idle")

	move_and_slide()  # No assignment in Godot 4; returns collision count

	# Shooting logic
	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

	# Example input for weapon swapping
	if Input.is_action_just_pressed("swap_to_handgun"):
		switch_weapon("handgun")
	elif Input.is_action_just_pressed("swap_to_rifle"):
		switch_weapon("rifle")
	elif Input.is_action_just_pressed("swap_to_shotgun"):
		switch_weapon("shotgun")


func set_target(target: Vector2) -> void:
	# Update the agent with the new target
	navigation_agent.set_target_position(target)
	print("Target set to:", target)


func switch_weapon(new_weapon: String) -> void:
	# Update the weapon in GameStateManager
	GameStateManager.set_weapon(new_weapon)

	# Notify the gun about the new weapon
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(new_weapon)

	# Play idle animation for the new weapon
	play_animation("idle")


func shoot() -> void:
	# Don't interrupt a playing shooting animation
	if is_playing_animation:
		return

	if gun and gun.has_method("fire_bullet"):
		gun.fire_bullet()
		play_animation("shoot")  # Play the shooting animation


func reload() -> void:
	# Example reload logic
	play_animation("reload")
	is_paused = true
	await("animation_finished")  # If you're using a signal or custom logic
	is_paused = false


func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)  # Force the agent to stay still
	play_animation("idle")


func resume_shooting() -> void:
	is_paused = false


# Called when NavigationAgent2D emits velocity_computed (if you want dynamic velocity from the agent).
func _on_velocity_computed(agent_velocity: Vector2) -> void:
	# You can handle velocity changes if needed, e.g. for custom acceleration.
	# If you rely on get_next_path_position() each frame, you can leave this empty.
	pass


func play_animation(state: String) -> void:
	var animation_name = state + "_" + GameStateManager.get_weapon()
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
			is_playing_animation = (state == "shoot")
	else:
		push_warning("Animation not found: %s" % animation_name)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "shoot_" + GameStateManager.get_weapon():
		is_playing_animation = false
