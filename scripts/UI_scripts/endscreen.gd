extends Control

@onready var endscreen: Control = $"."  # Root UI container
@onready var blackscreen: ColorRect = $BlackScreen
@onready var failed_screen: Sprite2D = $Failed
@onready var complete_screen: Sprite2D = $Complete 
@export var player: CharacterBody2D

func _ready() -> void:
	# Ensure endscreen is hidden at start
	endscreen.visible = false
	blackscreen.visible = false
	failed_screen.visible = false
	complete_screen.visible = false

	# Connect signals if player exists
	if player and not player.is_connected("player_died", Callable(self, "_on_player_died")):
		player.connect("player_died", Callable(self, "_on_player_died"))

	# Connect checkpoint completion signal
	if not GameStateManager.is_connected("checkpoint_reached", Callable(self, "_on_checkpoint_reached")):
		GameStateManager.connect("checkpoint_reached", Callable(self, "_on_checkpoint_reached"))

func _on_player_died() -> void:
	print("Player died. Showing mission failed screen.")
	endscreen.visible = true
	blackscreen.visible = true
	failed_screen.visible = true
	complete_screen.visible = false
	AudioManager.stop_sfx("siren_passing_by_1")
	AudioManager.stop_sfx("crowd_chatter_1")
	

func _on_checkpoint_reached(checkpoint_id: int, is_final: bool) -> void:
	print("Checkpoint reached:", checkpoint_id, "Final:", is_final)  # Debugging log
	if is_final:  # ✅ Only trigger when reaching the final checkpoint
		print("Final checkpoint reached. Showing mission complete screen.")
		endscreen.visible = true
		blackscreen.visible = true
		complete_screen.visible = true
		failed_screen.visible = false
