extends Node2D

@export var checkpoint_id: int = 1
@export var path_label: String = "alpha"
@export var is_final: bool = false

func _ready() -> void:
	add_to_group("checkpoints")
