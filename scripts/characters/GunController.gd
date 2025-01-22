extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5

@onready var raycast: RayCast2D = $RayCast2D
@onready var muzzle_handgun: Sprite2D = $PistolMF
@onready var muzzle_rifle: AnimatedSprite2D = $RifleMF
@onready var muzzle_shotgun: AnimatedSprite2D = $ShotgunMF

var weapon_data = {
	"handgun": {"position": Vector2(163, 44), "direction": Vector2(1, 0), "fire_rate": 2.0},
	"rifle":   {"position": Vector2(181, 36), "direction": Vector2(1, 0), "fire_rate": 0.2},
	"shotgun": {"position": Vector2(186, 37), "direction": Vector2(1, 0), "fire_rate": 1.0}
}

var current_fire_rate: float = 0.5
var time_since_last_shot: float = 0.0
var last_fired_bullet: Node = null

func _ready() -> void:
	var current_weapon = GameStateManager.get_weapon()
	update_raycast(current_weapon)
	update_weapon(current_weapon)
	muzzle_handgun.visible = false
	muzzle_rifle.visible = false
	muzzle_shotgun.visible = false

func _process(delta: float) -> void:
	time_since_last_shot += delta
	if is_instance_valid(last_fired_bullet):
		if Input.is_action_pressed("control_bullet"):
			last_fired_bullet.enable_player_control()
		else:
			last_fired_bullet.disable_player_control()
	else:
		last_fired_bullet = null

func fire_bullet() -> Node:
	if bullet_scene and time_since_last_shot >= current_fire_rate:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = raycast.global_position
		bullet.rotation = raycast.global_rotation
		get_tree().current_scene.add_child(bullet)

		last_fired_bullet = bullet
		time_since_last_shot = 0.0
		print("Bullet fired from", GameStateManager.get_weapon())

		_show_muzzle_flash(GameStateManager.get_weapon())
		return bullet
	return null


func _show_muzzle_flash(weapon_name: String) -> void:
	muzzle_handgun.visible = false
	muzzle_rifle.visible = false
	muzzle_shotgun.visible = false

	match weapon_name:
		"handgun":
			muzzle_handgun.visible = true
			await get_tree().create_timer(0.1).timeout
			muzzle_handgun.visible = false

		"rifle":
			muzzle_rifle.visible = true
			muzzle_rifle.play("flash")
			await muzzle_rifle.animation_finished
			muzzle_rifle.visible = false

		"shotgun":
			muzzle_shotgun.visible = true
			muzzle_shotgun.play("flash")
			await muzzle_shotgun.animation_finished
			muzzle_shotgun.visible = false

func switch_weapon(new_weapon: String) -> void:
	GameStateManager.set_weapon(new_weapon)
	update_raycast(new_weapon)
	update_weapon(new_weapon)

func update_raycast(weapon_name: String) -> void:
	if weapon_data.has(weapon_name):
		var info = weapon_data[weapon_name]
		raycast.position = info["position"]
		raycast.target_position = info["direction"] * 100
		raycast.enabled = true

func update_weapon(weapon_name: String) -> void:
	if weapon_data.has(weapon_name):
		current_fire_rate = weapon_data[weapon_name]["fire_rate"]
		print("Updated weapon:", weapon_name, "Fire rate:", current_fire_rate)
