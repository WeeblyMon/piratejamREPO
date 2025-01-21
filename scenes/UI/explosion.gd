extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Check if the "explode" animation exists
	if animated_sprite.sprite_frames.has_animation("explode"):
		# Play the "explode" animation
		animated_sprite.play("explode")
		
		# Connect the "animation_finished" signal using a Callable
		animated_sprite.animation_finished.connect(_on_Animation_finished)
	else:
		push_warning("Animation 'explode' not found in AnimatedSprite2D.")

func _on_Animation_finished() -> void:
	# Once the animation finishes, remove the node
	queue_free()
