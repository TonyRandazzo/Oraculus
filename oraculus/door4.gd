extends Node2D

@onready var instructions = $Instractions
@onready var npc_ai: Player2AINPC = $Player2AINPC
@onready var detection_area: Area2D = $Area2D

var thinking_timer: Timer
var generation_timeout: Timer
var thinking_dots: int = 0
var instructions_generated: bool = false
var current_instructions: String = ""
var is_thinking: bool = false
var possible_answers = ["Sun", "Heart", "Love"]
var correct_answer: String = ""

func _ready():
	if not instructions:
		push_error("CRITICAL ERROR: Instructions not found! Ensure path is correct.")
		return
	
	if not npc_ai:
		push_error("CRITICAL ERROR: Player2AINPC not found! Ensure path is correct.")
		return
	
	# Choose random correct answer
	correct_answer = possible_answers[randi() % possible_answers.size()]
	
	# Configure AI
	setup_ai_profile()
	
	generation_timeout = Timer.new()
	generation_timeout.name = "GenerationTimeout"
	add_child(generation_timeout)
	generation_timeout.one_shot = true
	generation_timeout.timeout.connect(_on_generation_timeout)
	
	# Add detection area to group
	detection_area.add_to_group("demon_detection")

func setup_ai_profile():
	npc_ai._selected_character = {
		"name": "Enigmatic Voice",
		"description": "A mysterious entity that proposes riddles",
		"voice_ids": ["male"]
	}
	npc_ai.use_player2_selected_character = false
	npc_ai.tts_enabled = false
	npc_ai.auto_store_conversation_history = true

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not instructions_generated:
		generate_riddle()
	else:
		instructions.show_text(current_instructions)

func generate_riddle():
	if is_thinking or not is_instance_valid(npc_ai):
		return
	
	instructions_generated = true
	is_thinking = true
	
	_show_thinking_indicator()
	
	if is_instance_valid(generation_timeout):
		generation_timeout.start(15.0)
	
	# AI configuration for riddle generation
	npc_ai.system_message = """You are a mysterious entity that proposes riddles. 
Create a difficult but clear riddle with the exact answer: %s.
The riddle must:
1. Rhyme
2. Never directly mention the answer
3. Have an ancient and mysterious tone

Required format:
[Hidden answer: %s]""" % [correct_answer, correct_answer]
	
	var request_data = {
		"action": "generate_riddle",
		"requirements": {
			"answer": correct_answer,
			"style": "rhyming",
			"length": "4+ lines"
		},
		"stimuli": "Create a riddle with answer " + correct_answer
	}
	
	# Safely disconnect existing connections
	if npc_ai.chat_received.is_connected(_on_instructions_received):
		npc_ai.chat_received.disconnect(_on_instructions_received)
	if npc_ai.chat_failed.is_connected(_on_instructions_failed):
		npc_ai.chat_failed.disconnect(_on_instructions_failed)
	
	# Connect new signals
	var connect_err = npc_ai.chat_received.connect(_on_instructions_received, CONNECT_ONE_SHOT)
	if connect_err != OK:
		push_error("Failed to connect chat_received signal")
		_on_instructions_failed(-1)
		return
	
	connect_err = npc_ai.chat_failed.connect(_on_instructions_failed, CONNECT_ONE_SHOT)
	if connect_err != OK:
		push_error("Failed to connect chat_failed signal")
		_on_instructions_failed(-1)
		return
	
	npc_ai.notify(JSON.stringify(request_data))

func _stop_thinking_indicator():
	is_thinking = false
	
	if is_instance_valid(thinking_timer):
		thinking_timer.stop()
		thinking_timer.queue_free()
		thinking_timer = null
	
	if is_instance_valid(generation_timeout):
		generation_timeout.stop()

func _show_thinking_indicator():
	thinking_dots = 0
	
	if not is_instance_valid(instructions):
		push_error("ERROR: Instructions not valid during thinking indicator!")
		return
	
	instructions.show_text("The entity is formulating the riddle...")
	
	if thinking_timer and is_instance_valid(thinking_timer):
		thinking_timer.queue_free()
	
	thinking_timer = Timer.new()
	thinking_timer.name = "ThinkingTimer"
	add_child(thinking_timer)
	thinking_timer.wait_time = 0.5
	thinking_timer.timeout.connect(_update_thinking_animation)
	thinking_timer.start()

func _update_thinking_animation():
	if not is_instance_valid(instructions) or not is_thinking:
		return
	
	thinking_dots = (thinking_dots + 1) % 4
	var dots = ".".repeat(thinking_dots)
	instructions.show_text("The entity is formulating the riddle" + dots)

func _on_instructions_received(message: String):
	_stop_thinking_indicator()
	
	if not is_instance_valid(instructions):
		push_error("ERROR: Instructions not valid!")
		return
	
	current_instructions = _clean_riddle_response(message)
	instructions.show_text(current_instructions)
	
	print("Riddle received: ", current_instructions)
	print("Correct answer: ", correct_answer)

func _clean_riddle_response(message: String) -> String:
	# Remove hidden answer if present
	var clean_message = message.replace("[Hidden answer: %s]" % correct_answer, "")
	clean_message = clean_message.strip_edges()
	
	# Keep only the part before additional notes
	var lines = clean_message.split("\n")
	var riddle_lines = []
	
	for line in lines:
		if line.strip_edges().begins_with("1.") or "Answer:" in line:
			break
		if line.strip_edges().length() > 0:
			riddle_lines.append(line)
	
	return "\n".join(riddle_lines)

func _on_generation_timeout():
	if current_instructions.is_empty():
		_on_instructions_failed(-1)

func _on_instructions_failed(error_code: int):
	_stop_thinking_indicator()
	
	if not is_instance_valid(instructions):
		push_error("ERROR: Instructions not valid during fallback!")
		return
	


func receive_player_answer(answer: String):
	# Convert to lowercase for case-insensitive comparison
	var player_answer = answer.to_lower().strip_edges()
	var expected_answer = correct_answer.to_lower().strip_edges()
	
	# Check if answer contains correct word (even as part of phrase)
	if expected_answer in player_answer:
		# Correct answer
		if has_node("AnimationPlayer"):
			$AnimationPlayer.play("exit")
		# Optional: confirmation message
		if is_instance_valid(instructions):
			instructions.show_text("Correct! The riddle is solved...")
			$StaticBody2D/CollisionShape2D.disabled = true
			modulate.a -= 1
	else:
		# Wrong answer
		if is_instance_valid(instructions):
			instructions.show_text("Wrong! Try again...")
		
		# Optional: regenerate riddle after error
		# instructions_generated = false
		# generate_riddle()
