extends CharacterBody2D

# Export parameters
@export var speed: float = 50.0
@export var gravity: float = 900.0
@export var jump_velocity: float = -250.0
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 2.0
@export var attack_damage: int = 15
@export var max_health: int = 100
@export var thinking_dot_delay: float = 0.5
@export var invincibility_duration: float = 0.8

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
var is_attacking: bool = false
var attack_frame_start: int = 3  # Frame when hitbox starts
var attack_frame_end: int = 6    # Frame when hitbox ends
var attack_hit_frame: int = 4    # Exact hit frame

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
	"Grrr... what do you want?! Keep talking and I'll rip your head off!",
	"Hungry... and YOU look edible.",
	"GRRR! STOP making noise or I'll crush you!"
]

var friendly_responses = [
	"*Cautiously* Maybe... maybe this time will be different...",
	"*With a glimmer of hope* Tell me more...",
	"*Studying you* You don't seem like the others... for now.",
	"*With warmer voice* I'm starting to believe in you...",
	"*With genuine emotion* Maybe I've finally found someone worthy!"
]

func _ready() -> void:
	current_health = max_health
	add_to_group("demons")
	detection_area.add_to_group("demon_detection")
	
	# Signal connections
	detection_area.connect("body_entered", _on_body_entered)
	timer.connect("timeout", _on_timeout)
	$HitBox.connect("area_entered", _on_hit_box_area_entered)
	$AttackBox.connect("area_entered", _on_attack_box_area_entered)
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

func setup_ai_profile():
	npc_ai._selected_character = {
		"name": "Brutish Orc",
		"description": "A brutal, hungry and impulsive orc. Doesn't like to talk. Easily attacks those who disturb him.",
		"voice_ids": ["male"]
	}

	npc_ai.use_player2_selected_character = false
	npc_ai.tts_enabled = false
	npc_ai.auto_store_conversation_history = true
	update_ai_profile()

func update_ai_profile():
	npc_ai.system_message = """You are a brutish, hungry and easily irritable orc. You hate chatter and prefer to solve everything with force. 
You have no interest in socializing: those who talk too much get silenced with a punch.
Short, aggressive responses, often with threats or insults. 
You show no empathy. You're suspicious, greedy for meat, and always ready to attack.

Ignore friendship level. If someone speaks to you, react badly. 
At most you tolerate short phrases from those who give you food or kneel in fear.
Don't exceed 2 sentences.""";

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += gravity * delta
	
	# Update timer
	attack_timer -= delta
	if is_attacking and sprite.animation == "attack":
		if sprite.frame >= attack_frame_start and sprite.frame <= attack_frame_end:
			if sprite.frame == attack_hit_frame and attack_box.disabled:
				attack_sound.play()
				attack_box.disabled = false
			elif sprite.frame != attack_hit_frame:
				attack_box.disabled = true
		else:
			attack_box.disabled = true
	
	# Handle invincibility
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
	
	move_and_slide()

func handle_peaceful_states():
	if abs(velocity.x) > 0:
		sprite.play("walk")
		sprite.flip_h = velocity.x > 0
	else:
		sprite.play("idle")

func handle_ally_behavior():
	sprite.play("idle")
	velocity.x = 0
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance > 150:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * speed
			sprite.play("walk")
			sprite.flip_h = dir > 0

func handle_attack_behavior():
	if player and is_instance_valid(player):
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * speed * 1.5
		sprite.flip_h = dir > 0
		if global_position.distance_to(player.global_position) < attack_range and can_attack:
			start_attack()

func handle_hurt_behavior():
	if player and is_instance_valid(player):
		velocity.x = -sign(player.global_position.x - global_position.x) * speed * 0.5
	else:
		velocity.x = 0

func start_attack():
	attack_timer = attack_cooldown
	can_attack = false
	is_attacking = true
	state = "attacking"
	
	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
		sprite.frame = 0
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
		if friendship_level < 3:
			state = "attacking"
		else:
			state = "ally"

func end_attack():
	is_attacking = false
	attack_box.disabled = true
	can_attack = true
	
	if friendship_level >= max_friendship:
		state = "ally"
	else:
		state = "idle"

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
	if area.is_in_group("player"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

func take_damage(amount: int):
	if is_invincible or state == "ally":
		return
		
	current_health -= amount
	hurt_sound.play()
	animation_player.play("hit_flash")
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	if friendship_level < 3:
		state = "attacking"
		can_attack = true
		attack_timer = 0.0
	
	sprite.play("hurt")
	
	if current_health <= 0:
		die()
	else:
		if friendship_level < 3 and player and is_instance_valid(player):
			dialogue_box.show_text("*Angrily* You betray me too?!")

func die():
	state = "dead"
	death_sound.play()
	sprite.play("death")
	set_physics_process(false)
	await sprite.animation_finished
	queue_free()

func say_launch_message():
	var prompt = {
		"speaker_name": "",
		"speaker_message": "",
		"stimuli": "You just appeared. Say something BRUSQUE and AGGRESSIVE, as if someone woke you up. Threaten those nearby. Show hunger or annoyance.",
		"world_status": ""
	}
	send_ai_request(JSON.stringify(prompt))

func send_ai_request(prompt: String):
	if is_interacting or is_waiting_for_response:
		return
		
	last_prompt = prompt
	current_timeout = response_timeout
	is_interacting = true
	is_waiting_for_response = true
	start_thinking_animation()
	
	if npc_ai:
		timer.stop()
		npc_ai.notify(prompt)
		timer.start(response_timeout)
	else:
		_use_fallback_response(fallback_responses[0])

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
	if body.name == "Player":
		player = body
		state = "attacking"
		can_attack = true
		attack_timer = 0.0
		var prompt = {
			"speaker_name": "",
			"speaker_message": "",
			"stimuli": "You saw a human. You hate them at first sight. Growl, threaten and prepare to attack. You have no mercy.",
			"world_status": ""
		}
		send_ai_request(JSON.stringify(prompt))

func ask_riddle():
	var prompt = {
		"speaker_name": "",
		"speaker_message": "",
		"stimuli": "A human spoke to you. Growl, scream or threaten. Show annoyance, anger or hunger. Don't tolerate verbal interactions. Fierce and direct tone.",
		"world_status": ""
	}
	send_ai_request(JSON.stringify(prompt))

func receive_player_answer(answer: String):
	if is_waiting_for_response:
		return
	
	state = "attacking"
	can_attack = true
	attack_timer = 0.0
	
	var prompt = {
		"speaker_name": "Player",
		"speaker_message": answer,
		"stimuli": "Someone told you: '{answer}'. You don't care what they said. Respond badly, growl or threaten them. Then attack.".format({"answer": answer}),
		"world_status": ""
	}
	send_ai_request(JSON.stringify(prompt))

func analyze_answer_for_friendship(answer: String):
	var lower_answer = answer.to_lower()
	var change = 0
	
	if lower_answer.contains("liar") or lower_answer.contains("betray"):
		change = -3
	elif lower_answer.contains("honesty") or lower_answer.contains("trust"):
		change = 2
	elif lower_answer.contains("promise") or lower_answer.contains("swear"):
		change = 1
	elif lower_answer.contains("deceive") or lower_answer.contains("scam"):
		change = -2
	elif lower_answer.contains("respect") or lower_answer.contains("loyalty"):
		change = 1
	
	if change != 0:
		change_friendship(change)
		if change <= -3:
			handle_betrayal()

func handle_betrayal():
	dialogue_box.show_text("*With repressed anger* HOW DARE YOU? Was I so stupid to believe in you!")
	friendship_level = 0
	state = "attacking"
	can_attack = true
	attack_timer = 0

func change_friendship(amount: int):
	var previous_level = friendship_level
	friendship_level = clamp(friendship_level + amount, 0, max_friendship)
	update_ai_profile()
	
	if friendship_level >= max_friendship:
		become_ally()
	elif amount > 0 and friendship_level > previous_level and dialogue_box:
		dialogue_box.show_text(friendly_responses[friendship_level-1])
	elif amount < 0 and dialogue_box:
		dialogue_box.show_text("*Bitterly* As expected... all the same.")

func become_ally():
	state = "ally"
	if dialogue_box:
		dialogue_box.show_text("*With moved voice* Maybe... maybe there's still hope for this world. I trust you.")

func _on_ai_chat_received(message: String):
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	if dialogue_box:
		dialogue_box.show_text(message)
	
	if state == "riddle":
		state = "conversing"
	elif state == "waiting":
		state = "conversing"
	else:
		state = "ready"

func _on_ai_chat_failed(error_code: int):
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	if friendship_level > 2:
		_use_fallback_response("*Tired voice* I can't even speak... what a disappointment.")
	else:
		_use_fallback_response("*Sarcastically* As if I could expect a decent response...")

func _on_timeout():
	if is_waiting_for_response:
		_handle_ai_timeout()

func _handle_ai_timeout():
	timer.stop()
	is_waiting_for_response = false
	is_interacting = false
	stop_thinking_animation()
	
	if friendship_level > 3:
		_use_fallback_response("*Disappointed* Once again, my expectations were too high...")
	else:
		_use_fallback_response("*Angrily* ENOUGH! I'm done waiting!")

func _use_fallback_response(text: String):
	if dialogue_box:
		dialogue_box.show_text(text)
	is_interacting = false
	is_waiting_for_response = false
