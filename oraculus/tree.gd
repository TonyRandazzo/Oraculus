extends Sprite2D

@export var input_field: TextEdit
@export var output_label: Label
@export var npc_name: String = "Tutorial"
@export var max_tokens: int = 50
@export var temperature: float = 0.7
@export var max_history: int = 10

@export var system_prompt: String = """
CRITICAL INSTRUCTION: You MUST respond ONLY in English. Under NO circumstances use Italian, Spanish, French, or any language other than English.
Your name is {npc_name}, a friendly and helpful assistant who teaches new players how to play the game.
- Keep a welcoming and encouraging tone.
- Do not reveal specific story details or spoilers.
- Be vague and mysterious about lore, but precise about game commands.

GAME COMMANDS:
- Movement: Use arrow keys/WASD on keyboard or controller. LT on controller or SHIFT on keyboard to sprint. SpaceBar or A to jump. You can also slide by pressing the forward movement key twice quickly.
- Inventory: Press 1 on keyboard or SELECT on controller to open the inventory. Pick an item with the mouse and use it by clicking on it in the center.
- Talk: Press the on-screen button below the HP bar or \\ on the keyboard, type your phrase, and send it with ENTER.
- Attack: Press E on keyboard or Y on controller.
- Defense: You can parry using Q on keyboard or X on controller.

It is important that the player talks to NPCs to progress in the game.
You have complete freedom in how you respond, as long as you remain friendly and helpful.

REMEMBER: Your response MUST be in English. English only. No Italian.
"""

var conversation_history: Array = []
var is_waiting_for_response: bool = false
var _server_ready: bool = false
var _thinking_tween: Tween = null
var _ai_thread: Thread = null
var _ai_thread_result: String = ""
var _ai_thread_done: bool = false
var _server_manager: Node = null

func _ready():
	_server_manager = get_node_or_null("/root/AIServerManager")
	if not _server_manager:
		push_error("AIServerManager not found!")
		return
	if not _server_manager.server_started.is_connected(_on_server_started):
		_server_manager.server_started.connect(_on_server_started)
	if not _server_manager.server_failed.is_connected(_on_server_failed):
		_server_manager.server_failed.connect(_on_server_failed)
	if _server_manager.is_server_ready():
		_on_server_started()
	else:
		_server_ready = false
	if input_field:
		input_field.gui_input.connect(_on_input_gui_input)
	await get_tree().create_timer(0.5).timeout
	if _server_ready:
		_send_to_ai_server("Greet the player with a short welcome message. You are a helpful and friendly assistant.")

func _on_input_gui_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
		_on_player_message_sent(input_field.text)

func _on_server_started():
	_server_ready = true

func _on_server_failed(error_message: String):
	_server_ready = false
	output_label.text = "Connection error to AI server."

func _on_player_message_sent(player_message: String):
	if player_message.strip_edges() == "":
		return
	if is_waiting_for_response:
		output_label.text = "Please wait for the AI to respond..."
		return
	input_field.text = ""
	input_field.editable = false
	if conversation_history.size() >= max_history:
		conversation_history.pop_front()
	conversation_history.append({"player": player_message, "npc": ""})
	_send_to_ai_server(player_message)

func _get_system_prompt() -> String:
	return system_prompt.replace("{npc_name}", npc_name)

func _send_to_ai_server(player_message: String):
	if not _server_ready:
		_use_fallback("AI server is not available. Please try again later.")
		return
	if is_waiting_for_response or (_ai_thread != null and _ai_thread.is_alive()):
		return
	is_waiting_for_response = true
	_start_thinking_dots()
	var payload = {
		"npc_name": npc_name,
		"player_input": player_message,
		"language": "english",
		"lang": "en",           # extra param if server supports it
		"max_tokens": max_tokens,
		"temperature": temperature,
		"conversation_history": conversation_history,
		"system_prompt": _get_system_prompt()
	}
	if _server_manager.is_using_remote():
		_do_remote_request(payload)
	else:
		_do_local_request(payload)

func _do_local_request(payload: Dictionary):
	_ai_thread_done = false
	_ai_thread = Thread.new()
	_ai_thread.start(_thread_request.bind(payload, _server_manager))

func _do_remote_request(payload: Dictionary):
	var response = await _server_manager.make_request("chat", payload)
	_stop_thinking_dots()
	if response == null or response.has("error"):
		_use_fallback("Connection interrupted...")
		is_waiting_for_response = false
		input_field.editable = true
		return
	var ai_response = response.get("response", "")
	_on_ai_response_received(ai_response)

func _thread_request(payload: Dictionary, manager: Node) -> void:
	var response = manager.make_request_sync("chat", payload)
	if response.has("error"):
		_ai_thread_done = true
		return
	_ai_thread_result = response.get("response", "")
	_ai_thread_done = true

func _process(_delta: float) -> void:
	if not _ai_thread_done:
		return
	if _ai_thread == null:
		_ai_thread_done = false
		return
	_ai_thread.wait_to_finish()
	_ai_thread = null
	_ai_thread_done = false
	_stop_thinking_dots()
	if _ai_thread_result != "":
		_on_ai_response_received(_ai_thread_result)
	else:
		_use_fallback("No response received.")
	_ai_thread_result = ""

func _on_ai_response_received(message: String):
	is_waiting_for_response = false
	input_field.editable = true
	if conversation_history.size() > 0 and conversation_history[-1].has("player"):
		conversation_history[-1]["npc"] = message
	output_label.text = message
	input_field.grab_focus()

func _use_fallback(text: String):
	is_waiting_for_response = false
	input_field.editable = true
	_stop_thinking_dots()
	output_label.text = text
	input_field.grab_focus()

func _start_thinking_dots():
	if _thinking_tween:
		_thinking_tween.kill()
	output_label.text = "."
	_thinking_tween = create_tween().set_loops()
	_thinking_tween.tween_callback(_cycle_thinking_dots).set_delay(0.5)

func _cycle_thinking_dots():
	if not is_waiting_for_response or not output_label:
		return
	match output_label.text:
		".": output_label.text = ".."
		"..": output_label.text = "..."
		_: output_label.text = "."

func _stop_thinking_dots():
	if _thinking_tween:
		_thinking_tween.kill()
		_thinking_tween = null
