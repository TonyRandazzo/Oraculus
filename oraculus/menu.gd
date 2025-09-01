extends Control

@onready var question_text_edit = $Title/Questions
@onready var answer_text_edit = $Title/Answer
@onready var npc_ai = $Title/Player2AINPC

func _ready():
	# AI signal connections
	npc_ai.chat_received.connect(_on_chat_received)
	npc_ai.chat_failed.connect(_on_chat_failed)
	
	# Character configuration
	npc_ai._selected_character = {
		"name": "Oracle",
		"description": "An oracle that clearly and concisely explains the game rules to you. There are various enemies that are aggressive and/or diplomatic, and you can talk to them or kill them. They give you information if you talk to them. The objective is to find the exit door and win. You move with the PC arrow keys or joystick, attack with E or Y on the joystick, interact with A, and exit the interaction with B or with '\\'",
		"voice_ids": ["demon_voice"]
	}
	npc_ai.use_player2_selected_character = true
	npc_ai.tts_enabled = false
	
	# Initial focus on text edit
	question_text_edit.grab_focus()

func _input(event):
	# Submit with Enter (KEY_ENTER for numpad, KEY_KP_ENTER for main enter)
	if event is InputEventKey and event.pressed:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and question_text_edit.has_focus():
			_send_question()

func _send_question():
	var question = question_text_edit.text.strip_edges()
	if question == "":
		return
	
	answer_text_edit.text = "The Oracle is thinking..."
	question_text_edit.editable = false  # Disable input during wait
	
	# Send question to AI
	npc_ai.notify(question)

func _on_chat_received(response: String):
	answer_text_edit.text = response
	question_text_edit.editable = true
	question_text_edit.text = ""  # Clear the question
	question_text_edit.grab_focus()  # Return focus

func _on_chat_failed(error_code: int):
	answer_text_edit.text = "The Oracle is too busy to respond now. (Error: %d)" % error_code
	question_text_edit.editable = true
	question_text_edit.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://oraculus/main.tscn")

func _on_options_pressed() -> void:
	$Title/Options2.visible = true
	get_tree().paused = true
