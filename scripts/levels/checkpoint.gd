extends Area2D  # Now extends Area2D to detect collisions!

@export var checkpoint_id: int = 1
@export var path_label: String = "alpha"
@export var is_final: bool = false 

func _ready() -> void:
	add_to_group("checkpoints")
	connect("body_entered", Callable(self, "_on_body_entered"))  

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):  # ✅ Ensures only the player triggers it
		print("Checkpoint Reached:", checkpoint_id, "Final:", is_final)
		GameStateManager.emit_signal("checkpoint_reached", checkpoint_id, is_final)
