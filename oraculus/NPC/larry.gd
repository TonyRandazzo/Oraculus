extends Node2D

# Larry — Gigante prigioniero nei sotterranei.
# Non combatte, non cammina. Parla, mente, osserva ogni azione del giocatore.
# Se gli sei simpatico, ti teletrasporta.

@export var npc_name: String = "Larry"

@onready var detection_area: Area2D = $Area2D
@onready var dialogue_box = $Dialogue

# ── Stato relazionale ─────────────────────────────────────────────────────────
var friendship_level: int = 0
var max_friendship: int = 5
var hostility: int = 25
var player: Node2D = null
var player_input_buffer: String = ""
var conversation_history: Array = []
const MEMORY_CAPACITY := 6

# ── Osservazione azioni giocatore ─────────────────────────────────────────────
var observed_attacks: int = 0
var observed_parries: int = 0
var observed_slides: int = 0
var observed_jumps: int = 0
var player_ever_parried: bool = false

var _prev_attacking: bool = false
var _prev_parrying: bool = false
var _prev_sliding: bool = false
var _prev_on_floor: bool = true
var _observation_cooldown: float = 0.0
const OBSERVATION_COOLDOWN := 9.0

# ── Teleport ──────────────────────────────────────────────────────────────────
const TELEPORT_TARGET := Vector2(590, -76)
const TELEPORT_FRIENDSHIP_REQ := 3

# ── AI ────────────────────────────────────────────────────────────────────────
var is_waiting_for_response: bool = false
var _server_ready: bool = false
var _ai_thread: Thread = null
var _ai_thread_result: String = ""
var _ai_thread_new_hostility: int = -1
var _ai_thread_done: bool = false
var _thinking_tween: Tween = null

# ── Risposte ──────────────────────────────────────────────────────────────────
var fallback_responses: Array = [
	"*yawns enormously* Oh, a visitor. How delightfully boring.",
	"*counting fingers* Let me think... no. I have no useful information. Goodbye.",
	"*grins* I know everything. Unfortunately I choose to share almost none of it.",
	"*dramatically* The answer is 'yes'. Or 'no'. I forget which.",
]

var friendly_responses: Array = [
	"*surprised* That was... actually funny. I respect that.",
	"*laughing* Not bad for a soldier who can't parry properly.",
	"*impressed* You may stay. Few people I say that to.",
	"*warms up* Ask me something. I might even tell the truth.",
	"*leans down* You're alright, small one. Don't ruin it.",
]

var observation_comments: Dictionary = {
	"attack": [
		"*counting* Swing number %d. Elegant? No. Effective? We'll see.",
		"*notes it down* Another attack. Your arm must be very tired.",
		"*applauds once* A hit! Or a miss. Either way, commitment.",
	],
	"parry": [
		"*raises eyebrow* A parry. So you DO know that move.",
		"*marks tally* Parry registered. I will remember this.",
		"*ironically* Oh, beautiful parry. Very fancy for someone lost underground.",
	],
	"slide": [
		"*chuckles* Did you just slide? On purpose?",
		"*watching* Stylish. Completely unnecessary. I approve.",
	],
	"jump": [
		"*impressed* Bold, jumping in a dungeon.",
		"*flatly* Gravity still works down here. Just confirming.",
	],
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("demons")
	detection_area.add_to_group("demon_detection")
	detection_area.connect("body_entered", _on_body_entered)
	detection_area.connect("body_exited", _on_body_exited)

	var server_manager := get_node_or_null("/root/AIServerManager")
	if server_manager:
		if not server_manager.server_started.is_connected(_on_server_started):
			server_manager.server_started.connect(_on_server_started)
		if server_manager.is_server_ready():
			_on_server_started()

func _on_server_started() -> void:
	_server_ready = true
	_send_to_ai_server(
		"Introduce yourself in ONE sardonic sentence (max 12 words). You are Larry, a Giant trapped underground who knows too much."
	)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

# ── Osservazione ogni frame ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	_handle_ai_thread()

	if not player or not is_instance_valid(player):
		return

	_observation_cooldown -= delta
	_observe_player()

func _observe_player() -> void:
	var attacking: bool = player.get("attacking") if "attacking" in player else false
	var parrying:  bool = player.get("parrying")  if "parrying"  in player else false
	var sliding:   bool = player.get("sliding")   if "sliding"   in player else false
	var on_floor:  bool = player.is_on_floor()    if player.has_method("is_on_floor") else true

	if attacking and not _prev_attacking:
		observed_attacks += 1
		_maybe_comment("attack", [str(observed_attacks)])

	if parrying and not _prev_parrying:
		observed_parries += 1
		player_ever_parried = true
		_maybe_comment("parry", [])

	if sliding and not _prev_sliding:
		observed_slides += 1
		_maybe_comment("slide", [])

	if on_floor and not _prev_on_floor:
		observed_jumps += 1
		_maybe_comment("jump", [])

	_prev_attacking = attacking
	_prev_parrying  = parrying
	_prev_sliding   = sliding
	_prev_on_floor  = on_floor

func _maybe_comment(action: String, fmt_args: Array) -> void:
	if _observation_cooldown > 0 or is_waiting_for_response:
		return
	var pool: Array = observation_comments.get(action, [])
	if pool.is_empty():
		return
	var template: String = pool[randi() % pool.size()]
	var text: String = template % fmt_args if not fmt_args.is_empty() else template
	dialogue_box.show_text(text)
	_observation_cooldown = OBSERVATION_COOLDOWN

# ── Input giocatore ───────────────────────────────────────────────────────────
func receive_player_answer(answer: String) -> void:
	player_input_buffer = answer

	if _try_offer_teleport(answer):
		return

	if is_waiting_for_response:
		return

	_analyze_friendship(answer)
	_send_to_ai_server(answer)

# ── Teletrasporto ─────────────────────────────────────────────────────────────
func _try_offer_teleport(msg: String) -> bool:
	if friendship_level < TELEPORT_FRIENDSHIP_REQ:
		return false

	var lower := msg.to_lower()
	var asking := (
		lower.contains("teleport") or lower.contains("shortcut") or
		lower.contains("take me")  or lower.contains("transport") or
		lower.contains("bring me") or lower.contains("somewhere") or
		lower.contains("portami")  or lower.contains("scorciatoia") or
		lower.contains("trasporta")
	)
	if not asking:
		return false

	var quips := [
		"*snaps fingers* Done. Don't thank me — I'm very busy doing nothing.",
		"*waves hand* There you go. Gift or prank — even I'm not sure.",
		"*grins* Fastest route available: my goodwill. Rare. Enjoy it.",
	]
	dialogue_box.show_text(quips[randi() % quips.size()])

	get_tree().create_timer(1.4).timeout.connect(func():
		if player and is_instance_valid(player):
			player.global_position = TELEPORT_TARGET
	, CONNECT_ONE_SHOT)
	return true

# ── Amicizia ──────────────────────────────────────────────────────────────────
func _analyze_friendship(answer: String) -> void:
	var lower := answer.to_lower()
	var change := 0

	if lower.contains("funny") or lower.contains("joke") or lower.contains("laugh") or lower.contains("haha"):
		change = 2
	elif lower.contains("giant") or lower.contains("big") or lower.contains("enormous"):
		change = 1
	elif lower.contains("lie") or lower.contains("truth") or lower.contains("liar"):
		change = 1
	elif lower.contains("interesting") or lower.contains("clever") or lower.contains("smart"):
		change = 1
	elif lower.contains("please") or lower.contains("help") or lower.contains("map"):
		change = 1
	elif lower.contains("boring") or lower.contains("useless"):
		change = -1
	elif lower.contains("kill") or lower.contains("attack") or lower.contains("fight"):
		change = -1

	if change == 0:
		return

	var prev := friendship_level
	var prev_hostility := hostility
	friendship_level = clamp(friendship_level + change, 0, max_friendship)
	hostility = clamp(hostility - change * 10, 0, 100)
	FeedbackPopup.show_stat_change(self, friendship_level - prev, hostility - prev_hostility)
	if change > 0 and friendship_level > prev:
		dialogue_box.show_text(friendly_responses[min(friendship_level - 1, friendly_responses.size() - 1)])

# ── AI ────────────────────────────────────────────────────────────────────────
func _send_to_ai_server(player_message: String) -> void:
	if not _server_ready:
		dialogue_box.show_text(fallback_responses[randi() % fallback_responses.size()])
		return
	if is_waiting_for_response or (_ai_thread != null and _ai_thread.is_alive()):
		return

	var server_manager := get_node_or_null("/root/AIServerManager")
	if not server_manager:
		return

	var payload := {
		"npc_name":             npc_name,
		"player_input":         player_message,
		"hostility":            hostility,
		"friendship":           friendship_level * 20,
		"language":             "inglese",
		"max_tokens":           30,
		"temperature":          0.9,
		"conversation_history": conversation_history,
		"context_vars": {
			"attacks":       observed_attacks,
			"parries":       observed_parries,
			"ever_parried":  player_ever_parried,
			"can_teleport":  friendship_level >= TELEPORT_FRIENDSHIP_REQ,
		},
	}

	is_waiting_for_response = true
	_start_thinking_dots()

	if server_manager.is_using_remote():
		var response = await server_manager.make_request("chat", payload)
		_stop_thinking_dots()
		if response == null or response.has("error"):
			_use_fallback()
			return
		_handle_response(response)
	else:
		_ai_thread = Thread.new()
		_ai_thread_done = false
		_ai_thread.start(_thread_request.bind(payload, server_manager))

func _thread_request(payload: Dictionary, server_manager: Node) -> void:
	var response = server_manager.make_request_sync("chat", payload)
	_ai_thread_result        = response.get("response", "") if not response.has("error") else ""
	_ai_thread_new_hostility = int(response.get("new_hostility", hostility))
	_ai_thread_done = true

func _handle_ai_thread() -> void:
	if not _ai_thread_done or _ai_thread == null:
		return
	_ai_thread.wait_to_finish()
	_ai_thread = null
	_ai_thread_done = false
	_stop_thinking_dots()
	if _ai_thread_result != "":
		_handle_response({"response": _ai_thread_result, "new_hostility": _ai_thread_new_hostility})
	else:
		_use_fallback()
	_ai_thread_result        = ""
	_ai_thread_new_hostility = -1

func _handle_response(response: Dictionary) -> void:
	is_waiting_for_response = false
	var text: String = response.get("response", "")
	var new_h := int(response.get("new_hostility", hostility))
	if new_h >= 0:
		var prev_friendship := friendship_level
		var prev_hostility := hostility
		hostility        = new_h
		friendship_level = clamp(5 - int(hostility / 20.0), 0, max_friendship)
		FeedbackPopup.show_stat_change(self, friendship_level - prev_friendship, hostility - prev_hostility)
	if conversation_history.size() >= MEMORY_CAPACITY:
		conversation_history.pop_front()
	conversation_history.append({"player": player_input_buffer, "npc": text})
	if dialogue_box:
		dialogue_box.show_text(text)

func _use_fallback() -> void:
	is_waiting_for_response = false
	_stop_thinking_dots()
	if dialogue_box:
		dialogue_box.show_text(fallback_responses[randi() % fallback_responses.size()])

# ── Thinking dots ─────────────────────────────────────────────────────────────
func _start_thinking_dots() -> void:
	if _thinking_tween: _thinking_tween.kill()
	if dialogue_box: dialogue_box.show_text(".")
	_thinking_tween = create_tween().set_loops()
	_thinking_tween.tween_callback(func():
		if not is_waiting_for_response or not dialogue_box: return
		var cur: String = dialogue_box.get_displayed_text().strip_edges() \
			if dialogue_box.has_method("get_displayed_text") else "."
		match cur:
			".":  dialogue_box.show_text("..")
			"..": dialogue_box.show_text("...")
			_:    dialogue_box.show_text(".")
	).set_delay(0.5)

func _stop_thinking_dots() -> void:
	if _thinking_tween:
		_thinking_tween.kill()
		_thinking_tween = null
