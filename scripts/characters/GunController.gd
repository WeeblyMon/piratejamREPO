extends Node2D

@export var bullet_scene: PackedScene
@onready var raycast: RayCast2D = $RayCast2D
@onready var muzzle_handgun: Sprite2D = $PistolMF
@onready var muzzle_rifle: AnimatedSprite2D = $RifleMF
@onready var muzzle_shotgun: AnimatedSprite2D = $ShotgunMF

var current_weapon: String = GameStateManager.get_weapon()
var fire_rate: float = GameStateManager.get_fire_rate()
var weapon_data: Dictionary = GameStateManager.get_weapon_data()
var time_since_last_shot: float = 0.0
var last_fired_bullet: Node = null

func _ready() -> void:
	current_weapon = GameStateManager.get_weapon()
	fire_rate = GameStateManager.get_fire_rate()
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
	if bullet_scene and time_since_last_shot >= fire_rate:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = raycast.global_position
		bullet.rotation = raycast.global_rotation
		get_tree().current_scene.add_child(bullet)

		last_fired_bullet = bullet
		time_since_last_shot = 0.0
		fire_sfx()
		_show_muzzle_flash(current_weapon)
		return bullet
	return null

func fire_sfx() -> void:
	match current_weapon:
		"handgun":
			AudioManager.play_sfx("handgun_shot")
		"rifle":
			AudioManager.play_sfx_varied("rifle_shot", 0.0, false, 0.90, 1.1)
		"shotgun":
			AudioManager.play_sfx("shotgun_shot")
		_:
			AudioManager.play_sfx("gunshot_1")

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
	current_weapon = new_weapon
	fire_rate = GameStateManager.get_fire_rate()
	update_raycast(new_weapon)
	update_weapon(new_weapon)

func update_raycast(weapon_name: String) -> void:
	if weapon_data.has(weapon_name):
		var info = weapon_data[weapon_name]
		raycast.position = info["position"]
		raycast.target_position = info["direction"] * 100
		raycast.enabled = true

func update_weapon(weapon_name: String) -> void:
	fire_rate = GameStateManager.get_fire_rate()
	print("Updated weapon:", weapon_name, "Fire rate:", fire_rate)
