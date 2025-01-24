extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 5.0
@export var damage: int = 1
@export var max_points: int = 5
@export var point_spacing: float = 20.0

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
	add_to_group("bullet")
	
	area.body_entered.connect(_on_body_entered)
	if local_line2d:
		local_line2d.clear_points()
		local_line2d.get_parent().remove_child(local_line2d)
		get_tree().root.add_child(local_line2d)
		local_line2d.global_transform = Transform2D()
	else:
		push_warning("No child Line2D found")
	
	update_bullet_visibility()
	update_speed()
	
func update_speed() -> void:
	if current_weapon == "handgun":
		speed = 1000
	elif current_weapon == "rifle":
		speed = 2000
	elif current_weapon == "shotgun":
		speed = 750
	else:
		speed = 500
		

func update_bullet_visibility() -> void:
	pistol_sprite.visible = current_weapon == "handgun"
	rifle_sprite.visible = current_weapon == "rifle"
	shotgun_sprite.visible = current_weapon == "shotgun"

func _process(delta: float) -> void:
	# Calculate unscaled delta to maintain consistent behavior regardless of time scale
	var unscaled_delta = delta / Engine.time_scale

	time_alive += unscaled_delta
	if time_alive >= lifetime:
		queue_free()
		return

	if is_controlled:
		_control_bullet(unscaled_delta)
	else:
		_move_forward(unscaled_delta)

	_update_trail(unscaled_delta)

func _move_forward(unscaled_delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * unscaled_delta

func _control_bullet(unscaled_delta: float) -> void:
	if Input.is_action_pressed("rotate_left"):
		rotation -= deg_to_rad(160 * unscaled_delta)
	if Input.is_action_pressed("rotate_right"):
		rotation += deg_to_rad(160 * unscaled_delta)
	position += Vector2.RIGHT.rotated(rotation) * speed * unscaled_delta * 0.7


func _update_trail(unscaled_delta: float) -> void:
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
	is_controlled = true
	time_alive = 0.0
	Engine.time_scale = 0.2

func disable_player_control() -> void:
	is_controlled = false
	Engine.time_scale = 1.0

func _on_body_entered(body: Node) -> void:
	if body.has_method("_start_panic"):
			body._start_panic()
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
	if local_line2d:
		local_line2d.clear_points()
