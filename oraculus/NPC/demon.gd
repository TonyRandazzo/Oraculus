extends CharacterBody2D

@export var speed: float = 50.0
@export var gravity: float = 900.0
@export var jump_velocity: float = -250.0
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 2.0
@export var attack_damage: int = 15
@export var max_health: int = 100
@export var thinking_dot_delay: float = 0.5
@export var invincibility_duration: float = 0.8
@export var attack_animation_fps: float = 10.0
@export var ai_update_interval: float = 3.0
@export var memory_capacity: int = 5
@export var aggression_increase_on_hit: float = 0.2
@export var base_aggression: float = 0.7
@export var hostility_threshold_for_permanent_hostility: int = 80

@export var personality_traits: Dictionary = {
	"aggressiveness": 0.7,
	"curiosity": 0.5,
	"playfulness": 0.3,
	"loyalty": 0.2
}

var is_attacking: bool = false
var attack_hit_time: float = 0.3
var attack_start_time: float = 0.0

var player: Node2D = null
var state: String = "idle"
var attack_timer: float = 0.0
var is_interacting: bool = false
@export var npc_name: String = "Rigon"
const AI_SERVER_URL = "http://localhost:5000"

var _ai_thread: Thread = null
var _ai_thread_result: String = ""
var _ai_thread_new_hostility: int = -1
var _ai_thread_done: bool = false
var _thinking_tween: Tween = null
var hostility: int = 70

var _server_ready: bool = false
var _server_timeout_timer: float = 0.0

var is_waiting_for_response: bool = false
var friendship_level: int = 0
var max_friendship: int = 5
var current_health: int
var can_attack: bool = true
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var last_ai_update: float = 0.0
var dialogue_cooldown_timer: float = 1000.0
var can_initiate_dialogue: bool = true
var current_aggression: float = base_aggression
var is_permanently_hostile: bool = false

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

var fallback_responses = [
	"*Chuckle* A riddle!", 
	"*Roar* Too hard!", 
	"*Hiss* You amuse me!"
]

var friendly_responses = [
	"*Sigh* Not useless...",
	"*Interest* Keep talking...",
	"*Giggle* You're funny!",
	"*Calm* I was wrong...",
	"*Smile* You're worthy!"
]

var attack_phrases = [
	"*Scream* Suffer!",
	"*Roar* Taste fury!",
	"*Laugh* This hurts!",
	"*Shout* For darkness!",
	"*Hiss* Die now!",
	"*Howl* INSECT!"
]

var aggressive_hit_responses = [
	"*Scream* ENOUGH!",
	"*Roar* TO DUST!",
	"*Shout* PAY DEARLY!",
	"*Hiss* END IS NEAR!",
	"*Laugh* PAIN TASTES!"
]

func _ready() -> void:
	current_health = max_health
	current_aggression = base_aggression
	personality_traits["aggressiveness"] = base_aggression
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
		await get_tree().create_timer(1.0).timeout
		say_launch_message()

func _on_server_started():
	_server_ready = true
	await get_tree().create_timer(1.0).timeout
	say_launch_message()

func _on_server_failed(error_message: String):
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

func initialize_personality():
	personality_state = personality_traits.duplicate()
	personality_state["patience"] = 1.0 - personality_traits["aggressiveness"]
	personality_state["social"] = (personality_traits["curiosity"] + personality_traits["playfulness"]) / 2.0
	ai_decision_weights = {"attack": current_aggression, "talk": personality_traits["curiosity"], "ally": personality_traits["loyalty"], "tease": personality_traits["playfulness"], "retreat": 0.1}

func _physics_process(delta: float) -> void:
	_process_server_timeout(delta)
	
	velocity.y += gravity * delta
	if player and not is_instance_valid(player):
		player = null
		state = "idle"
	attack_timer -= delta
	if is_attacking and sprite.animation == "attack":
		var attack_time = Time.get_ticks_msec() / 1000.0 - attack_start_time
		if attack_time >= attack_hit_time and attack_box.disabled:
			attack_sound.play()
			attack_box.disabled = false
			if attack_phrases.size() > 0:
				dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
		elif attack_time < attack_hit_time:
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
	if player and state in ["idle", "ready", "conversing"] and not is_waiting_for_response and can_initiate_dialogue and not is_permanently_hostile:
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
	if is_permanently_hostile:
		state = "attacking"
		return
	velocity.x = 0
	sprite.play("idle")
	
	if is_on_floor() and player and is_instance_valid(player) and abs(global_position.y - player.global_position.y) < 30:
		if abs(global_position.x - player.global_position.x) < 20:
			var push_dir = sign(global_position.x - player.global_position.x)
			if push_dir == 0:
				push_dir = 1
			velocity.x = push_dir * speed * 2.0

func handle_ally_behavior():
	if is_permanently_hostile:
		state = "attacking"
		return
	sprite.play("idle")
	velocity.x = 0
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance > 150:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * speed
			sprite.flip_h = dir < 0
		
		if is_on_floor() and abs(global_position.y - player.global_position.y) < 30:
			if abs(global_position.x - player.global_position.x) < 20:
				var push_dir = sign(global_position.x - player.global_position.x)
				if push_dir == 0:
					push_dir = 1
				velocity.x = push_dir * speed * 2.0

func handle_attack_behavior(delta: float):
	if player and is_instance_valid(player):
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * speed * (1.0 + current_aggression)
		sprite.flip_h = dir < 0
		
		if is_on_floor() and abs(global_position.y - player.global_position.y) < 30:
			if abs(global_position.x - player.global_position.x) < 20:
				var push_dir = sign(global_position.x - player.global_position.x)
				if push_dir == 0:
					push_dir = 1
				velocity.x = push_dir * speed * 2.0
		
		if not is_attacking and global_position.distance_to(player.global_position) > attack_range * 2.0 and not is_permanently_hostile:
			state = "conversing"
			return
		if not is_attacking:
			var distance = global_position.distance_to(player.global_position)
			if distance < attack_range and can_attack:
				start_attack()
			elif distance < attack_range * 1.5:
				velocity.x = sign(player.global_position.x - global_position.x) * speed * (0.8 + current_aggression * 0.2)
				sprite.play("walk")
			else:
				sprite.play("walk")
	else:
		velocity.x = 0

func handle_hurt_behavior():
	if is_permanently_hostile:
		state = "attacking"
		return
	if player and is_instance_valid(player):
		velocity.x = -sign(player.global_position.x - global_position.x) * speed * 0.5
	else:
		velocity.x = 0

func start_attack():
	attack_timer = attack_cooldown * (1.5 - current_aggression * 0.5)
	can_attack = false
	is_attacking = true
	state = "attacking"
	attack_start_time = Time.get_ticks_msec() / 1000.0
	if sprite.sprite_frames.has_animation("attack"):
		sprite.speed_scale = attack_animation_fps / sprite.sprite_frames.get_animation_speed("attack") * (1.0 + current_aggression * 0.3)
		sprite.play("attack")
	else:
		push_error("'attack' animation not found!")
		end_attack()
		return
	attack_box.disabled = true

func _disable_attack_box():
	attack_box.disabled = true

func _on_animation_finished():
	if sprite.animation == "attack":
		end_attack()
	elif sprite.animation == "hurt":
		state = "attacking" if friendship_level < 3 else "ally"

func end_attack():
	is_attacking = false
	attack_box.disabled = true
	if player and global_position.distance_to(player.global_position) < attack_range * 1.5 and not is_permanently_hostile:
		state = "conversing"
	elif friendship_level >= max_friendship and not is_permanently_hostile:
		state = "ally"
	else:
		state = "idle"
	can_attack = true

func _on_hit_box_area_entered(area: Area2D):
	if area.is_in_group("player") and not is_invincible:
		var damage_source = area.get_parent()
		var damage = 10
		if damage_source.has_method("get_damage"): damage = damage_source.get_damage()
		elif damage_source.has_method("take_damage"): damage = damage_source.damage if "damage" in damage_source else 10
		take_damage(damage)

func _on_attack_box_area_entered(area: Area2D):
	if area.is_in_group("hit_player"):
		var p = area.get_parent()
		if p.has_method("take_damage"):
			p.take_damage(attack_damage * (1.0 + current_aggression * 0.5))

func take_damage(amount: int):
	if is_invincible or state == "ally": return
	
	current_aggression = min(current_aggression + aggression_increase_on_hit, 1.0)
	personality_traits["aggressiveness"] = current_aggression
	personality_state["aggressiveness"] = current_aggression
	hostility = min(hostility + 10, 100)
	
	if hostility >= hostility_threshold_for_permanent_hostility and not is_permanently_hostile:
		is_permanently_hostile = true
		current_aggression = 1.0
		personality_traits["aggressiveness"] = 1.0
		personality_state["aggressiveness"] = 1.0
		if dialogue_box:
			dialogue_box.show_text("*ROAR* NO MORE WORDS! ONLY DEATH!")
		can_initiate_dialogue = false
	
	adapt_decision_weights()
	current_health -= amount
	hurt_sound.play()
	animation_player.play("hit_flash")
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	if friendship_level < 3:
		state = "attacking"
		can_attack = true
		attack_timer = 0.0
		if not is_permanently_hostile:
			dialogue_box.show_text(aggressive_hit_responses[randi() % aggressive_hit_responses.size()])
	sprite.play("hurt")
	if current_health <= 0: die()
	elif friendship_level < 3 and player and is_instance_valid(player) and not is_permanently_hostile:
		dialogue_box.show_text("*Scream* You'll pay!")

func die():
	state = "dead"
	death_sound.play()
	sprite.play("death")
	set_physics_process(false)
	await sprite.animation_finished
	queue_free()

func _update_ai_state():
	update_environmental_factors()
	update_mood()
	adapt_decision_weights()
	get_tree().create_timer(ai_update_interval).timeout.connect(_update_ai_state)

func update_environmental_factors():
	environmental_factors = {"time_of_day": _get_time_factor(), "player_proximity": _get_player_proximity_factor(), "health_status": float(current_health) / float(max_health), "recent_interactions": _get_interaction_trend()}

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
	var mood_score = {"angry": personality_state["aggressiveness"] * (1.0 - environmental_factors["health_status"]), "happy": personality_state["playfulness"] * environmental_factors["recent_interactions"], "curious": personality_state["curiosity"] * environmental_factors["player_proximity"], "loyal": personality_state["loyalty"] * (friendship_level / float(max_friendship))}
	var new_mood = mood_score.keys()[mood_score.values().find(mood_score.values().max())]
	var intensity = mood_score[new_mood]
	if new_mood != current_mood:
		mood_intensity = lerp(mood_intensity, intensity, 0.3)
		if mood_intensity < 0.1: current_mood = new_mood
	else:
		mood_intensity = intensity

func adapt_decision_weights():
	ai_decision_weights["attack"]  = current_aggression * (1.0 if current_mood == "angry" else 0.5)
	ai_decision_weights["talk"]    = personality_state["curiosity"] * (1.5 if current_mood == "curious" else 1.0) * (1.0 - current_aggression)
	ai_decision_weights["ally"]    = personality_state["loyalty"] * (2.0 if current_mood == "loyal" else 1.0) * (1.0 - current_aggression)
	ai_decision_weights["tease"]   = personality_state["playfulness"] * (1.8 if current_mood == "happy" else 0.8) * (1.0 - current_aggression)
	ai_decision_weights["retreat"] = 0.5 if environmental_factors["health_status"] < 0.3 else 0.1
	if environmental_factors["time_of_day"] > 0.8: ai_decision_weights["attack"] *= 1.5
	if environmental_factors["health_status"] < 0.3:
		ai_decision_weights["ally"] *= 0.5
		ai_decision_weights["attack"] *= 1.8

func make_ai_decision() -> String:
	if is_permanently_hostile:
		return "attack"
	var decisions = ai_decision_weights.keys()
	var weights = ai_decision_weights.values()
	var total = weights.reduce(func(a, b): return a + b)
	var normalized = weights.map(func(x): return x / total)
	var rand = randf()
	var cumulative = 0.0
	for i in range(normalized.size()):
		cumulative += normalized[i]
		if rand <= cumulative: return decisions[i]
	return decisions[-1]

func execute_ai_decision(decision: String):
	if not can_initiate_dialogue: return
	if is_permanently_hostile:
		state = "attacking"
		return
	face_player()
	match decision:
		"attack":
			if friendship_level < 3 and current_aggression > 0.5:
				state = "attacking"
				dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
				can_initiate_dialogue = false
		"talk":
			if randf() < 0.7: ask_riddle()
			else: initiate_random_dialogue()
			can_initiate_dialogue = false
		"ally":
			if friendship_level >= 3:
				state = "ally"
				dialogue_box.show_text("*Calm* We work together...")
				can_initiate_dialogue = false
		"tease":
			var t = ["*Chuckle* Funny face!", "*Giggle* Humans amuse!", "*Sarcasm* That's best?"]
			dialogue_box.show_text(t[randi() % t.size()])
			can_initiate_dialogue = false
		"retreat":
			if current_health < max_health * 0.3:
				state = "hurt"
				dialogue_box.show_text("*Panting* Not over...")
				can_initiate_dialogue = false

func say_launch_message():
	_send_to_ai_server("Announce presence in ONE short sentence (max 10 words). You're a demon mage.")

func ask_riddle():
	_send_to_ai_server("Speak short riddle (one sentence, max 10 words).")

func initiate_random_dialogue():
	var prompts = [
		"Ask ONE short question (max 8 words).",
		"Tell short story fragment (max 10 words).",
		"Make short chilling observation (max 8 words).",
		"Challenge with short phrase (max 6 words)."
	]
	_send_to_ai_server(prompts[randi() % prompts.size()])

func receive_player_answer(answer: String):
	if is_permanently_hostile:
		state = "attacking"
		return
	if state == "attacking": state = "conversing"
	if state != "waiting" and state != "conversing" and state != "ready": return
	if is_waiting_for_response: return
	face_player()
	state = "waiting"
	analyze_answer_for_friendship(answer)
	_send_to_ai_server(answer)

func analyze_answer_for_friendship(answer: String):
	var lower = answer.to_lower()
	var change = 0
	if lower.contains("please") or lower.contains("thank you"): change = 1
	elif lower.contains("alliance") or lower.contains("friend"): change = 2
	elif lower.contains("wisdom") or lower.contains("power"): change = 1
	elif lower.contains("asshole") or lower.contains("idiot"): change = -1
	elif lower.contains("respect") or lower.contains("honor"): change = 1
	if change != 0: change_friendship(change)

func change_friendship(amount: int):
	var prev = friendship_level
	friendship_level = clamp(friendship_level + amount, 0, max_friendship)
	hostility = clamp(hostility - amount * 15, 0, 100)
	if friendship_level >= max_friendship: become_ally()
	elif amount > 0 and friendship_level > prev and dialogue_box:
		dialogue_box.show_text(friendly_responses[friendship_level - 1])

func become_ally():
	state = "ally"
	if dialogue_box:
		dialogue_box.show_text("*Calm* You're worthy ally... for now.")

func _on_ai_chat_received(message: String):
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	var sentiment = analyze_sentiment(message)
	if conversation_history.size() >= memory_capacity: conversation_history.pop_front()
	conversation_history.append({"message": message, "sentiment": sentiment, "time": Time.get_unix_time_from_system()})
	update_personality_from_response(message, sentiment)
	if dialogue_box: dialogue_box.show_text(message)
	match state:
		"riddle", "waiting": state = "conversing"
		_: state = "ready"

func analyze_sentiment(text: String) -> float:
	var pos = ["ally","friend","wise","powerful","respect"]
	var neg = ["hate","stupid","weak","ridiculous","despise"]
	var lower = text.to_lower()
	var score = 0.0
	for w in pos: if w in lower: score += 0.2
	for w in neg: if w in lower: score -= 0.3
	return clamp(score, -1.0, 1.0)

func update_personality_from_response(message: String, sentiment: float):
	var r = 0.05
	if sentiment > 0.3:
		personality_state["loyalty"] = min(personality_state["loyalty"] + r, 1.0)
		personality_state["playfulness"] = min(personality_state["playfulness"] + r * 0.5, 1.0)
	elif sentiment < -0.3:
		personality_state["aggressiveness"] = min(personality_state["aggressiveness"] + r, 1.0)
		personality_state["curiosity"] = max(personality_state["curiosity"] - r * 0.3, 0.0)
	adapt_decision_weights()

func _on_ai_chat_failed(_error_code: int):
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	if friendship_level > 2: _use_fallback_response("*Calm* Weak magic...")
	else: _use_fallback_response("*Laughter*")

func _on_body_entered(body: Node2D):
	if is_permanently_hostile:
		state = "attacking"
		return
	if body.name == "Player" and state in ["idle","ready"]:
		player = body
		face_player()
		state = "riddle"
		ask_riddle()
	elif body.name == "Player" and state in ["conversing","waiting"]:
		player = body
		face_player()

func _on_timeout():
	if is_waiting_for_response:
		is_waiting_for_response = false
		is_interacting = false
		_stop_thinking_dots()
		if friendship_level > 3: _use_fallback_response("*Yawn* Boring...")
		else: _use_fallback_response("*Echo*")

func _use_fallback_response(text: String):
	if dialogue_box: dialogue_box.show_text(text)
	is_interacting = false
	is_waiting_for_response = false

func get_ai_state_description() -> String:
	return "Mood: {0} | Friendship: {1}/{2} | Hostility: {3} | Aggression: {4} | Permanent: {5}".format([current_mood, friendship_level, max_friendship, hostility, current_aggression, is_permanently_hostile])

func _send_to_ai_server(player_message: String) -> void:
	if not _server_ready:
		_use_fallback_response(fallback_responses[randi() % fallback_responses.size()])
		return
	
	if is_waiting_for_response:
		return
	if _ai_thread != null and _ai_thread.is_alive():
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
		"max_tokens": 40,
		"temperature": 0.7,
		"max_length": 50
	}
	_ai_thread = Thread.new()
	_ai_thread.start(_thread_request.bind(payload))

func _thread_request(payload: Dictionary) -> void:
	var client = HTTPClient.new()
	var err = client.connect_to_host("localhost", 5000)
	if err != OK:
		_ai_thread_done = true
		return
	var waited := 0.0
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		OS.delay_msec(50)
		client.poll()
		waited += 0.05
		if waited > 5.0:
			_ai_thread_done = true
			return
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_ai_thread_done = true
		return
	var body_str = JSON.stringify(payload)
	var headers = ["Content-Type: application/json", "Content-Length: " + str(body_str.length())]
	err = client.request(HTTPClient.METHOD_POST, "/chat", headers, body_str)
	if err != OK:
		_ai_thread_done = true
		return
	waited = 0.0
	while waited < 60.0:
		OS.delay_msec(100)
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_CONNECTED:
			break
		elif status == HTTPClient.STATUS_DISCONNECTED:
			_ai_thread_done = true
			return
		waited += 0.1
	var response_body := PackedByteArray()
	waited = 0.0
	while waited < 20.0:
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				response_body.append_array(chunk)
				waited = 0.0
			else:
				OS.delay_msec(50)
				waited += 0.05
		else:
			break
	if response_body.size() > 0:
		var json = JSON.new()
		var text = response_body.get_string_from_utf8()
		if json.parse(text) == OK:
			var data = json.get_data()
			_ai_thread_result = data.get("response", "")
			_ai_thread_new_hostility = int(data.get("new_hostility", hostility))
	_ai_thread_done = true

func _process(_delta: float) -> void:
	if not _ai_thread_done or _ai_thread == null:
		return
	_ai_thread.wait_to_finish()
	_ai_thread = null
	_ai_thread_done = false
	_stop_thinking_dots()
	if _ai_thread_result != "":
		if _ai_thread_new_hostility >= 0:
			hostility = _ai_thread_new_hostility
			friendship_level = clamp(5 - int(hostility / 20.0), 0, max_friendship)
		_on_ai_chat_received(_ai_thread_result)
	else:
		_on_ai_chat_failed(-1)
	_ai_thread_result = ""
	_ai_thread_new_hostility = -1

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
