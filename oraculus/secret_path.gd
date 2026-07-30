extends Node2D




func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("overlap_player"):
		if $"../Player".crouching:
			$"../Player".global_position = Vector2(-445, -12)
