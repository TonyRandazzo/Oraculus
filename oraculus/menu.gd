extends Control

@onready var question_text_edit = $Label
@onready var answer_text_edit = $Dialogue

var npc_name: String = "Tutorial"
var max_tokens: int = 25
var temperature: float = 0.7
var _server_ready: bool = false
var _using_remote: bool = false
var is_waiting_for_response: bool = false
var conversation_history: Array = []
var _ai_thread: Thread = null
var _ai_thread_done: bool = false
var _ai_thread_result: String = ""
var _player_input_buffer: String = ""
var _thinking_timer: Timer
var _dot_count: int = 0

func _ready() -> void:
	if question_text_edit is LineEdit:
		question_text_edit.text_submitted.connect(_on_text_submitted)
	else:
		question_text_edit.gui_input.connect(_on_question_gui_input)
		question_text_edit.focus_exited.connect(_on_focus_exited)
	_thinking_timer = Timer.new()
	_thinking_timer.wait_time = 0.5
	_thinking_timer.one_shot = false
	_thinking_timer.timeout.connect(_cycle_thinking_dots)
	add_child(_thinking_timer)
	answer_text_edit.text = "Ask me anything..."
	var server_manager = get_node_or_null("/root/AIServerManager")
	if not server_manager:
		answer_text_edit.text = "Server AI not available."
		return
	if not server_manager.server_started.is_connected(_on_server_started):
		server_manager.server_started.connect(_on_server_started)
	if not server_manager.server_failed.is_connected(_on_server_failed):
		server_manager.server_failed.connect(_on_server_failed)
	if server_manager.is_server_ready():
		_on_server_started()

func _on_question_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		question_text_edit.accept_event()
		_process_player_input(question_text_edit.text)

func _on_server_started() -> void:
	_server_ready = true
	_using_remote = get_node("/root/AIServerManager").is_using_remote()
	if answer_text_edit.text == "Ask me anything...":
		pass

func _on_server_failed(error_message: String) -> void:
	_server_ready = false
	answer_text_edit.text = "Server AI not available: " + error_message

func _on_text_submitted(text: String) -> void:
	_process_player_input(text)

func _on_text_changed(text: String) -> void:
	pass

func _on_focus_exited() -> void:
	if question_text_edit.text.strip_edges() != "":
		_process_player_input(question_text_edit.text)

func _process_player_input(text: String) -> void:
	if is_waiting_for_response or not _server_ready:
		return
	_player_input_buffer = text
	question_text_edit.text = ""
	_send_ai_request(text, "inglese")

func _send_ai_request(player_message: String, language: String = "inglese") -> void:
	if not _server_ready:
		_use_fallback_response("Server not available.")
		return
	is_waiting_for_response = true
	_start_thinking_dots()
	var server_manager = get_node("/root/AIServerManager")
	if server_manager.is_using_remote():
		_do_remote_request(player_message, language)
	else:
		_do_local_request(player_message, language)

func _do_remote_request(player_message: String, language: String) -> void:
	var server_manager = get_node("/root/AIServerManager")
	var payload = {
		"npc_name": npc_name,
		"player_input": player_message,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"conversation_history": conversation_history,
		"language": language
	}
	var response = await server_manager.make_request("chat", payload)
	_stop_thinking_dots()
	is_waiting_for_response = false
	if response == null or response.has("error"):
		_use_fallback_response("Connection lost...")
		return
	var ai_message = response.get("response", "")
	_on_ai_response_received(ai_message)

func _do_local_request(player_message: String, language: String) -> void:
	var server_manager = get_node("/root/AIServerManager")
	_ai_thread_done = false
	_ai_thread_result = ""
	_ai_thread = Thread.new()
	_ai_thread.start(_thread_request.bind(player_message, language, server_manager))

func _thread_request(player_message: String, language: String, server_manager: Node) -> void:
	var payload = {
		"npc_name": npc_name,
		"player_input": player_message,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"conversation_history": conversation_history,
		"language": language
	}
	var response = server_manager.make_request_sync("chat", payload)
	if response.has("error"):
		_ai_thread_result = ""
	else:
		_ai_thread_result = response.get("response", "")
	_ai_thread_done = true

func _process(_delta: float) -> void:
	if _ai_thread != null and _ai_thread_done:
		_ai_thread.wait_to_finish()
		_ai_thread = null
		_ai_thread_done = false
		_stop_thinking_dots()
		is_waiting_for_response = false
		if _ai_thread_result != "":
			_on_ai_response_received(_ai_thread_result)
		else:
			_use_fallback_response("Local server did not respond.")

func _on_ai_response_received(message: String) -> void:
	if conversation_history.size() >= 10:
		conversation_history.pop_front()
	conversation_history.append({"player": _player_input_buffer, "npc": message})
	answer_text_edit.text = message

func _use_fallback_response(text: String) -> void:
	_stop_thinking_dots()
	is_waiting_for_response = false
	answer_text_edit.text = text

func _start_thinking_dots() -> void:
	_dot_count = 0
	answer_text_edit.text = "."
	_thinking_timer.start()

func _cycle_thinking_dots() -> void:
	if not is_waiting_for_response:
		_thinking_timer.stop()
		return
	_dot_count = (_dot_count + 1) % 4
	if _dot_count == 0:
		answer_text_edit.text = "..."
	else:
		answer_text_edit.text = ".".repeat(_dot_count) + "."

func _stop_thinking_dots() -> void:
	_thinking_timer.stop()
	if answer_text_edit.text in [".", "..", "..."]:
		answer_text_edit.text = "Ask me anything..."

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://oraculus/main.tscn")

func _on_options_pressed() -> void:
	$Title/Options2.visible = true
	get_tree().paused = true
