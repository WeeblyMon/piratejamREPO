extends CharacterBody2D

@export var speed: float = 150.0  # Movement speed
@export var fire_rate: float = 1.0  # Shooting rate
@export var gun: Node2D  # Reference to the gun node
@export var stop_distance: float = 5.0  # Distance to stop at the target

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D  # Reference to NavigationAgent2D
@onready var path_debug: Node2D = $PathDebug  # Reference to PathDebug node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # Reference to AnimatedSprite2D
var is_playing_animation: bool = false
var time_since_last_shot: float = 0.0  # Timer for shooting
var is_paused: bool = false  # Pause flag for movement/shooting

func _ready() -> void:
	if not navigation_agent:
		print("NavigationAgent2D node not found!")
		return

	# Assign the NavigationAgent2D to the PathDebug node for visualization
	if path_debug and path_debug.has_method("set"):
		path_debug.navigation_agent = navigation_agent

	# Connect velocity_computed signal
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	# Notify the gun about the initial weapon from GameStateManager
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(GameStateManager.get_weapon())
		
func switch_weapon(new_weapon: String) -> void:
	# Update the weapon in GameStateManager
	GameStateManager.set_weapon(new_weapon)

	# Notify the gun about the new weapon
	if gun and gun.has_method("switch_weapon"):
		gun.switch_weapon(new_weapon)

	# Play idle animation for the new weapon
	play_animation("idle")

func _physics_process(delta: float) -> void:
	if is_paused:
		velocity = Vector2.ZERO
		play_animation("idle")  # Play idle animation while paused
		move_and_slide()
		return

	# Movement logic
	var next_position = navigation_agent.get_next_path_position()
	var distance_to_target = global_position.distance_to(next_position)

	if distance_to_target > stop_distance and next_position != Vector2.ZERO:
		velocity = (next_position - global_position).normalized() * speed
		play_animation("move")  # Play move animation
		var direction = next_position - global_position
		rotation = lerp_angle(rotation, direction.angle(), 10 * delta)
	else:
		velocity = Vector2.ZERO
		play_animation("idle")  # Play idle animation

	move_and_slide()

	# Shooting logic
	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func shoot() -> void:
	if is_playing_animation:
		return  # Skip shooting if the fire animation hasn't finished

	if gun and gun.has_method("fire_bullet"):
		gun.fire_bullet()
		play_animation("shoot")  # Play the shooting animation

func reload() -> void:
	# Play reload animation and disable shooting temporarily
	play_animation("reload")
	is_paused = true
	await("animation_finished")
	is_paused = false

func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)  # Pause by setting target to current position
	play_animation("idle")

func resume_shooting() -> void:
	is_paused = false

func set_target(target: Vector2) -> void:
	navigation_agent.set_target_position(target)
	print("Target set to:", target)

func _on_velocity_computed(velocity: Vector2) -> void:
	# Optional: Handle velocity changes dynamically
	pass

func play_animation(state: String) -> void:
	var animation_name = state + "_" + GameStateManager.get_weapon()

	if animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:  # Avoid restarting the same animation
			animated_sprite.play(animation_name)
			is_playing_animation = (state == "shoot")  # Only set the flag for "shoot" animation
	else:
		print("Animation not found:", animation_name)



func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "shoot_" + GameStateManager.get_weapon():
		is_playing_animation = false  # Reset the flag if the shooting animation finishes
