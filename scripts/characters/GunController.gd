extends Node2D

@export var bullet_scene: PackedScene
@onready var raycast: RayCast2D = $RayCast2D
@onready var muzzle_handgun: Sprite2D = $PistolMF
@onready var muzzle_rifle: AnimatedSprite2D = $RifleMF
@onready var muzzle_shotgun: AnimatedSprite2D = $ShotgunMF
var is_reloading: bool = false
var current_weapon: String = GameStateManager.get_weapon()
var fire_rate: float = GameStateManager.get_fire_rate()
var weapon_data: Dictionary = GameStateManager.get_weapon_data()
var time_since_last_shot: float = 0.0
var last_fired_bullet: Node = null
var reload_timer: Timer = null
var base_shell_time: float = 0.5

func _ready() -> void:
	current_weapon = GameStateManager.get_weapon()
	GameStateManager.connect("weapon_changed", Callable(self, "_on_weapon_changed"))
	_on_weapon_changed(GameStateManager.get_weapon())
	GameStateManager.connect("jam_state_changed", Callable(self, "_on_jam_state_changed"))
	fire_rate = GameStateManager.get_fire_rate()
	update_raycast(current_weapon)
	update_weapon(current_weapon)
	muzzle_handgun.visible = false
	muzzle_rifle.visible = false
	muzzle_shotgun.visible = false
	
func _on_weapon_changed(new_weapon: String) -> void:
	current_weapon = new_weapon
	fire_rate = GameStateManager.get_fire_rate()
	update_raycast(new_weapon)
	update_weapon(new_weapon)
	print("GunController updated to:", new_weapon, "Fire rate:", fire_rate)
	
func get_sanity_fraction() -> float:
	var fraction = float(GameStateManager.current_sanity) / float(GameStateManager.max_sanity)
	return clamp(fraction, 0.0, 1.0)

func _process(delta: float) -> void:
	# Increment with unscaled delta to ensure consistent behavior in slow motion
	var unscaled_delta = delta / Engine.time_scale
	time_since_last_shot += unscaled_delta

	var controlled_bullets = get_tree().get_nodes_in_group("controlled_bullets")

	if Input.is_action_pressed("control_bullet"):
		if controlled_bullets.size() == 0:
			return  
		if is_instance_valid(last_fired_bullet):
			last_fired_bullet.enable_player_control()
	else:
		if is_instance_valid(last_fired_bullet):
			last_fired_bullet.disable_player_control()


func fire_bullet() -> Node:
	# Prevent firing if the weapon is jammed
	AudioManager.play_sfx_varied("casing_drop_1", 1.2, false, 0.9, 1.4)
	if GameStateManager.is_jammed:
		print("GunController: Cannot fire while jammed!")
		return null

	# Use unscaled delta to account for slow motion
	var unscaled_delta = 1.0 / Engine.time_scale
	if time_since_last_shot < fire_rate * unscaled_delta:
		return null

	# Prevent firing if reloading
	if GameStateManager.is_reloading:
		print("Cannot fire while reloading!")
		return null

	# Handle shotgun logic (fires multiple pellets)
	if current_weapon == "shotgun":
		fire_shotgun_volley()
		time_since_last_shot = 0.0
		return null

	# Standard bullet logic
	if bullet_scene and GameStateManager.get_current_ammo() > 0:
		# Consume ammo before firing
		if GameStateManager.consume_ammo():
			# Instantiate and configure the bullet
			var bullet = bullet_scene.instantiate()
			bullet.global_position = raycast.global_position
			bullet.rotation = raycast.global_rotation
			get_tree().current_scene.add_child(bullet)

			# Update state for the last fired bullet
			last_fired_bullet = bullet
			time_since_last_shot = 0.0

			# Play firing effects
			fire_sfx()
			_show_muzzle_flash(current_weapon)

			return bullet
	else:
		# If out of ammo, initiate a reload
		print("No ammo left! Starting reload...")
		reload_weapon()

	return null



	
func fire_shotgun_volley() -> void:
	# Check jam/reload states
	if GameStateManager.is_jammed:
		print("GunController: Cannot fire while jammed!")
		return

	if GameStateManager.is_reloading:
		print("GunController: Cannot fire while reloading!")
		return

	if GameStateManager.get_current_ammo() < 1:
		print("Not enough ammo for shotgun volley! Starting reload...")
		GameStateManager.reload_weapon()
		return

	# Consume exactly 1 ammo for the entire volley
	if GameStateManager.consume_ammo():
		# Spread settings
		var spread_angle = deg_to_rad(20)  # total angle of the cone
		var pellet_count = 10
		var angle_step = spread_angle / (pellet_count - 1)

		# Spawn each pellet
		for i in range(pellet_count):
			var bullet = bullet_scene.instantiate()
			bullet.global_position = raycast.global_position
			bullet.rotation = raycast.global_rotation - (spread_angle * 0.5) + (angle_step * i)

			get_tree().current_scene.add_child(bullet)

		print("GunController: Shotgun volley fired!")
		fire_sfx()
		_show_muzzle_flash(current_weapon)

func reload_weapon() -> void:
	if is_reloading:
		return  # Already reloading, do nothing

	# If for some reason we let the GunController reload other weapons fully:
	if current_weapon != "shotgun":
		GameStateManager.reload_weapon()
		return

	# Check if shotgun is already full
	var weap_ammo_dict = GameStateManager.get_weapon_ammo()
	if not weap_ammo_dict.has(current_weapon):
		push_warning("No ammo data for weapon: %s".format(current_weapon))
		return

	var ammo_data = weap_ammo_dict[current_weapon]
	if ammo_data["current"] >= ammo_data["max"]:
		print("Shotgun is already full. No reload needed.")
		return

	is_reloading = true

	# Create or re-use a reload_timer
	if reload_timer == null:
		reload_timer = Timer.new()
		reload_timer.one_shot = true
		add_child(reload_timer)

		# Connect once to a shell-loaded function
		if not reload_timer.timeout.is_connected(Callable(self, "_on_shotgun_shell_loaded")):
			reload_timer.timeout.connect(Callable(self, "_on_shotgun_shell_loaded"))
	else:
		reload_timer.stop()

	# Calculate shell time based on sanity
	var fraction = get_sanity_fraction()
	var final_shell_time = base_shell_time * lerp(2.0, 1.0, fraction)

	reload_timer.wait_time = final_shell_time
	reload_timer.start()

	print("Starting shotgun reload. Time per shell:", final_shell_time)
	
func _on_shotgun_shell_loaded() -> void:
	var weap_ammo_dict = GameStateManager.get_weapon_ammo()
	var ammo_data = weap_ammo_dict[current_weapon]
	ammo_data["current"] += 1
	print("Shotgun loaded 1 shell. Current ammo:", ammo_data["current"])

	# If still not full, restart the timer for next shell
	if ammo_data["current"] < ammo_data["max"]:
		var fraction = get_sanity_fraction()
		var final_shell_time = base_shell_time * lerp(2.0, 1.0, fraction)
		reload_timer.wait_time = final_shell_time
		reload_timer.start()
		print("Reloading next shell. Time = ", final_shell_time)
	else:
		# Done loading
		is_reloading = false
		reload_timer.stop()
		reload_timer.queue_free()
		reload_timer = null
		print("Shotgun fully reloaded.")

	
func fire_sfx() -> void:
	match current_weapon:
		"handgun":
			AudioManager.play_sfx("handgun_shot")
		"rifle":
			AudioManager.play_sfx_varied("rifle_shot", 0.0, false, 0.9, 1.1)
			await get_tree().create_timer(fire_rate).timeout  # Sync sound to fire rate
		"shotgun":
			AudioManager.play_sfx("shotgun_shot")
		_:
			AudioManager.play_sfx("gunshot_1")


func _show_muzzle_flash(weapon_name: String) -> void:
	# Reset all muzzle flashes
	muzzle_handgun.visible = false
	muzzle_rifle.visible = false
	muzzle_shotgun.visible = false

	match weapon_name:
		"handgun":
			muzzle_handgun.visible = true
			await get_tree().create_timer(fire_rate * 0.5).timeout
			muzzle_handgun.visible = false

		"rifle":
			muzzle_rifle.visible = true
			muzzle_rifle.play("flash")
			await get_tree().create_timer(fire_rate).timeout  # Keep flash visible for the fire rate duration
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
