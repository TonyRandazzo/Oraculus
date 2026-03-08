extends Control

var item_name = "no item"
var item_description = "there are no item in your inventory"



func _on_interact_pressed() -> void:
	if $"../..".can_interact and$"../..".current_demon:
		$"../..".hud_label.editable = true
		$"../..".hud.show()
		$"../..".hud_label.grab_focus()
		return


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("item"):
		$Inventory.visible = !$Inventory.visible
		$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item1.texture_normal
		item_name = $Inventory/Buttons/Item1.item_name
		item_description = $Inventory/Buttons/Item1.item_description
	if $Inventory/Buttons/SelectedItem.texture != null:
		$Inventory/ItemName.text = item_name
		$Inventory/ItemDescription.text = item_description


func _on_item_1_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item1.texture_normal
	item_name = $Inventory/Buttons/Item1.item_name
	item_description = $Inventory/Buttons/Item1.item_description

func _on_item_2_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item2.texture_normal
	item_name = $Inventory/Buttons/Item2.item_name
	item_description = $Inventory/Buttons/Item2.item_description

func _on_item_3_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item3.texture_normal
	item_name = $Inventory/Buttons/Item3.item_name
	item_description = $Inventory/Buttons/Item3.item_description

func _on_item_4_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item4.texture_normal
	item_name = $Inventory/Buttons/Item4.item_name
	item_description = $Inventory/Buttons/Item4.item_description

func _on_item_5_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item5.texture_normal
	item_name = $Inventory/Buttons/Item5.item_name
	item_description = $Inventory/Buttons/Item5.item_description

func _on_item_6_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item6.texture_normal
	item_name = $Inventory/Buttons/Item6.item_name
	item_description = $Inventory/Buttons/Item6.item_description

func _on_item_7_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item7.texture_normal
	item_name = $Inventory/Buttons/Item7.item_name
	item_description = $Inventory/Buttons/Item7.item_description

func _on_item_8_pressed() -> void:
	$Inventory/Buttons/SelectedItem.texture = $Inventory/Buttons/Item8.texture_normal
	item_name = $Inventory/Buttons/Item8.item_name
	item_description = $Inventory/Buttons/Item8.item_description
