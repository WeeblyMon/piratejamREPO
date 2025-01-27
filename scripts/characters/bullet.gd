extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 5.0
@export var damage: int = 1
@export var max_points: int = 5
@export var point_spacing: float = 20.0
@export var max_turn_rate: float = 420.0  # Max turn rate in degrees per second

var current_weapon = GameStateManager.get_weapon()
@onready var area: Area2D = $Area2D
@onready var local_line2d: Line2D = $Line2D
@onready var pistol_sprite: Sprite2D = $PistolP
@onready var rifle_sprite: Sprite2D = $RifleP
@onready var shotgun_sprite: Sprite2D = $ShotgunP

var time_alive: float = 0.0
var distance_accum: float = 0.0
var is_controlled: bool = false

func _ready() -> void:
	# Add this bullet to the appropriate group
	add_to_group("bullet")
	# Connect signals
	area.body_entered.connect(_on_body_entered)
	if local_line2d:
		local_line2d.clear_points()
	else:
		push_warning("Line2D is missing!")
	update_bullet_visibility()
	update_speed()

func update_speed() -> void:
	# Adjust speed based on weapon type
	match current_weapon:
		"handgun": speed = 1000
		"rifle": speed = 2000
		"shotgun": speed = 750
		_: speed = 500

func update_bullet_visibility() -> void:
	# Enable the correct sprite for the weapon type
	pistol_sprite.visible = current_weapon == "handgun"
	rifle_sprite.visible = current_weapon == "rifle"
	shotgun_sprite.visible = current_weapon == "shotgun"

func _process(delta: float) -> void:
	# Handle lifetime expiration
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return

	# Check for control toggles
	if Input.is_action_pressed("control_bullet"):
		if not is_controlled:
			enable_player_control()
	else:
		if is_controlled:
			disable_player_control()

	# Update movement logic
	if is_controlled:
		_control_bullet_with_mouse(delta)
	else:
		_move_forward(delta)

	# Update trail
	_update_trail()

func _move_forward(delta: float) -> void:
	# Basic forward movement
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _control_bullet_with_mouse(delta: float) -> void:
	# Adjust rotation to follow the mouse
	var mouse_pos = get_global_mouse_position()
	var target_angle = (mouse_pos - global_position).angle()
	var angle_difference = wrapf(target_angle - rotation, -PI, PI)
	var max_rotation = deg_to_rad(max_turn_rate) * delta
	rotation += clamp(angle_difference, -max_rotation, max_rotation)

	# Play steering sound if not already playing
	if not AudioManager.is_sfx_playing("bullet_steering_1"):
		AudioManager.play_sfx("bullet_steering_1", 1.0, true)  # Set to loop

	# Move the bullet forward
	_move_forward(delta)

func _update_trail() -> void:
	# Update the trail with the bullet's current position
	if not local_line2d:
		return
	var line_pos = local_line2d.to_local(global_position)
	if local_line2d.get_point_count() > 0:
		var last_pt = local_line2d.get_point_position(local_line2d.get_point_count() - 1)
		distance_accum += line_pos.distance_to(last_pt)
	else:
		distance_accum = point_spacing

	if distance_accum >= point_spacing:
		local_line2d.add_point(line_pos)
		distance_accum = 0.0
		if local_line2d.get_point_count() > max_points:
			local_line2d.remove_point(0)

func enable_player_control() -> void:
	# Enable control of the bullet
	is_controlled = true
	add_to_group("controlled_bullets")
	Engine.time_scale = 0.2  # Slow down time for control

	# Play the slow-motion sound once
	AudioManager.play_sfx("bullet_slow_mo_1", 1.0, false)  # Play sound with no looping

	time_alive = 0.0  # Reset time_alive for the controlled phase
	
func disable_player_control() -> void:
	# Disable control of the bullet
	is_controlled = false
	remove_from_group("controlled_bullets")
	Engine.time_scale = 1.0  # Restore normal time

	# Stop both sounds
	AudioManager.stop_sfx("bullet_slow_mo_1")
	AudioManager.stop_sfx("bullet_steering_1")

func _on_body_entered(body: Node) -> void:
	# Handle collisions
	if body.has_method("_start_panic"):
		body._start_panic()
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
	if local_line2d:
		local_line2d.clear_points()
