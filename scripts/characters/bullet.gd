extends Node2D

@export var speed: float = 500.0 
@export var lifetime: float = 5.0 

var time_alive: float = 0.0
var is_controlled: bool = false  

func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()  
		return
	if is_controlled:
		control_bullet(delta)
	else:
		move_forward(delta)

func move_forward(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func control_bullet(delta: float) -> void:
	if Input.is_action_pressed("rotate_left"):
		rotation -= deg_to_rad(120 * delta)
	if Input.is_action_pressed("rotate_right"):
		rotation += deg_to_rad(120 * delta)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta * 0.5
	

	
