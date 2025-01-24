extends Control
class_name AmmoCounter

# Define references to current ammo and max ammo text
@onready var ammo_text1: Label = $AmmoText  # Label for current ammo
@onready var ammo_text2: Label = $AmmoText2  # Label for max ammo

func _ready() -> void:
	# Initialize display
	update_ammo_display()

	GameStateManager.connect("ammo_changed", Callable(self, "_on_ammo_changed"))

# Called when ammo changes
func _on_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	ammo_text1.text = str(current_ammo)
	ammo_text2.text = str(max_ammo)

func update_ammo_display() -> void:
	var current_weapon = GameStateManager.get_weapon()
	var weapon_ammo = GameStateManager.get_weapon_ammo()

	if weapon_ammo.has(current_weapon):
		var current = weapon_ammo[current_weapon]["current"]
		var max = weapon_ammo[current_weapon]["max"]
		ammo_text1.text = str(current)
		ammo_text2.text = str(max)
	else:
		ammo_text1.text = "0"
		ammo_text2.text = "0"
