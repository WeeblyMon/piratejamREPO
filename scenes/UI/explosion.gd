extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

func _ready() -> void:
	# Start the animation and the timer
	animated_sprite.play("explode")
	timer.start(animated_sprite.frames.get_frame_count("explode") / animated_sprite.frames.get_animation_speed("explode"))

func _on_Timer_timeout() -> void:
	queue_free()  # Remove the explosion once the animation is done
