extends Control

@onready var question_text_edit = $Title/Questions
@onready var answer_text_edit = $Title/Answer
@onready var npc_ai = $Title/Player2AINPC

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://oraculus/main.tscn")

func _on_options_pressed() -> void:
	$Title/Options2.visible = true
	get_tree().paused = true
