extends Node2D

# door_id deve essere unico per ogni istanza della porta nella scena.
# riddle_theme guida il tono dell'indovinello AI (opzionale).
@export var door_id: String = "door_default"
@export var riddle_theme: String = ""

@onready var instructions = $Instractions
@onready var detection_area: Area2D = $Area2D

var door_unlocked: bool = false
var player_in_range: bool = false

# Assegnati da GameState._ready(), non più dall'Inspector.
var _mode: String = "riddle"          # "riddle" | "minigame"
var _minigame_index: int = 0

var current_riddle_text: String = ""
var current_riddle_answer: String = ""

func _ready() -> void:
	detection_area.connect("area_exited", _on_area_2d_area_exited)
	instructions.hide_dialogue()

	# Assegnazione casuale: GameState decide se questa porta ha un riddle o minigame.
	var assignment := GameState.assign_door(door_id)
	_mode = assignment["mode"]

	if _mode == "minigame":
		_minigame_index = assignment["index"]
		detection_area.remove_from_group("demon_detection")
	else:
		# Pre-carica subito il riddle: sarà pronto prima che il giocatore arrivi.
		_load_riddle()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not _is_player_area(area):
		return
	player_in_range = true

	if _mode == "riddle":
		if not current_riddle_text.is_empty():
			instructions.show_text(current_riddle_text)
		else:
			instructions.show_text("...")
	else:
		instructions.show_text("Press [interact] to begin the challenge!")

func _on_area_2d_area_exited(area: Area2D) -> void:
	if not _is_player_area(area):
		return
	player_in_range = false
	instructions.hide_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if _mode == "minigame" and player_in_range and event.is_action_pressed("interact"):
		_activate_minigame()
		get_viewport().set_input_as_handled()

func receive_player_answer(answer: String) -> void:
	if door_unlocked or _mode == "minigame" or current_riddle_answer.is_empty():
		return

	var player_answer := answer.to_lower().strip_edges()
	var expected := current_riddle_answer.to_lower().strip_edges()

	if expected in player_answer:
		_unlock_door()
		instructions.show_text("Correct! The way is open...")
	else:
		instructions.show_text("Wrong... think again.\n\n" + current_riddle_text)

# ── Riddle loading ────────────────────────────────────────────────────────────

func _load_riddle() -> void:
	# current_riddle_text rimane vuoto durante il caricamento:
	# il giocatore vede "..." finché il server non risponde.
	var server := get_node_or_null("/root/AIServerManager")
	if server == null:
		_use_fallback_riddle()
		return

	if server.is_server_ready():
		_fetch_ai_riddle(server)
	else:
		server.server_started.connect(_on_server_started, CONNECT_ONE_SHOT)

func _on_server_started() -> void:
	var server := get_node_or_null("/root/AIServerManager")
	if is_instance_valid(self) and server != null:
		_fetch_ai_riddle(server)

func _fetch_ai_riddle(server: Node) -> void:
	var result = await server.make_request("riddle", {
		"door_id":    door_id,
		"language":   "inglese",
		"theme":      riddle_theme,
		"session_id": GameState.session_id,
	})

	if not is_instance_valid(self):
		return

	var ai_text   = ""
	var ai_answer = ""
	if result != null and not result.has("error"):
		ai_text   = result.get("riddle", "")
		ai_answer = result.get("answer", "")

	if not ai_text.is_empty() and not ai_answer.is_empty():
		current_riddle_text   = ai_text
		current_riddle_answer = ai_answer
	else:
		_use_fallback_riddle()

	if door_id == "door_entrance":
		GameState.entrance_riddle_answer = current_riddle_answer
		print("[DEBUG door_entrance] answer saved to GameState: '%s'" % current_riddle_answer)

	if player_in_range:
		instructions.show_text(current_riddle_text)

func _use_fallback_riddle() -> void:
	var fallback := GameState.get_fallback_riddle()
	current_riddle_text   = fallback["riddle"]
	current_riddle_answer = fallback["answer"]
	if door_id == "door_entrance":
		GameState.entrance_riddle_answer = current_riddle_answer

# ── Minigame activation ───────────────────────────────────────────────────────

func _activate_minigame() -> void:
	var main := get_tree().current_scene
	var minigame_node := main.get_node_or_null("Minigame")
	if minigame_node == null:
		push_error("Door '%s': node 'Minigame' not found." % door_id)
		return

	var children := minigame_node.get_children()
	if children.is_empty():
		push_error("Door '%s': Minigame node has no children." % door_id)
		return

	for child in children:
		child.visible = false

	var idx := _minigame_index % children.size()
	var target := children[idx]

	if target.has_signal("completed") and not target.is_connected("completed", _on_minigame_completed):
		target.connect("completed", _on_minigame_completed)
	if target.has_method("activate"):
		target.activate(door_id)
	target.visible = true

func _on_minigame_completed() -> void:
	_unlock_door()
	instructions.show_text("The door yields to your skill...")

# ── Utilities ─────────────────────────────────────────────────────────────────

func _unlock_door() -> void:
	door_unlocked = true
	$StaticBody2D/CollisionShape2D.disabled = true
	modulate.a = 0.0

func _is_player_area(area: Area2D) -> bool:
	if area.is_in_group("player"):
		return true
	var parent := area.get_parent()
	return parent != null and (parent.name == "Player" or parent.is_in_group("player"))
