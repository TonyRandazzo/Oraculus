extends CharacterBody2D

# Export parameters
@export var speed: float = 0.0  # Doesn't move
@export var gravity: float = 0.0  # No gravity
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 2.0
@export var attack_damage: int = 15
@export var max_health: int = 100
@export var thinking_dot_delay: float = 0.5
@export var invincibility_duration: float = 0.8
@export var attack_animation_fps: float = 10.0
@export var ai_update_interval: float = 3.0
@export var memory_capacity: int = 5
@export var aggression_increase_on_hit: float = 0.5  # Increases aggression more when hit
@export var base_aggression: float = 0.1  # Very low by default

@export var personality_traits: Dictionary = {
	"aggressiveness": 0.1,  # Very low
	"curiosity": 0.8,       # Very curious
	"playfulness": 0.7,     # Playful
	"loyalty": 0.6          # More loyal
}

# Attack variables
var is_attacking: bool = false
var attack_frame_start: int = 6
var attack_frame_end: int = 16
var attack_hit_frame: int = 10
var players_in_attack_area: Array = []  # Tracks players in attack area

# State variables
var player: Node2D = null
var state: String = "idle"
var attack_timer: float = 0.0
var is_interacting: bool = false
var response_timeout: float = 30.0
var current_timeout: float = 0.0
var last_prompt: String = ""
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

# Advanced AI system
var conversation_history: Array = []
var personality_state: Dictionary = {}
var current_mood: String = "neutral"
var mood_intensity: float = 0.5
var environmental_factors: Dictionary = {}
var ai_decision_weights: Dictionary = {}

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var npc_ai: Player2AINPC = $Player2AINPC
@onready var dialogue_box = $Dialogue
@onready var hit_box = $HitBox/CollisionShape2D
@onready var attack_box = $AttackBox/CollisionShape2D
@onready var animation_player = $AnimationPlayer
@onready var hurt_sound = $HurtSound
@onready var attack_sound = $AttackSound
@onready var death_sound = $DeathSound

# Response database
var fallback_responses = [
	"*Chuckling* I challenge you with a riddle!",
	"*Smiling* What a curious thing you ask me!",
	"*With interest* Tell me more, mortal..."
]

var friendly_responses = [
	"*Sighing* What a pleasure to talk with an intelligent human...",
	"*With interest* Keep talking, mortal...",
	"*Giggling* You're funny, for a human",
	"*With calm voice* Maybe I was wrong about humans...",
	"*Smiling* You've earned my respect, little mortal"
]

var attack_phrases = [
	"AHAHAHAHAHAHHAHA",
	"Die everyone!",
	"Taste this hate bomb!",
	"Burn! Burn! Burn!"
]

var aggressive_hit_responses = [
	"*In pain* Why are you hurting me?",
	"*Angrily* Now you've really irritated me!",
	"I'll kill you!",
	"Why are you forcing me to do this?"
]

func _ready() -> void:
	current_health = max_health
	current_aggression = base_aggression
	personality_traits["aggressiveness"] = base_aggression
	
	add_to_group("demons")
	detection_area.add_to_group("demon_detection")
	
	# Signal connections
	detection_area.connect("body_entered", _on_body_entered)
	timer.connect("timeout", _on_timeout)
	$HitBox.connect("area_entered", _on_hit_box_area_entered)
	$AttackBox.connect("area_entered", _on_attack_box_area_entered)
	$AttackBox.connect("area_exited", _on_attack_box_area_exited)  # Added to detect exit
	sprite.connect("animation_finished", _on_animation_finished)
	
	if npc_ai:
		setup_ai_profile()
		if npc_ai.has_signal("chat_received"):
			npc_ai.chat_received.connect(_on_ai_chat_received)
		if npc_ai.has_signal("chat_failed"):
			npc_ai.chat_failed.connect(_on_ai_chat_failed)
	
	sprite.play("idle")
	await get_tree().create_timer(1.0).timeout
	say_launch_message()
	attack_box.disabled = true
	
	# Initialize advanced AI system
	initialize_personality()
	_update_ai_state()

func setup_ai_profile():
	npc_ai._selected_character = {
		"name": "Demon",
		"description": "Friendly and cunning demon who hates fighting but can defend itself if attacked",
		"voice_ids": ["demon_voice_1", "demon_voice_2"]
	}
	npc_ai.use_player2_selected_character = false
	npc_ai.tts_enabled = false
	npc_ai.auto_store_conversation_history = true
	update_ai_profile()

func update_ai_profile():
	pass

func initialize_personality():
	personality_state = personality_traits.duplicate()
	personality_state["patience"] = 1.0 - personality_traits["aggressiveness"]
	personality_state["social"] = (personality_traits["curiosity"] + personality_traits["playfulness"]) / 2.0
	
	ai_decision_weights = {
		"attack": current_aggression,
		"talk": personality_traits["curiosity"] * 1.5,  # Talks much more
		"ally": personality_traits["loyalty"],
		"tease": personality_traits["playfulness"],
		"retreat": 0.1
	}

func _physics_process(delta: float) -> void:
	# Never moves, so no gravity or movement
	velocity = Vector2.ZERO
	
	# If player disappeared, return to idle
	if player and not is_instance_valid(player):
		player = null
		state = "idle"
	
	# Update timer
	attack_timer -= delta
	
	# Attack handling - applies continuous damage when attacking
	if is_attacking and sprite.animation == "attack":
		attack_box.disabled = false  # Hitbox is always active during attack
		
		# Play sound only on specific frame (not continuously)
		if sprite.frame == attack_hit_frame:
			attack_sound.play()
			# Choose random attack phrase only occasionally
			if attack_phrases.size() > 0 and randf() < 0.1:  # Reduced frequency to 10%
				dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
		
		# Apply continuous damage ONLY to players actually in attack area
		for player_in_area in players_in_attack_area:
			if is_instance_valid(player_in_area) and player_in_area.has_method("take_damage"):
				# Calculate damage per second
				var damage_per_second = attack_damage * (1.0 + current_aggression * 0.5)
				player_in_area.take_damage(damage_per_second * delta)
	else:
		# If not attacking, disable hitbox
		attack_box.disabled = true
	
	# Invincibility handling
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			animation_player.stop()
			sprite.modulate = Color(1, 1, 1, 1)
	
	# "Thinking" animation
	if is_waiting_for_response:
		thinking_timer -= delta
		if thinking_timer <= 0:
			dot_count += 1
			thinking_timer = thinking_dot_delay
			update_thinking_dots()
	
	# Dialogue cooldown handling
	if not can_initiate_dialogue:
		dialogue_cooldown_timer -= delta
		if dialogue_cooldown_timer <= 0:
			can_initiate_dialogue = true
			dialogue_cooldown_timer = 5.0
	
	# AI update
	last_ai_update += delta
	if player and state in ["idle", "ready", "conversing"] and not is_waiting_for_response and can_initiate_dialogue:
		if last_ai_update > ai_update_interval:
			last_ai_update = 0.0
			var decision = make_ai_decision()
			execute_ai_decision(decision)

	# Main state machine
	match state:
		"idle", "ready", "riddle", "waiting", "conversing":
			handle_peaceful_states()
		"ally":
			handle_ally_behavior()
		"attacking":
			handle_attack_behavior()
		"hurt":
			handle_hurt_behavior()

func _on_attack_box_area_entered(area: Area2D):
	# Verify area is actually from player
	if area.is_in_group("hit_player") or area.get_parent().name == "Player":
		var player_node = area.get_parent()
		if player_node.has_method("take_damage") and not players_in_attack_area.has(player_node):
			players_in_attack_area.append(player_node)
			print("Player entered attack area: ", player_node.name)

func _on_attack_box_area_exited(area: Area2D):
	# Verify area is actually from player
	if area.is_in_group("hit_player") or area.get_parent().name == "Player":
		var player_node = area.get_parent()
		if players_in_attack_area.has(player_node):
			players_in_attack_area.erase(player_node)
			print("Player left attack area: ", player_node.name)

func send_structured_request(data: Dictionary):
	if is_interacting or is_waiting_for_response:
		return
		
	face_player()  # Turn towards player before starting dialogue
	last_prompt = JSON.stringify(data)
	current_timeout = response_timeout
	is_interacting = true
	is_waiting_for_response = true
	start_thinking_animation()
	
	if npc_ai:
		timer.stop()
		npc_ai.notify(JSON.stringify(data))
		timer.start(response_timeout)
	else:
		_use_fallback_response(fallback_responses[0])

func handle_peaceful_states():
	sprite.play("idle")

func handle_ally_behavior():
	sprite.play("idle")

func handle_attack_behavior():
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance < attack_range and can_attack:
			start_attack()
		else:
			# Keep showing attack animation even if player is out of range
			if not is_attacking:
				start_attack()

func handle_hurt_behavior():
	pass  # Doesn't move even when hurt

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
	
	attack_box.disabled = false  # Hitbox always active during attack

func face_player():
	if player and is_instance_valid(player):
		var direction = sign(player.global_position.x - global_position.x)
		sprite.flip_h = direction > 0 

func _on_animation_finished():
	if sprite.animation == "attack":
		if state == "attacking":  # If still in attack mode, keep attacking
			sprite.play("attack")
			sprite.frame = 0
		else:
			end_attack()
	elif sprite.animation == "hurt":
		if friendship_level < 3 and current_aggression > 0.5:
			state = "attacking"
			sprite.play("attack")
		else:
			state = "ally"

func end_attack():
	is_attacking = false
	attack_box.disabled = true
	# DON'T clear array here - let it handle automatically with area_exited
	
	if player and global_position.distance_to(player.global_position) < attack_range * 1.5 and current_aggression > 0.5:
		# If still aggressive and player is close, keep attacking
		start_attack()
	elif friendship_level >= max_friendship:
		state = "ally"
	else:
		state = "idle"
	
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

func take_damage(amount: int):
	if is_invincible or state == "ally":
		return
		
	# Greatly increases aggression when hit
	current_aggression = min(current_aggression + aggression_increase_on_hit, 1.0)
	personality_traits["aggressiveness"] = current_aggression
	personality_state["aggressiveness"] = current_aggression
	adapt_decision_weights()
	
	current_health -= amount
	hurt_sound.play()
	animation_player.play("hit_flash")
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	# Reaction when hit
	state = "attacking"
	can_attack = true
	attack_timer = 0.0
	start_attack()  # Force immediate attack
	dialogue_box.show_text(aggressive_hit_responses[randi() % aggressive_hit_responses.size()])
	
	sprite.play("hurt")
	
	if current_health <= 0:
		die()

func die():
	state = "dead"
	death_sound.play()
	sprite.play("death")
	set_physics_process(false)
	await sprite.animation_finished
	queue_free()

# Advanced AI system
func _update_ai_state():
	update_environmental_factors()
	update_mood()
	adapt_decision_weights()
	get_tree().create_timer(ai_update_interval).timeout.connect(_update_ai_state)

func update_environmental_factors():
	environmental_factors = {
		"time_of_day": _get_time_factor(),
		"player_proximity": _get_player_proximity_factor(),
		"health_status": float(current_health) / float(max_health),
		"recent_interactions": _get_interaction_trend()
	}

func _get_time_factor() -> float:
	var time = fmod(Time.get_unix_time_from_system() / 43200.0, 1.0)
	return abs(time - 0.5) * 2.0

func _get_player_proximity_factor() -> float:
	if not player or not is_instance_valid(player):
		return 0.0
	var distance = global_position.distance_to(player.global_position)
	return 1.0 - clamp(distance / 500.0, 0.0, 1.0)

func _get_interaction_trend() -> float:
	if conversation_history.size() == 0:
		return 0.5
	var positive_count = conversation_history.filter(func(x): return x.get("sentiment", 0) > 0).size()
	return float(positive_count) / conversation_history.size()

func update_mood():
	var mood_score = {
		"angry": personality_state["aggressiveness"] * (1.0 - environmental_factors["health_status"]),
		"happy": personality_state["playfulness"] * environmental_factors["recent_interactions"],
		"curious": personality_state["curiosity"] * environmental_factors["player_proximity"],
		"loyal": personality_state["loyalty"] * (friendship_level / float(max_friendship))
	}
	
	current_mood = mood_score.keys()[mood_score.values().find(mood_score.values().max())]
	mood_intensity = mood_score[current_mood]

func adapt_decision_weights():
	ai_decision_weights["attack"] = current_aggression * (1.0 if current_mood == "angry" else 0.5)
	ai_decision_weights["talk"] = personality_state["curiosity"] * (1.5 if current_mood == "curious" else 1.0) * (1.0 - current_aggression)
	ai_decision_weights["ally"] = personality_state["loyalty"] * (2.0 if current_mood == "loyal" else 1.0) * (1.0 - current_aggression)
	ai_decision_weights["tease"] = personality_state["playfulness"] * (1.8 if current_mood == "happy" else 0.8) * (1.0 - current_aggression)
	ai_decision_weights["retreat"] = 0.5 if environmental_factors["health_status"] < 0.3 else 0.1
	
	if environmental_factors["time_of_day"] > 0.8:
		ai_decision_weights["attack"] *= 1.5
	if environmental_factors["health_status"] < 0.3:
		ai_decision_weights["ally"] *= 0.5
		ai_decision_weights["attack"] *= 1.8

func make_ai_decision() -> String:
	var decisions = ai_decision_weights.keys()
	var weights = ai_decision_weights.values()
	
	var total = weights.reduce(func(a, b): return a + b)
	var normalized = weights.map(func(x): return x / total)
	
	var rand = randf()
	var cumulative = 0.0
	for i in range(normalized.size()):
		cumulative += normalized[i]
		if rand <= cumulative:
			return decisions[i]
	
	return decisions[-1]

func execute_ai_decision(decision: String):
	if not can_initiate_dialogue:
		return
	
	face_player()  # Turn towards player even for AI decisions
	
	match decision:
		"attack":
			if friendship_level < 3:
				state = "attacking"
				dialogue_box.show_text(attack_phrases[randi() % attack_phrases.size()])
				can_initiate_dialogue = false
		"talk":
			if randf() < 0.7:
				ask_riddle()
			else:
				initiate_random_dialogue()
			can_initiate_dialogue = false
		"ally":
			if friendship_level >= 3:
				state = "ally"
				dialogue_box.show_text("*Calm voice* Perhaps we can work together...")
				can_initiate_dialogue = false
		"tease":
			var teasings = [
				"*Chuckling* What a funny face you have!",
				"*Giggling* Humans are so amusing!",
				"*Sarcastically* Really? That's the best you can do?"
			]
			dialogue_box.show_text(teasings[randi() % teasings.size()])
			can_initiate_dialogue = false
		"retreat":
			if current_health < max_health * 0.3:
				state = "hurt"
				dialogue_box.show_text("*Panting voice* This... isn't... over...")
				can_initiate_dialogue = false

# Dialogue system
func say_launch_message():
	var request_data = {
		"action": "launch",
		"friendship_level": friendship_level,
		"stimuli": "Announce your presence with a friendly but mysterious phrase"
	}
	send_structured_request(request_data)

func ask_riddle():
	var request_data = {
		"action": "riddle", 
		"friendship_level": friendship_level,
		"stimuli": "Speak a riddle for the human"
	}
	send_structured_request(request_data)

func initiate_random_dialogue():
	var prompts = [
		{"action": "philosophy", "stimuli": "Ask a deep philosophical question"},
		{"action": "story", "stimuli": "Tell a fragment of your story"},
		{"action": "observation", "stimuli": "Make an observation about the environment"},
		{"action": "challenge", "stimuli": "Challenge the player to prove their worth"}
	]
	var selected = prompts[randi() % prompts.size()]
	selected["friendship_level"] = friendship_level
	send_structured_request(selected)

func receive_player_answer(answer: String):
	if state == "attacking":
		state = "conversing"
	
	if state != "waiting" and state != "conversing" and state != "ready":
		return
		
	if is_waiting_for_response:
		return
	
	face_player()  # Turn towards player when receiving an answer
	state = "waiting"
	analyze_answer_for_friendship(answer)
	
	var request_data = {
		"action": "response",
		"friendship_level": friendship_level,
		"player_message": answer,
		"stimuli": "Respond to the player's message"
	}
	send_structured_request(request_data)

func analyze_answer_for_friendship(answer: String):
	var lower_answer = answer.to_lower()
	var change = 0
	
	if lower_answer.contains("please") or lower_answer.contains("thank you"):
		change = 1
	elif lower_answer.contains("alliance") or lower_answer.contains("friend"):
		change = 2
	elif lower_answer.contains("wisdom") or lower_answer.contains("power"):
		change = 1
	elif lower_answer.contains("asshole") or lower_answer.contains("idiot"):
		change = -1
	elif lower_answer.contains("respect") or lower_answer.contains("honor"):
		change = 1
	
	if change != 0:
		change_friendship(change)

func change_friendship(amount: int):
	var previous_level = friendship_level
	friendship_level = clamp(friendship_level + amount, 0, max_friendship)
	
	update_ai_profile()
	
	if friendship_level >= max_friendship:
		become_ally()
	elif amount > 0 and friendship_level > previous_level and dialogue_box:
		dialogue_box.show_text(friendly_responses[friendship_level-1])

func become_ally():
	state = "ally"
	if dialogue_box:
		dialogue_box.show_text("*Calm voice* You've proven your worth, human. Consider me your ally... for now.")

func _on_ai_chat_received(message: String):
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	var sentiment = analyze_sentiment(message)
	var interaction = {
		"message": message,
		"sentiment": sentiment,
		"time": Time.get_unix_time_from_system()
	}
	
	if conversation_history.size() >= memory_capacity:
		conversation_history.pop_front()
	conversation_history.append(interaction)
	
	update_personality_from_response(message, sentiment)
	
	if dialogue_box:
		dialogue_box.show_text(message)
	
	match state:
		"riddle":
			state = "conversing"
		"waiting":
			state = "conversing"
		_:
			state = "ready"

func analyze_sentiment(text: String) -> float:
	var positive_words = ["ally", "friend", "wise", "powerful", "respect"]
	var negative_words = ["hate", "stupid", "weak", "ridiculous", "despise"]
	
	var lower_text = text.to_lower()
	var score = 0.0
	
	for word in positive_words:
		if word in lower_text:
			score += 0.2
	
	for word in negative_words:
		if word in lower_text:
			score -= 0.3
	
	return clamp(score, -1.0, 1.0)

func update_personality_from_response(message: String, sentiment: float):
	var change_rate = 0.05
	
	if sentiment > 0.3:
		personality_state["loyalty"] = min(personality_state["loyalty"] + change_rate, 1.0)
		personality_state["playfulness"] = min(personality_state["playfulness"] + change_rate * 0.5, 1.0)
	elif sentiment < -0.3:
		personality_state["aggressiveness"] = min(personality_state["aggressiveness"] + change_rate, 1.0)
		personality_state["curiosity"] = max(personality_state["curiosity"] - change_rate * 0.3, 0.0)
	
	adapt_decision_weights()

func _on_ai_chat_failed(error_code: int):
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	if friendship_level > 2:
		_use_fallback_response("*Calm voice* My magical energies are weak...")
	else:
		_use_fallback_response("*Stifled laughter*")

func start_thinking_animation():
	dot_count = 0
	thinking_timer = thinking_dot_delay
	update_thinking_dots()

func update_thinking_dots():
	if dialogue_box:
		var dots = ".".repeat(dot_count % 4)
		dialogue_box.show_text("Thinking" + dots)

func stop_thinking_animation():
	thinking_timer = 0.0
	dot_count = 0

func _on_body_entered(body: Node2D):
	if body.name == "Player" and (state == "idle" or state == "ready"):
		player = body
		face_player()  # Turn towards player when detected
		state = "riddle"
		ask_riddle()
	elif body.name == "Player" and (state == "conversing" or state == "waiting"):
		player = body
		face_player() 

func _on_timeout():
	if is_waiting_for_response:
		_handle_ai_timeout()

func _handle_ai_timeout():
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	if friendship_level > 3:
		_use_fallback_response("*Yawning* You're boring me, human...")
	else:
		_use_fallback_response("*Evil echo*")

func _use_fallback_response(text: String):
	if dialogue_box:
		dialogue_box.show_text(text)
	is_interacting = false
	is_waiting_for_response = false

# Utility functions
func get_ai_state_description() -> String:
	return """
	Demon AI State:
	Mood: {mood} (Intensity: {intensity})
	Personality: {personality}
	Friendship: {friendship}
	Environment: {environment}
	Decision Weights: {weights}
	Aggression: {aggression}
	""".format({
		"mood": current_mood,
		"intensity": mood_intensity,
		"personality": personality_state,
		"friendship": str(friendship_level) + "/" + str(max_friendship),
		"environment": environmental_factors,
		"weights": ai_decision_weights,
		"aggression": current_aggression
	})
