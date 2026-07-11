extends Node2D

@export var spawn_node_name: String = "Spawn"
@export var player_group: String = "overlap_player"
@export var stair_layer_on_respawn: int = 0  
@export var z_index_on_respawn: int = 0        

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group(player_group):
		var spawn_node = get_node(spawn_node_name)
		if spawn_node:
			var player = $"../../Player"
			player.global_position = spawn_node.global_position
			player.current_stair_layer = stair_layer_on_respawn
			player.z_index = z_index_on_respawn  
		else:
			push_error("Nodo spawn '%s' non trovato in %s" % [spawn_node_name, name])
