extends Control

@onready var level_1_scene: PackedScene = preload("res://scenes/levels/level1.tscn")
@onready var test_scene: PackedScene = preload("res://scenes/levels/main.tscn")

@onready var sprite1: AnimatedSprite2D = $MarginContainer/VBoxContainer/Start/AnimatedSprite2D
@onready var sprite2: AnimatedSprite2D = $MarginContainer/VBoxContainer/Start/AnimatedSprite2D2

func _ready() -> void:
	AudioManager.play_music("main menu")

	# Ensure they start playing
	if sprite1 and sprite1.sprite_frames and sprite1.animation != "":
		sprite1.play()

	if sprite2 and sprite2.sprite_frames and sprite2.animation != "":
		sprite2.play()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(level_1_scene)
	AudioManager.play_sfx("menu_navigation_confirm_1")
	
func _on_test_button_pressed() -> void:
	get_tree().change_scene_to_packed(test_scene)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
