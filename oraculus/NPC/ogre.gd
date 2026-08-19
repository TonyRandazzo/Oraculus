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

var player: Node2D = null
var state: String = "idle"
var attack_timer: float = 0.0
var is_interacting: bool = false
@export var npc_name: String = "Orco"
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
var is_attacking: bool = false
var attack_frame_start: int = 3
var attack_frame_end: int = 6
var attack_hit_frame: int = 4

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
	"GRRR! What?!",
	"Hungry... you look edible!",
	"GRR! Stop noise!"
]

var friendly_responses = [
	"*Cautious* Maybe...",
	"*Hope* Tell me more...",
	"*Studying* Not like others...",
	"*Warm* I believe you!",
	"*Emotional* Worthy!"
]

func _ready() -> void:
	current_health = max_health
	add_to_group("demons")
	detection_area.add_to_group("demon_detection")
	detection_area.connect("body_entered", _on_body_entered)
	timer.connect("timeout", _on_timeout)
	$HitBox.connect("area_entered", _on_hit_box_area_entered)
	$AttackBox.connect("area_entered", _on_attack_box_area_entered)
	sprite.connect("animation_finished", _on_animation_finished)
	sprite.play("idle")
	attack_box.disabled = true
	
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

func _physics_process(delta: float) -> void:
	_process_server_timeout(delta)
	
	velocity.y += gravity * delta
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
	
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			animation_player.stop()
			sprite.modulate = Color(1, 1, 1, 1)
	
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
	
	if is_on_floor() and player and is_instance_valid(player) and abs(global_position.y - player.global_position.y) < 30:
		if abs(global_position.x - player.global_position.x) < 20:
			var push_dir = sign(global_position.x - player.global_position.x)
			if push_dir == 0:
				push_dir = 1
			velocity.x = push_dir * speed * 2.0

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
		
		if is_on_floor() and abs(global_position.y - player.global_position.y) < 30:
			if abs(global_position.x - player.global_position.x) < 20:
				var push_dir = sign(global_position.x - player.global_position.x)
				if push_dir == 0:
					push_dir = 1
				velocity.x = push_dir * speed * 2.0

func handle_attack_behavior():
	if player and is_instance_valid(player):
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * speed * 1.5
		sprite.flip_h = dir > 0
		
		if is_on_floor() and abs(global_position.y - player.global_position.y) < 30:
			if abs(global_position.x - player.global_position.x) < 20:
				var push_dir = sign(global_position.x - player.global_position.x)
				if push_dir == 0:
					push_dir = 1
				velocity.x = push_dir * speed * 2.0
		
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
		var p = area.get_parent()
		if p.has_method("take_damage"):
			p.take_damage(attack_damage)

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
			dialogue_box.show_text("*Angry* You betray?!")

func die():
	state = "dead"
	death_sound.play()
	sprite.play("death")
	set_physics_process(false)
	await sprite.animation_finished
	queue_free()

func say_launch_message():
	_send_to_ai_server("Announce presence in ONE short sentence (max 10 words). Angry, hungry, aggressive orc.")

func ask_riddle():
	_send_to_ai_server("Growl or threaten in ONE short sentence (max 8 words). Angry orc.")

func receive_player_answer(answer: String):
	if is_waiting_for_response:
		return
	state = "attacking"
	can_attack = true
	attack_timer = 0.0
	_send_to_ai_server("Someone said: '" + answer + "'. Respond with ONE short angry growl (max 8 words).")

func analyze_answer_for_friendship(answer: String):
	var lower_answer = answer.to_lower()
	var change = 0
	if lower_answer.contains("liar") or lower_answer.contains("betray"): change = -3
	elif lower_answer.contains("honesty") or lower_answer.contains("trust"): change = 2
	elif lower_answer.contains("promise") or lower_answer.contains("swear"): change = 1
	elif lower_answer.contains("deceive") or lower_answer.contains("scam"): change = -2
	elif lower_answer.contains("respect") or lower_answer.contains("loyalty"): change = 1
	if change != 0:
		change_friendship(change)
		if change <= -3:
			handle_betrayal()

func handle_betrayal():
	dialogue_box.show_text("*Anger* HOW DARE YOU?!")
	friendship_level = 0
	state = "attacking"
	can_attack = true
	attack_timer = 0

func change_friendship(amount: int):
	var previous_level = friendship_level
	var prev_hostility = hostility
	friendship_level = clamp(friendship_level + amount, 0, max_friendship)
	hostility = clamp(hostility - amount * 15, 0, 100)
	FeedbackPopup.show_stat_change(self, friendship_level - previous_level, hostility - prev_hostility)
	if friendship_level >= max_friendship:
		become_ally()
	elif amount > 0 and friendship_level > previous_level and dialogue_box:
		dialogue_box.show_text(friendly_responses[friendship_level - 1])
	elif amount < 0 and dialogue_box:
		dialogue_box.show_text("*Bitter* All the same...")

func become_ally():
	state = "ally"
	if dialogue_box:
		dialogue_box.show_text("*Moved* I trust you...")

func _on_ai_chat_received(message: String):
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	if dialogue_box:
		dialogue_box.show_text(message)
	if state == "riddle" or state == "waiting":
		state = "conversing"
	else:
		state = "ready"

func _on_ai_chat_failed(_error_code: int):
	is_waiting_for_response = false
	is_interacting = false
	_stop_thinking_dots()
	if friendship_level > 2:
		_use_fallback_response("*Tired* Can't speak...")
	else:
		_use_fallback_response("*Sarcasm* Expecting decent response?")

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player = body
		state = "attacking"
		can_attack = true
		attack_timer = 0.0
		_send_to_ai_server("Saw human. Hate them. ONE short angry growl (max 8 words).")

func _on_timeout():
	if is_waiting_for_response:
		is_waiting_for_response = false
		is_interacting = false
		_stop_thinking_dots()
		if friendship_level > 3:
			_use_fallback_response("*Disappointed* Expectations too high...")
		else:
			_use_fallback_response("*Angry* ENOUGH waiting!")

func _use_fallback_response(text: String):
	if dialogue_box: dialogue_box.show_text(text)
	is_interacting = false
	is_waiting_for_response = false

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
