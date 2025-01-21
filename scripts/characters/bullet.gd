extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 5.0
@export var damage: int = 1  # Damage dealt by the bullet

# Trail properties
@export var max_points: int = 20  # Maximum number of points in the trail
@export var point_spacing: float = 10.0  # Distance between trail points

@onready var sprite: Sprite2D = $Sprite2D  # Bullet sprite
@onready var area: Area2D = $Area2D  # Collision area
@export var line2d: Line2D # Trail node

var time_alive: float = 0.0
var is_controlled: bool = false  # True if the player is manually steering this bullet
var distance_accum: float = 0.0  # Used to control spacing between trail points

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	if line2d == null:
		push_warning("Line2D is not assigned. Please assign it in the editor.")
	else:
		line2d.clear_points()  # Ensure the trail starts empty

func _process(delta: float) -> void:
	time_alive += delta

	# If the bullet exceeds its lifetime, remove it
	if time_alive >= lifetime:
		queue_free()
		return

	if is_controlled:
		control_bullet(delta)
	else:
		move_forward(delta)

	_update_trail()

func move_forward(delta: float) -> void:
	# Normal bullet: move in the direction of 'rotation'
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func control_bullet(delta: float) -> void:
	# Rotate left/right with custom actions
	if Input.is_action_pressed("rotate_left"):
		rotation -= deg_to_rad(160 * delta)
	if Input.is_action_pressed("rotate_right"):
		rotation += deg_to_rad(160 * delta)

	# Move forward more slowly while controlled
	position += Vector2.RIGHT.rotated(rotation) * speed * delta * 0.7

func _update_trail() -> void:
	if line2d == null:
		return

	# Calculate the distance from the last point to the current position
	if line2d.get_point_count() > 0:
		var last_point = line2d.get_point_position(line2d.get_point_count() - 1)
		var distance = global_position.distance_to(last_point)
		distance_accum += distance
	else:
		distance_accum = point_spacing  # Ensure the first point is added

	# Add a new point if the accumulated distance exceeds the spacing
	if distance_accum >= point_spacing:
		line2d.add_point(global_position)
		distance_accum = 0.0

		# Remove the oldest point if we exceed the max number of points
		if line2d.get_point_count() > max_points:
			line2d.remove_point(0)

func enable_player_control() -> void:
	is_controlled = true
	time_alive = 0  # Reset lifetime to allow prolonged control
	Engine.time_scale = 0.2  # Slow-motion effect

func disable_player_control() -> void:
	is_controlled = false
	Engine.time_scale = 1.0  # Reset time scale

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)  # Apply damage if the object can take it
	queue_free()  # Destroy the bullet on impact

	# Clear the trail on destruction
	if line2d:
		line2d.clear_points()
