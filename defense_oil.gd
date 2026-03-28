extends Node2D

var item_name = "Defense Oil"
var item_description = "this oil gives a boost to your defence"


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("overlap_player"):
		
		var buttons = $"../Player/CanvasLayer/HUD/Inventory/Buttons"
		var new_texture = $Area2D/Sprite2D.texture
		
		for child in buttons.get_children():
			if child.texture_normal == null and child.texture_pressed == null:
				child.texture_normal = new_texture
				child.texture_pressed = new_texture
				child.item_name = item_name
				child.item_description = item_description
				child.add_to_group("defense potion")
				queue_free()
				return
