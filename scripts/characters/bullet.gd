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

@onready var sprite: Sprite2D = null  # Declare 'sprite' variable

var time_alive: float = 0.0
var distance_accum: float = 0.0
var is_controlled: bool = false

func _ready() -> void:
	# Add this bullet to the "bullet" group
	add_to_group("bullet")

	# Set Collision Layer and Mask
	area.collision_layer = 5  # Layer 5: Player Bullet
	area.collision_mask = (1 << 1) | (1 << 6) # Layers 2 (Enemy) and 4 (Enemy Bullet) (7 is civilian)
	# Connect collision signal using Callable syntax for Area2D
	if not area.is_connected("area_entered", Callable(self, "_on_area_entered")):
		area.connect("area_entered", Callable(self, "_on_area_entered"))
	
		# **Connect the body_entered signal**
	if not area.is_connected("body_entered", Callable(self, "_on_body_entered")):
		area.connect("body_entered", Callable(self, "_on_body_entered"))
		
	# Clear trail points
	if local_line2d:
		local_line2d.clear_points()
	# Update visibility and speed based on weapon
	update_bullet_visibility()
	update_speed()
	
	# Assign 'sprite' based on current_weapon
	if current_weapon == "handgun":
		sprite = pistol_sprite
	elif current_weapon == "rifle":
		sprite = rifle_sprite
	elif current_weapon == "shotgun":
		sprite = shotgun_sprite
	else:
		sprite = pistol_sprite  # Default to pistol_sprite if weapon type is unknown

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
	# Basic forward movement using manual position updates
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

	# Move the bullet forward using manual position updates
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
	if not is_controlled:
		is_controlled = true
		add_to_group("controlled_bullets")
		area.collision_mask = (1 << 1) | (1 << 3) | (1 << 6)  # Layer 4

		Engine.time_scale = 0.2  # Slow down time for control

		if not AudioManager.is_sfx_playing("bullet_slow_mo_1"):
			AudioManager.play_sfx("bullet_slow_mo_1", 3.0, false)  # Play sound without looping

		time_alive = 0.0  # Reset time_alive for the controlled phase

func disable_player_control() -> void:
	# Disable control of the bullet
	if is_controlled:
		is_controlled = false
		remove_from_group("controlled_bullets")
		area.collision_mask = (1 << 1) | (1 << 3)  # Layers 2 and 4

		Engine.time_scale = 1.0  # Restore normal time

		# Stop the slow-motion sound
		if AudioManager.is_sfx_playing("bullet_slow_mo_1"):
			AudioManager.stop_sfx("bullet_slow_mo_1")

		# Stop the steering sound if it was playing
		if AudioManager.is_sfx_playing("bullet_steering_1"):
			AudioManager.stop_sfx("bullet_steering_1")

func _on_area_entered(area_other: Area2D) -> void:
	if is_in_group("controlled_bullets") and area_other.is_in_group("enemy_bullets"):
		area_other.queue_free()  # Destroy enemy bullet

		if sprite:
			sprite.modulate = Color(1, 1, 0)  # Yellow flash
			var flash_timer = Timer.new()
			flash_timer.one_shot = true
			flash_timer.wait_time = 0.1
			add_child(flash_timer)
			flash_timer.connect("timeout", Callable(self, "_reset_flash"), CONNECT_DEFERRED)
			flash_timer.start()
			AudioManager.play_sfx("enemy_hit_1_1")
		else:
			push_warning("Sprite is not assigned!")

		return  # Exit to prevent further processing
	elif area_other.has_method("take_damage"):
		area_other.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node) -> void:
	AudioManager.play_sfx("enemy_hit_1_1")  # Play ding sound
	if body.has_method("take_damage"):
		body.take_damage(damage)  # Apply damage to the enemy or civilian
	queue_free()  # Destroy the player bullet after hitting the enemy or civilian


func _reset_flash() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1)  # Reset to original color
