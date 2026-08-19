extends Control

var item_name = "no item"
var item_description = "there are no item in your inventory"



func _on_interact_pressed() -> void:
	$"../..".open_chat()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("item"):
		$Inventory.visible = !$Inventory.visible
		$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item1.texture_normal
		item_name = $Inventory/Buttons/Item1.item_name
		item_description = $Inventory/Buttons/Item1.item_description
	if $Inventory/Buttons/SelectedItem.texture_normal != null:
		$Inventory/ItemName.text = item_name
		$Inventory/ItemDescription.text = item_description
	else:
		item_name = "no item"
		item_description = "there are no item in your inventory"
		$Inventory/ItemName.text = item_name
		$Inventory/ItemDescription.text = item_description



func _on_item_1_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item1.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item1.texture_normal
	item_name = $Inventory/Buttons/Item1.item_name
	item_description = $Inventory/Buttons/Item1.item_description



func _on_item_2_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item2.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item2.texture_normal
	item_name = $Inventory/Buttons/Item2.item_name
	item_description = $Inventory/Buttons/Item2.item_description

func _on_item_3_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item3.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item3.texture_normal
	item_name = $Inventory/Buttons/Item3.item_name
	item_description = $Inventory/Buttons/Item3.item_description

func _on_item_4_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item4.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item4.texture_normal
	item_name = $Inventory/Buttons/Item4.item_name
	item_description = $Inventory/Buttons/Item4.item_description

func _on_item_5_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item5.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item5.texture_normal
	item_name = $Inventory/Buttons/Item5.item_name
	item_description = $Inventory/Buttons/Item5.item_description

func _on_item_6_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item6.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item6.texture_normal
	item_name = $Inventory/Buttons/Item6.item_name
	item_description = $Inventory/Buttons/Item6.item_description

func _on_item_7_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item7.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item7.texture_normal
	item_name = $Inventory/Buttons/Item7.item_name
	item_description = $Inventory/Buttons/Item7.item_description

func _on_item_8_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture_normal = $Inventory/Buttons/Item8.texture_normal
	$Inventory/Buttons/SelectedItem.texture_pressed = $Inventory/Buttons/Item8.texture_normal
	item_name = $Inventory/Buttons/Item8.item_name
	item_description = $Inventory/Buttons/Item8.item_description


func _try_use_door_scroll() -> bool:
	var player = $"../.."
	var door = player.current_demon
	if door == null or not door.has_method("unlock_with_scroll"):
		return false

	for slot in $Inventory/Buttons.get_children():
		if slot.name == "SelectedItem":
			continue
		if slot.is_in_group("door scroll"):
			if door.unlock_with_scroll():
				slot.remove_from_group("door scroll")
				slot.texture_normal = null
				slot.texture_pressed = null
				slot.item_name = "no item"
				slot.item_description = "there are no item in your inventory"
				$Inventory/Buttons/SelectedItem.texture_normal = null
				$Inventory/Buttons/SelectedItem.texture_pressed = null
			return true
	return false

func _on_selected_item_pressed() -> void:
	if _try_use_door_scroll():
		return
	if $Inventory/Buttons/Item1.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item1.remove_from_group("life potion")
		$Inventory/Buttons/Item1.texture_normal = null
		$Inventory/Buttons/Item1.texture_pressed = null
		$Inventory/Buttons/Item1.item_name = "no item"
		$Inventory/Buttons/Item1.item_description = "there are no item in your inventory"
		return
	if $Inventory/Buttons/Item1.is_in_group("defense potion"):
		$"../..".defense_potion_active = true
		$"../..".defense_potion_timer.start(15.0)
		print("Timer exists: ", $"../..".defense_potion_timer != null)
		$"../../VFX2".play("defense")
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item1.remove_from_group("defense potion")
		$Inventory/Buttons/Item1.texture_normal = null
		$Inventory/Buttons/Item1.texture_pressed = null
		$Inventory/Buttons/Item1.item_name = "no item"
		$Inventory/Buttons/Item1.item_description = "there are no item in your inventory"
		return

	if $Inventory/Buttons/Item2.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item2.texture_normal = null
		$Inventory/Buttons/Item2.texture_pressed = null
		$Inventory/Buttons/Item2.remove_from_group("life potion")
		$Inventory/Buttons/Item2.item_name = "no item"
		$Inventory/Buttons/Item2.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item3.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item3.texture_normal = null
		$Inventory/Buttons/Item3.texture_pressed = null
		$Inventory/Buttons/Item3.remove_from_group("life potion")
		$Inventory/Buttons/Item3.item_name = "no item"
		$Inventory/Buttons/Item3.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item4.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item4.texture_normal = null
		$Inventory/Buttons/Item4.texture_pressed = null
		$Inventory/Buttons/Item4.remove_from_group("life potion")
		$Inventory/Buttons/Item4.item_name = "no item"
		$Inventory/Buttons/Item4.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item5.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item5.texture_normal = null
		$Inventory/Buttons/Item5.texture_pressed = null
		$Inventory/Buttons/Item5.remove_from_group("life potion")
		$Inventory/Buttons/Item5.item_name = "no item"
		$Inventory/Buttons/Item5.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item6.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item6.texture_normal = null
		$Inventory/Buttons/Item6.texture_pressed = null
		$Inventory/Buttons/Item6.remove_from_group("life potion")
		$Inventory/Buttons/Item6.item_name = "no item"
		$Inventory/Buttons/Item6.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item7.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item7.texture_normal = null
		$Inventory/Buttons/Item7.texture_pressed = null
		$Inventory/Buttons/Item7.remove_from_group("life potion")
		$Inventory/Buttons/Item7.item_name = "no item"
		$Inventory/Buttons/Item7.item_description = "there are no item in your inventory"
		return


	if $Inventory/Buttons/Item8.is_in_group("life potion") and $"../..".current_health < $"../..".max_health:
		$"../..".current_health = $"../..".max_health
		$"../..".update_health()
		$Inventory/Buttons/SelectedItem.texture_normal = null
		$Inventory/Buttons/SelectedItem.texture_pressed = null
		$Inventory/Buttons/Item8.texture_normal = null
		$Inventory/Buttons/Item8.texture_pressed = null
		$Inventory/Buttons/Item8.remove_from_group("life potion")
		$Inventory/Buttons/Item8.item_name = "no item"
		$Inventory/Buttons/Item8.item_description = "there are no item in your inventory"
		return
