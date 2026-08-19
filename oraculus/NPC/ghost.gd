extends CharacterBody2D

@export var speed: float = 40.0
@export var gravity: float = 900.0
@export var jump_velocity: float = -250.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 2.5
@export var attack_damage: int = 8
@export var max_health: int = 80
@export var thinking_dot_delay: float = 0.5
@export var invincibility_duration: float = 0.8
@export var attack_animation_fps: float = 10.0
@export var ai_update_interval: float = 4.0
@export var memory_capacity: int = 5
@export var aggression_increase_on_hit: float = 0.1
@export var base_aggression: float = 0.2   # SmirBombo è gentile, raramente attacca
@export var knockback_force: float = 200.0
@export var lateral_offset_range: Vector2 = Vector2(50.0, 120.0)

@export var npc_name: String = "SmirBombo"
const AI_SERVER_URL = "http://localhost:5000"

@export var personality_traits: Dictionary = {
	"aggressiveness": 0.2,
	"curiosity": 0.85,
	"playfulness": 0.55,
	"loyalty": 0.8
}

var is_attacking: bool = false
var attack_frame_start: int = 6
var attack_frame_end: int = 16
var attack_hit_frame: int = 10

var player: Node2D = null
var state: String = "idle"
var attack_timer: float = 0.0
var is_interacting: bool = false
var is_waiting_for_response: bool = false
var friendship_level: int = 0
var max_friendship: int = 5
var thinking_timer: float = 0.0
var dot_count: int = 0
var current_health: int
var can_attack: bool = true
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var last_ai_update: float = 0.0
var dialogue_cooldown_timer: float = 1000.0
var can_initiate_dialogue: bool = true
var current_aggression: float = base_aggression
var current_lateral_offset: float = 0.0
var hostility: int = 30   # SmirBombo non è ostile di default

var _ai_thread: Thread = null
var _thinking_tween: Tween = null
var _ai_thread_result: String = ""
var _ai_thread_new_hostility: int = -1
var _ai_thread_done: bool = false
var player_input_buffer: String = ""

var _server_ready: bool = false
var _server_timeout_timer: float = 0.0
var _server_check_started: bool = false

var conversation_history: Array = []
var personality_state: Dictionary = {}
var current_mood: String = "neutral"
var mood_intensity: float = 0.5
var environmental_factors: Dictionary = {}
var ai_decision_weights: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var dialogue_box = $Dialogue
@onready var hit_box = $HitBox/CollisionShape2D
@onready var attack_box = $AttackBox/CollisionShape2D
@onready var animation_player = $AnimationPlayer
@onready var hurt_sound = $HurtSound
@onready var attack_sound = $AttackSound
@onready var death_sound = $DeathSound
@onready var VFX = $VFX

# SmirBombo cerca di non attaccare — risponde con tristezza e confusione
var fallback_responses: Array = [
	"*sighs softly* I only wish to speak with you...",
	"*floats quietly* This castle remembers better days.",
	"*whispers* You remind me of those who once walked these halls."
]

var cultural_responses: Array = [
	"*brightens* You know of such things? How wonderful.",
	"*gently* The family cherished that. I still do.",
	"*warmly* You are not as empty as I feared."
]

var attack_phrases: Array = [
	"*reluctant* I did not want this...",
	"*trembling* You leave me no choice.",
	"*sorrowful* Even patience has its end.",
	"*whispers* Forgive me. Forgive me."
]

var aggressive_hit_responses: Array = [
	"*flinches* Why would you do that?",
	"*hurt* I was trying to help you.",
	"*backs away* Please... stop.",
	"*quietly breaks* I thought you were different."
]

var friendly_responses: Array = [
	"*relieved* Perhaps I was wrong to fear you.",
	"*warms* You speak with more care than most.",
	"*softly* I remember soldiers like you — before the war changed them.",
	"*almost smiling* The Oracle would have liked you, I think.",
	"*trusting* Come. I will show you what I know."
]

func _send_to_ai_server(player_message: String):
	if not _server_ready:
		_use_fallback_response(fallback_responses[randi() % fallback_responses.size()])
		return
	if is_waiting_for_response or (_ai_thread != null and _ai_thread.is_alive()):
		return

	var server_manager = get_node_or_null("/root/AIServerManager")
	if not server_manager:
		_use_fallback_response(fallback_responses[randi() % fallback_responses.size()])
		return

	if server_manager.is_using_remote():
		_do_remote_request(player_message)
	else:
		_do_local_request(player_message)

func _do_local_request(player_message: String):
	var server_manager = get_node_or_null("/root/AIServerManager")
	if not server_manager:
		_use_fallback_response(fallback_responses[randi() % fallback_responses.size()])
		return

	is_waiting_for_response = true
	is_interacting = true
	_ai_thread_done = false
	_start_thinking_dots()

	var payload = {
		"npc_name": npc_name,
		"player_input": player_message,
		"hostility": hostility,
		"friendship": friendship_level * 20,
		"language": "inglese",
		"max_tokens": 25,
		"temperature": 0.75,
		"max_length": 12,
		"conversation_history": conversation_history,
	}

	_ai_thread = Thread.new()
	_ai_thread.start(_thread_request.bind(payload, server_manager))

func _do_remote_request(player_message: String):
	var server_manager = get_node_or_null("/root/AIServerManager")
	if not server_manager:
		_use_fallback_response("Connection error...")
		return

	is_waiting_for_response = true
	is_interacting = true
	_start_thinking_dots()

	var payload = {
		"npc_name": npc_name,
		"player_input": player_message,
		"hostility": hostility,
		"friendship": friendship_level * 20,
		"language": "inglese",
		"max_tokens": 25,
		"temperature": 0.75,
		"max_length": 12,
		"conversation_history": conversation_history,
	}

	var response = await server_manager.make_request("chat", payload)

	_stop_thinking_dots()

	if response == null or response.has("error"):
		_use_fallback_response("*fades slightly* The words escape me...")
		is_waiting_for_response = false
		is_interacting = false
		return

	var ai_response = response.get("response", "")
	var new_hostility = int(response.get("new_hostility", hostility))

	if new_hostility >= 0:
		var prev_friendship = friendship_level
		var prev_hostility = hostility
		hostility = new_hostility
		friendship_level = clamp(5 - int(hostility / 20.0), 0, max_friendship)
		FeedbackPopup.show_stat_change(self, friendship_level - prev_friendship, hostility - prev_hostility)

	_on_ai_chat_received(ai_response)

func _thread_request(payload: Dictionary, server_manager: Node) -> void:
	var response = server_manager.make_request_sync("chat", payload)
	if response.has("error"):
		_ai_thread_done = true
		return
	_ai_thread_result = response.get("response", "")
	_ai_thread_new_hostility = int(response.get("new_hostility", hostility))
	_ai_thread_done = true

func _on_ai_chat_received(message: String):
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	var sentiment = analyze_sentiment(message)
	if conversation_history.size() >= memory_capacity:
		conversation_history.pop_front()
	conversation_history.append({"player": player_input_buffer, "npc": message, "sentiment": sentiment, "time": Time.get_unix_time_from_system()})
	update_personality_from_response(message, sentiment)
	if dialogue_box:
		dialogue_box.show_text(message)
	match state:
		"riddle", "waiting": state = "conversing"
		_: state = "ready"

func receive_player_answer(answer: String):
	player_input_buffer = answer
	if state == "attacking": state = "conversing"
	if state != "waiting" and state != "conversing" and state != "ready": return
	if is_waiting_for_response: return
	face_player()
	state = "waiting"
	analyze_answer_for_friendship(answer)
	_send_to_ai_server(answer)

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
		if _ai_thread_new_hostility >= 0:
			var prev_friendship = friendship_level
			var prev_hostility = hostility
			hostility = _ai_thread_new_hostility
			friendship_level = clamp(5 - int(hostility / 20.0), 0, max_friendship)
			FeedbackPopup.show_stat_change(self, friendship_level - prev_friendship, hostility - prev_hostility)
		_on_ai_chat_received(_ai_thread_result)
	else:
		_on_ai_chat_failed(-1)

	_ai_thread_result = ""
	_ai_thread_new_hostility = -1

func _ready() -> void:
	current_health = max_health
	current_aggression = base_aggression
	personality_traits["aggressiveness"] = base_aggression
	hostility = int(base_aggression * 100)

	add_to_group("demons")
	detection_area.add_to_group("demon_detection")

	detection_area.connect("body_entered", _on_body_entered)
	timer.connect("timeout", _on_timeout)
	$HitBox.connect("area_entered", _on_hit_box_area_entered)
	$AttackBox.connect("area_entered", _on_attack_box_area_entered)
	sprite.connect("animation_finished", _on_animation_finished)

	sprite.play("idle")
	attack_box.disabled = true

	initialize_personality()
	_update_ai_state()
	_update_lateral_offset()

	var server_manager = get_node_or_null("/root/AIServerManager")
	if server_manager:
		if not server_manager.server_started.is_connected(_on_server_started):
			server_manager.server_started.connect(_on_server_started)
		if not server_manager.server_failed.is_connected(_on_server_failed):
			server_manager.server_failed.connect(_on_server_failed)

		if server_manager.is_server_ready():
			_on_server_started()
		else:
			_server_timeout_timer = 20.0
	else:
		_server_ready = false

func _on_server_started():
	_server_ready = true
	say_launch_message()

func _on_server_failed(_error_message: String):
	_server_ready = false

func _process_server_timeout(delta: float):
	if not _server_ready and _server_timeout_timer > 0:
		_server_timeout_timer -= delta
		if _server_timeout_timer <= 0 and not _server_ready:
			_server_ready = false

func face_player():
	if player and is_instance_valid(player):
		var direction = sign(player.global_position.x - global_position.x)
		sprite.flip_h = direction > 0
		VFX.flip_h = direction > 0

func _update_lateral_offset():
	current_lateral_offset = randf_range(lateral_offset_range.x, lateral_offset_range.y)
	if randf() > 0.5:
		current_lateral_offset = -current_lateral_offset

func initialize_personality():
	personality_state = personality_traits.duplicate()
	personality_state["patience"] = 1.0 - personality_traits["aggressiveness"]
	personality_state["social"] = (personality_traits["curiosity"] + personality_traits["playfulness"]) / 2.0
	ai_decision_weights = {
		"attack":  current_aggression,
		"talk":    personality_traits["curiosity"],
		"ally":    personality_traits["loyalty"],
		"tease":   personality_traits["playfulness"],
		"retreat": 0.05
	}

func _physics_process(delta: float) -> void:
	_process_server_timeout(delta)

	velocity.y += gravity * delta

	if player and not is_instance_valid(player):
		player = null
		state = "idle"

	attack_timer -= delta

	if is_attacking and sprite.animation == "attack":
		if sprite.frame >= attack_frame_start and sprite.frame <= attack_frame_end:
			if sprite.frame == attack_hit_frame and attack_box.disabled:
				attack_sound.play()
				attack_box.disabled = false
				if attack_phrases.size() > 0:
					dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
			elif sprite.frame != attack_hit_frame:
				attack_box.disabled = true
		else:
			attack_box.disabled = true

	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			animation_player.stop()
			sprite.modulate = Color(1, 1, 1, 1)

	if not can_initiate_dialogue:
		dialogue_cooldown_timer -= delta
		if dialogue_cooldown_timer <= 0:
			can_initiate_dialogue = true
			dialogue_cooldown_timer = 5.0

	last_ai_update += delta
	if player and state in ["idle", "ready", "conversing"] and not is_waiting_for_response and can_initiate_dialogue:
		if last_ai_update > ai_update_interval:
			last_ai_update = 0.0
			var decision = make_ai_decision()
			execute_ai_decision(decision)

	match state:
		"idle", "ready", "riddle", "waiting", "conversing":
			handle_peaceful_states()
		"ally":
			handle_ally_behavior()
		"attacking":
			handle_attack_behavior(delta)
		"hurt":
			handle_hurt_behavior()

	move_and_slide()

func handle_peaceful_states():
	velocity.x = 0
	velocity.y = 0
	sprite.play("idle")

func handle_ally_behavior():
	sprite.play("idle")
	velocity.x = 0
	velocity.y = 0
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance > 150:
			var target_position = player.global_position + Vector2(current_lateral_offset, 0)
			var dir = sign(target_position.x - global_position.x)
			velocity.x = dir * speed
			sprite.flip_h = dir > 0

func handle_attack_behavior(delta: float):
	if player and is_instance_valid(player):
		var target_position = player.global_position + Vector2(current_lateral_offset, 0)
		var direction_x = sign(target_position.x - global_position.x)
		var direction_y = sign(target_position.y - global_position.y)
		var y_distance = abs(target_position.y - global_position.y)

		velocity.x = direction_x * speed * (1.0 + current_aggression)
		sprite.flip_h = direction_x > 0

		if y_distance > 20:
			velocity.y = lerp(velocity.y, direction_y * speed * 0.7, 0.1)

		var distance = global_position.distance_to(target_position)
		if distance < attack_range and can_attack:
			start_attack()
		elif distance < attack_range * 1.5:
			velocity.x = sign(target_position.x - global_position.x) * speed * 0.8
			sprite.play("walk")
		else:
			sprite.play("walk")

func handle_hurt_behavior():
	velocity.x = lerp(velocity.x, 0.0, 0.1)
	velocity.y = lerp(velocity.y, 0.0, 0.1)

func start_attack():
	attack_timer = attack_cooldown * (1.5 - current_aggression * 0.5)
	can_attack = false
	is_attacking = true
	state = "attacking"
	if sprite.sprite_frames.has_animation("attack"):
		sprite.speed_scale = attack_animation_fps / sprite.sprite_frames.get_animation_speed("attack") * (1.0 + current_aggression * 0.3)
		sprite.play("attack")
		sprite.frame = 0
	else:
		push_error("'attack' animation not found!")
		end_attack()
		return
	attack_box.disabled = true
	_update_lateral_offset()

func _disable_attack_box():
	attack_box.disabled = true

func _on_animation_finished():
	if sprite.animation == "attack":
		end_attack()
	elif sprite.animation == "hurt":
		# SmirBombo non riparte ad attaccare dopo il hurt — si ritira
		state = "ally" if friendship_level >= 2 else "idle"

func end_attack():
	is_attacking = false
	attack_box.disabled = true
	if friendship_level >= max_friendship:
		state = "ally"
	else:
		state = "conversing"
	can_attack = true

func _on_hit_box_area_entered(area: Area2D):
	if area.is_in_group("player") and not is_invincible:
		var damage_source = area.get_parent()
		var damage = 10
		if damage_source.has_method("get_damage"):
			damage = damage_source.get_damage()
		elif damage_source.has_method("take_damage"):
			damage = damage_source.damage if "damage" in damage_source else 10
		take_damage(damage)

func _on_attack_box_area_entered(area: Area2D):
	if area.is_in_group("hit_player"):
		var p = area.get_parent()
		if p.has_method("take_damage"):
			p.take_damage(attack_damage * (1.0 + current_aggression * 0.5))

func take_damage(amount: int):
	if is_invincible or state == "ally":
		return
	current_aggression = min(current_aggression + aggression_increase_on_hit, 1.0)
	personality_traits["aggressiveness"] = current_aggression
	personality_state["aggressiveness"] = current_aggression
	hostility = min(hostility + 8, 100)
	adapt_decision_weights()
	current_health -= amount
	hurt_sound.play()
	animation_player.play("hit_flash")
	VFX.play("hit")
	is_invincible = true
	invincibility_timer = invincibility_duration
	var knockback_direction = -1.0 if not sprite.flip_h else 1.0
	velocity.x = knockback_direction * knockback_force
	velocity.y = -knockback_force * 0.5
	# SmirBombo attacca solo se già molto ostile
	if friendship_level < 2 and current_aggression > 0.5:
		state = "attacking"
		can_attack = true
		attack_timer = 0.0
		start_attack()
		dialogue_box.show_text(aggressive_hit_responses[randi() % aggressive_hit_responses.size()])
	else:
		dialogue_box.show_text(aggressive_hit_responses[randi() % aggressive_hit_responses.size()])
	sprite.play("hurt")
	if current_health <= 0:
		die()

func die():
	state = "dead"
	death_sound.play()
	sprite.play("death")
	VFX.play("vanishing")
	VFX.scale = Vector2(2.583, 2.583)
	set_physics_process(false)
	await sprite.animation_finished
	queue_free()

func _update_ai_state():
	update_environmental_factors()
	update_mood()
	adapt_decision_weights()
	get_tree().create_timer(ai_update_interval).timeout.connect(_update_ai_state)

func update_environmental_factors():
	environmental_factors = {
		"time_of_day":           _get_time_factor(),
		"player_proximity":      _get_player_proximity_factor(),
		"health_status":         float(current_health) / float(max_health),
		"recent_interactions":   _get_interaction_trend()
	}

func _get_time_factor() -> float:
	return abs(fmod(Time.get_unix_time_from_system() / 43200.0, 1.0) - 0.5) * 2.0

func _get_player_proximity_factor() -> float:
	if not player or not is_instance_valid(player): return 0.0
	return 1.0 - clamp(global_position.distance_to(player.global_position) / 500.0, 0.0, 1.0)

func _get_interaction_trend() -> float:
	if conversation_history.size() == 0: return 0.5
	var positive_count = conversation_history.filter(func(x): return x.get("sentiment", 0) > 0).size()
	return float(positive_count) / conversation_history.size()

func update_mood():
	var mood_score = {
		"angry":   personality_state["aggressiveness"] * (1.0 - environmental_factors["health_status"]),
		"happy":   personality_state["playfulness"]    * environmental_factors["recent_interactions"],
		"curious": personality_state["curiosity"]      * environmental_factors["player_proximity"],
		"loyal":   personality_state["loyalty"]        * (friendship_level / float(max_friendship))
	}
	current_mood = mood_score.keys()[mood_score.values().find(mood_score.values().max())]
	mood_intensity = mood_score[current_mood]

func adapt_decision_weights():
	ai_decision_weights["attack"]  = current_aggression * (1.0 if current_mood == "angry" else 0.2)
	ai_decision_weights["talk"]    = personality_state["curiosity"] * (1.8 if current_mood == "curious" else 1.2) * (1.0 - current_aggression * 0.5)
	ai_decision_weights["ally"]    = personality_state["loyalty"] * (2.5 if current_mood == "loyal" else 1.2) * (1.0 - current_aggression)
	ai_decision_weights["tease"]   = personality_state["playfulness"] * (1.5 if current_mood == "happy" else 0.9)
	ai_decision_weights["retreat"] = 0.4 if environmental_factors["health_status"] < 0.3 else 0.05
	if environmental_factors["health_status"] < 0.3:
		ai_decision_weights["ally"]   *= 0.3
		ai_decision_weights["attack"] *= 1.5

func make_ai_decision() -> String:
	var decisions = ai_decision_weights.keys()
	var weights   = ai_decision_weights.values()
	var total     = weights.reduce(func(a, b): return a + b)
	var normalized = weights.map(func(x): return x / total)
	var rand = randf()
	var cumulative = 0.0
	for i in range(normalized.size()):
		cumulative += normalized[i]
		if rand <= cumulative:
			return decisions[i]
	return decisions[-1]

func execute_ai_decision(decision: String):
	if not can_initiate_dialogue: return
	match decision:
		"attack":
			# SmirBombo attacca solo se estremamente ostile
			if friendship_level < 1 and current_aggression > 0.7:
				state = "attacking"
				dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
				can_initiate_dialogue = false
		"talk":
			share_castle_knowledge()
			can_initiate_dialogue = false
		"ally":
			if friendship_level >= 3:
				state = "ally"
				dialogue_box.show_text("*warmly* Stay close. I will guide you.")
				can_initiate_dialogue = false
		"tease":
			var teasings := [
				"*amused* You look lost. Most visitors do.",
				"*gently* The castle is full of surprises. So am I.",
				"*curious* What brought you here, really?"
			]
			dialogue_box.show_text(teasings[randi() % teasings.size()])
			can_initiate_dialogue = false
		"retreat":
			if current_health < max_health * 0.3:
				state = "hurt"
				dialogue_box.show_text("*quietly* I need... a moment.")
				can_initiate_dialogue = false

func say_launch_message():
	_send_to_ai_server("Introduce yourself briefly in ONE sentence (max 10 words). You are Smirne Bombo, a gentle spirit who knew the noble family.")

func share_castle_knowledge():
	var prompts := [
		"Share ONE curious fact about the castle or its spirits (max 10 words).",
		"Ask the player ONE gentle question about why they came here (max 8 words).",
		"Mention ONE thing you remember about the noble family (max 10 words).",
		"Hint at something interesting elsewhere in the castle (max 10 words).",
	]
	_send_to_ai_server(prompts[randi() % prompts.size()])

func analyze_answer_for_friendship(answer: String):
	var lower = answer.to_lower()
	var change = 0
	# SmirBombo risponde positivamente a rispetto, cultura, gentilezza
	if lower.contains("please") or lower.contains("thank") or lower.contains("kind"):
		change = 1
	elif lower.contains("family") or lower.contains("oracle") or lower.contains("remember"):
		change = 2
	elif lower.contains("art") or lower.contains("history") or lower.contains("knowledge") or lower.contains("book"):
		change = 2
	elif lower.contains("sorry") or lower.contains("forgive") or lower.contains("peace"):
		change = 1
	elif lower.contains("friend") or lower.contains("trust") or lower.contains("help"):
		change = 1
	# Risponde molto negativamente a violenza e insulti
	elif lower.contains("kill") or lower.contains("die") or lower.contains("hate") or lower.contains("stupid"):
		change = -2
	elif lower.contains("army") or lower.contains("holy cross") or lower.contains("soldier"):
		change = -1
	if change != 0:
		change_friendship(change)

func change_friendship(amount: int):
	var prev = friendship_level
	var prev_hostility = hostility
	friendship_level = clamp(friendship_level + amount, 0, max_friendship)
	hostility = clamp(hostility - amount * 12, 0, 100)
	FeedbackPopup.show_stat_change(self, friendship_level - prev, hostility - prev_hostility)
	if friendship_level >= max_friendship:
		become_ally()
	elif amount > 0 and friendship_level > prev and dialogue_box:
		dialogue_box.show_text(friendly_responses[min(friendship_level - 1, friendly_responses.size() - 1)])

func become_ally():
	state = "ally"
	if dialogue_box:
		dialogue_box.show_text("*quietly moved* I have not felt this in three years. Welcome, friend.")

func analyze_sentiment(text: String) -> float:
	var pos = ["friend", "gentle", "kind", "remember", "family", "oracle", "knowledge", "peace"]
	var neg = ["hate", "kill", "destroy", "army", "cross", "soldier", "stupid", "weak"]
	var lower = text.to_lower()
	var score = 0.0
	for w in pos: if w in lower: score += 0.2
	for w in neg: if w in lower: score -= 0.3
	return clamp(score, -1.0, 1.0)

func update_personality_from_response(message: String, sentiment: float):
	var r = 0.04
	if sentiment > 0.3:
		personality_state["loyalty"]     = min(personality_state["loyalty"]     + r,       1.0)
		personality_state["curiosity"]   = min(personality_state["curiosity"]   + r * 0.5, 1.0)
	elif sentiment < -0.3:
		personality_state["aggressiveness"] = min(personality_state["aggressiveness"] + r, 1.0)
		personality_state["playfulness"]    = max(personality_state["playfulness"]    - r, 0.0)
	adapt_decision_weights()

func _on_ai_chat_failed(_error_code: int):
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	_use_fallback_response("*fades* The words... escape me." if friendship_level > 2 else "*silence*")

func _on_body_entered(body: Node2D):
	if body.name == "Player" and state in ["idle", "ready"]:
		player = body
		face_player()
	elif body.name == "Player" and state in ["conversing", "waiting"]:
		player = body
		face_player()

func _on_timeout():
	if is_waiting_for_response:
		is_waiting_for_response = false
		is_interacting = false
		_stop_thinking_dots()
		_use_fallback_response("*drifts* My thoughts wander..." if friendship_level > 3 else "*silence*")

func _use_fallback_response(text: String):
	if dialogue_box: dialogue_box.show_text(text)
	is_interacting = false
	is_waiting_for_response = false

func _start_thinking_dots() -> void:
	if _thinking_tween:
		_thinking_tween.kill()
	if dialogue_box:
		dialogue_box.show_text(".")
	_thinking_tween = create_tween().set_loops()
	_thinking_tween.tween_callback(_cycle_thinking_dots).set_delay(0.5)

func _cycle_thinking_dots() -> void:
	if not is_waiting_for_response or not dialogue_box:
		return
	var cur = dialogue_box.get_displayed_text().strip_edges() if dialogue_box.has_method("get_displayed_text") else "."
	match cur:
		".":  dialogue_box.show_text("..")
		"..": dialogue_box.show_text("...")
		_:    dialogue_box.show_text(".")

func _stop_thinking_dots() -> void:
	if _thinking_tween:
		_thinking_tween.kill()
		_thinking_tween = null
