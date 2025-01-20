extends Control

@onready var level_1_scene: PackedScene = preload("res://scenes/levels/level1.tscn")
@onready var test_scene: PackedScene = preload("res://scenes/levels/main.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(level_1_scene)

func _on_test_button_pressed() -> void:
	get_tree().change_scene_to_packed(test_scene)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
