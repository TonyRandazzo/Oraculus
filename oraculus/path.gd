extends Node2D

@export var spawn_node_name: String = "Spawn"
@export var player_group: String = "overlap_player"



func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group(player_group):
		var spawn_node = get_node(spawn_node_name)
		if spawn_node:
			$"../../Player".global_position = spawn_node.global_position
			$"../../Player".current_stair_layer = 0
		else:
			push_error("Nodo spawn '%s' non trovato in %s" % [spawn_node_name, name])
