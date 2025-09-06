extends Area2D
var enter: bool


func _physics_process(delta: float) -> void:
	pass

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("music_player"):
		$"../../Player/Camera2D".zoom = Vector2(2, 2)
		
