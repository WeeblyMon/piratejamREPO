extends CharacterBody2D

@export var speed: float = 150.0  # Movement speed
@export var fire_rate: float = 1.0  # Time between shots
@export var gun: Node2D  # Reference to the gun node
@export var stop_distance: float = 5.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D  # Reference to NavigationAgent2D
@onready var path_debug: Node2D = $PathDebug  # Reference to the debug node

var time_since_last_shot: float = 0.0  # Timer for shooting
var is_paused: bool = false  # Flag to pause movement/shooting

func _ready() -> void:
	if not navigation_agent:
		print("NavigationAgent2D node not found!")
		return

	# Assign the NavigationAgent2D to the PathDebug node for visualization
	if path_debug and path_debug.has_method("set"):
		path_debug.navigation_agent = navigation_agent

	# Connect velocity_computed signal
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	if is_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Update velocity using NavigationAgent2D
	var next_position = navigation_agent.get_next_path_position()
	var distance_to_target = global_position.distance_to(next_position)

	if distance_to_target > stop_distance and next_position != Vector2.ZERO:
		velocity = (next_position - global_position).normalized() * speed

		# Smooth rotation to face the direction of movement
		var direction = next_position - global_position
		rotation = lerp_angle(rotation, direction.angle(), 10 * delta)  # Adjust 10 for speed
	else:
		velocity = Vector2.ZERO  # Stop moving

	move_and_slide()

	# Shooting logic
	time_since_last_shot += delta
	if time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func shoot() -> void:
	if gun and gun.has_method("fire_bullet"):
		gun.fire_bullet()

func pause_shooting() -> void:
	is_paused = true
	navigation_agent.set_target_position(global_position)  # Pause by setting target to current position

func resume_shooting() -> void:
	is_paused = false

func set_target(target: Vector2) -> void:
	navigation_agent.set_target_position(target)
	print("Target set to:", target)

func _on_velocity_computed(velocity: Vector2) -> void:
	# Optional: Handle velocity changes dynamically
	pass
