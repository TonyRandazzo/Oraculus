extends Node2D

enum DoorMode { RIDDLE, MINIGAME }

@export var door_mode: DoorMode = DoorMode.RIDDLE
@export var door_id: String = "door_default"
@export var riddle_theme: String = ""
@export var minigame_child_index: int = -1

@onready var instructions = $Instractions
@onready var detection_area: Area2D = $Area2D

var door_unlocked: bool = false
var player_in_range: bool = false
var current_riddle_text: String = ""
var current_riddle_answer: String = ""
var riddle_loading: bool = false

func _ready() -> void:
	detection_area.connect("area_exited", _on_area_2d_area_exited)
	instructions.hide_dialogue()

	if door_mode == DoorMode.MINIGAME:
		detection_area.remove_from_group("demon_detection")

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not _is_player_area(area):
		return

	player_in_range = true

	match door_mode:
		DoorMode.RIDDLE:
			if not current_riddle_text.is_empty():
				instructions.show_text(current_riddle_text)
			elif not riddle_loading:
				_request_riddle()
		DoorMode.MINIGAME:
			instructions.show_text("Press [interact] to begin the challenge!")

func _on_area_2d_area_exited(area: Area2D) -> void:
	if not _is_player_area(area):
		return
	player_in_range = false
	instructions.hide_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if door_mode == DoorMode.MINIGAME and player_in_range and event.is_action_pressed("interact"):
		_activate_minigame()
		get_viewport().set_input_as_handled()

func receive_player_answer(answer: String) -> void:
	if door_unlocked or door_mode == DoorMode.MINIGAME or current_riddle_answer.is_empty():
		return

	var player_answer := answer.to_lower().strip_edges()
	var expected := current_riddle_answer.to_lower().strip_edges()

	if expected in player_answer:
		_unlock_door()
		instructions.show_text("Correct! The way is open...")
	else:
		instructions.show_text("Wrong... think again.\n\n" + current_riddle_text)

func _request_riddle() -> void:
	riddle_loading = true
	instructions.show_text("...")

	var server := get_node_or_null("/root/AIServerManager")
	if server == null or not server.is_server_ready():
		_use_fallback_riddle()
		return

	var result = await server.make_request("riddle", {
		"door_id":  door_id,
		"language": "inglese",
		"theme":    riddle_theme,
	})

	if not is_instance_valid(self):
		return

	riddle_loading = false

	if result == null or result.has("error"):
		_use_fallback_riddle()
		return

	current_riddle_text   = result.get("riddle", "")
	current_riddle_answer = result.get("answer", "")

	if current_riddle_text.is_empty():
		_use_fallback_riddle()
		return

	if player_in_range:
		instructions.show_text(current_riddle_text)

func _use_fallback_riddle() -> void:
	current_riddle_text   = "I am cast by all who stand in the light,\nyet I myself have no substance.\nWhat am I?"
	current_riddle_answer = "shadow"
	if player_in_range:
		instructions.show_text(current_riddle_text)

func _unlock_door() -> void:
	door_unlocked = true
	$StaticBody2D/CollisionShape2D.disabled = true
	modulate.a = 0.0

func _activate_minigame() -> void:
	var main := get_tree().current_scene
	var minigame_node := main.get_node_or_null("Minigame")
	if minigame_node == null:
		push_error("Door '%s': node 'Minigame' not found in the main scene." % door_id)
		return

	var children := minigame_node.get_children()
	if children.is_empty():
		push_error("Door '%s': Minigame node has no children." % door_id)
		return

	for child in children:
		child.visible = false

	var target_index := minigame_child_index
	if target_index < 0 or target_index >= children.size():
		target_index = randi() % children.size()

	children[target_index].visible = true

func _is_player_area(area: Area2D) -> bool:
	if area.is_in_group("player"):
		return true
	var parent := area.get_parent()
	return parent != null and (parent.name == "Player" or parent.is_in_group("player"))
