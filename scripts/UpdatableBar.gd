class_name UpdatableBar extends ProgressBar

func update_bar(operation, value) -> void:
	if operation == Constants.OPERATIONS.ADD:
		increment_bar(value)
	else:
		decrement_bar(value)

func increment_bar(updated_value: int) -> void:
	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(self, "value", value + updated_value, .5)

func decrement_bar(updated_value) -> void:
	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(self, "value", value - updated_value, .5)
