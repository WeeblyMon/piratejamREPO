extends Node2D

@export var health: int = 10
@export var detection_radius: float = 300.0  # Currently unused
@export var random_walk_radius: float = 200.0
@export var walk_speed: float = 100.0
@export var panic_speed_multiplier: float = 2.0  # Speed multiplier when in panic mode
@export var panic_duration: float = 3.0  # How long panic mode lasts in panic mode

@onready var sprite: Sprite2D = $Sprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var target_position: Vector2 = Vector2.ZERO
var is_panicking: bool = false
var panic_timer: Timer = null

func _ready() -> void:
	add_to_group("civilian")
	GameStateManager.connect("wielder_phase_changed", Callable(self, "_on_wielder_phase_changed"))
	_pick_random_destination()
	set_process(true)

func _process(delta: float) -> void:
	if is_panicking:
		_random_walk(delta, walk_speed * panic_speed_multiplier)
	else:
		_random_walk(delta, walk_speed)

# -------------------------------------
# Damage & Death
# -------------------------------------
func take_damage(damage: int) -> void:
	health -= damage
	sprite.modulate = Color(1, 0, 0)
	flash_color()
	if health <= 0:
		die()
		GameStateManager.set_sanity(1, "sub")

func flash_color() -> void:
	var flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1
	add_child(flash_timer)
	flash_timer.start()
	AudioManager.play_sfx_varied("grunt_2", -0.5, false, 0.9, 1.1)
	await flash_timer.timeout
	sprite.modulate = Color(1, 1, 1)
	flash_timer.queue_free()
	AudioManager.play_sfx_varied("enemy_hit_1", false)

func die() -> void:
	GameStateManager.set_sanity(14, "sub")
	queue_free()

# -------------------------------------
# Random Walk
# -------------------------------------
func _pick_random_destination() -> void:
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_dist = randf_range(0, random_walk_radius)
	target_position = global_position + random_dir * random_dist
	navigation_agent.set_target_position(target_position)

func _random_walk(delta: float, speed: float) -> void:
	if global_position.distance_to(target_position) < 10.0:
		_pick_random_destination()

	if navigation_agent.is_navigation_finished():
		return

	var next_pos = navigation_agent.get_next_path_position()
	if next_pos == Vector2.ZERO:
		return

	var direction = (next_pos - global_position).normalized()
	if direction.length() > 0.01:
		position += direction * speed * delta
		rotation = direction.angle()

# -------------------------------------
# Panic Mode
# -------------------------------------
func _start_panic() -> void:
	if not is_panicking:
		is_panicking = true
		print("Entering panic mode!")
		if not panic_timer:
			panic_timer = Timer.new()
			panic_timer.one_shot = true
			panic_timer.wait_time = panic_duration
			add_child(panic_timer)
			panic_timer.start()
			panic_timer.timeout.connect(_stop_panic)

func _stop_panic() -> void:
	is_panicking = false
	print("Exiting panic mode.")
	if panic_timer:
		panic_timer.queue_free()
		panic_timer = null

# -------------------------------------
# Phase Change Handling
# -------------------------------------
func _on_wielder_phase_changed(new_phase: int) -> void:
	if new_phase == GameStateManager.WielderPhase.COMBAT:
		_start_panic()
