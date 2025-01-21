extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 5.0
@export var damage: int = 1  # Damage dealt by the bullet

var time_alive: float = 0.0
var is_controlled: bool = false  # True if the player is manually steering this bullet

@onready var area: Area2D = $Area2D  # Collision area

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)

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

func enable_player_control() -> void:
	is_controlled = true
	time_alive = 0  # Reset lifetime to allow prolonged control
	Engine.time_scale = 0.2  # Slow-motion effect

func disable_player_control() -> void:
	is_controlled = false
	Engine.time_scale = 1.0  # Reset time scale

# Handle collisions with other objects
func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)  # Apply damage if the object can take it
	queue_free()  # Destroy the bullet on impact
