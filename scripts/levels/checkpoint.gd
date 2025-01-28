extends Node2D

@export var checkpoint_id: int = 1
@export var path_label: String = "alpha"
@export var is_final: bool = false  # Determines if this is the final checkpoint

func _ready() -> void:
	add_to_group("checkpoints")

func on_player_enter_checkpoint():
	if is_final:  # Emit signal only if this is the final checkpoint
		GameStateManager.emit_signal("checkpoint_reached", checkpoint_id, is_final)
