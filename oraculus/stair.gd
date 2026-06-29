extends Node2D

@export var climb_speed: float = 100.0
@export var use_path_direction: bool = true
# Imposta a 1 o 2 nell'Inspector per assegnare la scala a un layer specifico.
# Il player sale solo le scale il cui stair_layer corrisponde al suo current_stair_layer.
@export var stair_layer: int = 1

var direction: Vector2 = Vector2(1, -1).normalized()

func _ready():
	if use_path_direction and $Path2D.curve.get_point_count() >= 2:
		var start = $Path2D.to_global($Path2D.curve.get_point_position(0))
		var end = $Path2D.to_global($Path2D.curve.get_point_position(1))
		direction = (end - start).normalized()
