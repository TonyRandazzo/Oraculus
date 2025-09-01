extends CharacterBody2D

# Riferimenti ai nodi
@onready var player_detection = $Area2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_box = $AttackBox
@onready var animation_player = $AnimationPlayer
@onready var animated_sprite = $AnimatedSprite2D
@onready var dialogue_system = $Dialogue
@onready var hurt_audio = $Hurt
@onready var death_audio = $Death
@onready var attack_audio = $Attack
@onready var walk_audio = $Walk
@onready var jump_audio = $Jump
@onready var timer = $Timer
@onready var player2ai_npc = $Player2AINPC

# Statistiche NPC
var max_health = 150
var current_health = 150
var attack_damage = 25
var move_speed = 80.0
var jump_force = -300.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Stati e comportamento
var player_reference = null
var is_attacking = false
var can_attack = true
var is_chasing = false
var last_direction = 1
var dialogue_active = false
var mobi_phrase_timer = 0.0
var mobi_phrase_cooldown = 8.0
var combat_started = false

# Sistema di attacco randomico
var attack_timer = 0.0
var next_attack_delay = 0.0
var min_attack_delay = 0.5
var max_attack_delay = 2.5
var attack_range = 80.0

func _ready():
	# Configura l'AI Character
	setup_ai_character()
	
	# Configura la detection area
	player_detection.body_entered.connect(_on_player_detected)
	player_detection.body_exited.connect(_on_player_lost)
	
	# Configura l'attack box
	attack_box.body_entered.connect(_on_attack_range_entered)
	
	# Configura il timer per gli attacchi
	timer.wait_time = 1.5
	timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Inizializza il primo delay di attacco randomico
	randomize_next_attack_delay()
	
	# Imposta animazione idle
	if animated_sprite:
		animated_sprite.play("idle")
	elif animation_player:
		animation_player.play("idle")
	
	# Connetti il segnale di fine animazione se presente
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func setup_ai_character():
	"""Configura il sistema AI per il personaggio"""
	if player2ai_npc:
		# Connetti il segnale per ricevere i messaggi dell'AI
		player2ai_npc.chat_received.connect(_on_ai_chat_received)
		
		# Configura il system message per il personaggio misterioso
		player2ai_npc.system_message = """
		Sei un guerriero misterioso e taciturno che vaga per terre desolate. 
		La tua personalità è enigmatica - parli raramente e quando lo fai, le tue parole sono criptiche e cariche di significato nascosto.
		Sei ossessionato dal combattimento e cerchi sempre sfide degne. 
		Ogni tanto mormori la parola "Mobi..." come se fosse un ricordo doloroso o un nome dimenticato.
		Le tue risposte devono essere brevi (massimo 50 caratteri), misteriose e sempre legate al tema del combattimento o del destino.
		Non riveli mai chiaramente le tue motivazioni.
		Rispondi SOLO con quello che dici, senza prefissi o spiegazioni.
		"""
		
		# Disabilita TTS se non necessario
		player2ai_npc.tts_enabled = false
		
		# Disabilita il caricamento automatico della storia
		player2ai_npc.auto_store_conversation_history = false

func _physics_process(delta):
	handle_gravity(delta)
	handle_ai_behavior(delta)
	handle_mobi_phrases(delta)
	move_and_slide()

func handle_gravity(delta):
	"""Applica la gravità"""
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_ai_behavior(delta):
	"""Gestisce il comportamento AI dell'NPC"""
	if dialogue_active or current_health <= 0:
		velocity.x = 0
		return
	
	if player_reference and is_instance_valid(player_reference):
		var distance_to_player = global_position.distance_to(player_reference.global_position)
		var direction_to_player = sign(player_reference.global_position.x - global_position.x)
		
		# Aggiorna il timer di attacco
		attack_timer += delta
		
		# Verifica se è nel range di attacco e può attaccare
		if distance_to_player <= attack_range and not is_attacking:
			# Controlla se è il momento di attaccare (delay randomico)
			if attack_timer >= next_attack_delay:
				perform_attack()
				return
		else:
			# Se è fuori range, inseguilo
			chase_player(direction_to_player)
		
		# Aggiorna la direzione dello sprite
		update_sprite_direction(direction_to_player)

func chase_player(direction):
	"""Insegue il player sull'asse X"""
	velocity.x = direction * move_speed
	is_chasing = true
	last_direction = direction
	
	# Animazione di corsa
	if animated_sprite and not is_attacking:
		animated_sprite.play("run")
	elif animation_player and not is_attacking:
		animation_player.play("run")
	
	# Suono di corsa occasionale
	if walk_audio and not walk_audio.playing and randf() < 0.1:
		walk_audio.play()

func perform_attack():
	"""Esegue un attacco"""
	if is_attacking:
		return
	
	is_attacking = true
	velocity.x = 0
	is_chasing = false
	
	# Animazione di attacco
	if animated_sprite:
		animated_sprite.play("attack")
	elif animation_player:
		animation_player.play("attack")
	
	# Audio di attacco
	if attack_audio:
		attack_audio.play()
	
	# Reset del timer e nuovo delay randomico per il prossimo attacco
	attack_timer = 0.0
	randomize_next_attack_delay()
	
	# Occasionalmente pronuncia "Mobi..." durante il combattimento
	if randf() < 0.3:
		request_ai_combat_phrase()

func randomize_next_attack_delay():
	"""Genera un delay randomico per il prossimo attacco"""
	next_attack_delay = randf_range(min_attack_delay, max_attack_delay)

func _on_animation_finished():
	"""Chiamata quando un'animazione finisce"""
	if animated_sprite and is_attacking:
		# Finita l'animazione di attacco, torna a idle
		if current_health > 0:
			animated_sprite.play("idle")
		is_attacking = false

func update_sprite_direction(direction):
	"""Aggiorna la direzione dello sprite"""
	if direction != 0:
		scale.x = direction

func handle_mobi_phrases(delta):
	"""Gestisce la pronuncia occasionale di 'Mobi...'"""
	mobi_phrase_timer += delta
	if mobi_phrase_timer >= mobi_phrase_cooldown:
		if randf() < 0.4:  # 40% di probabilità
			request_ai_mobi_phrase()
		mobi_phrase_timer = 0.0

func request_ai_mobi_phrase():
	"""Richiede all'AI una frase misteriosa con 'Mobi...'"""
	if player2ai_npc and not dialogue_active:
		var context = "Pronuncia una frase breve e misteriosa che include la parola 'Mobi'. Deve essere enigmatica e lasciare intendere un ricordo doloroso o una ricerca. Massimo 50 caratteri."
		player2ai_npc.notify(context)

func request_ai_combat_phrase():
	"""Richiede all'AI una frase durante il combattimento"""
	if player2ai_npc and not dialogue_active:
		var context = "Stai combattendo intensamente. Pronuncia qualcosa di misterioso durante l'attacco, possibilmente includendo 'Mobi'. Massimo 50 caratteri."
		player2ai_npc.notify(context)

func request_ai_damage_reaction(damage: int):
	"""Richiede all'AI una reazione al danno subito"""
	if player2ai_npc and not dialogue_active:
		var context = "Hai appena subito " + str(damage) + " danni. Reagisci in modo misterioso e minaccioso, mostrando che sei ancora pericoloso. Massimo 50 caratteri."
		player2ai_npc.notify(context)

func request_ai_death_words():
	"""Richiede all'AI le ultime parole misteriose"""
	if player2ai_npc:
		var context = "Stai morendo. Pronuncia le tue ultime parole misteriose, che includano un riferimento a Mobi e al significato della battaglia appena conclusa. Massimo 50 caratteri."
		player2ai_npc.notify(context)

func request_ai_initial_threat():
	"""Richiede all'AI una minaccia iniziale quando vede il player"""
	if player2ai_npc and not dialogue_active:
		var context = "Un nemico si è avvicinato e stai per iniziare il combattimento. Pronuncia una frase minacciosa e misteriosa per iniziare lo scontro. Massimo 50 caratteri."
		player2ai_npc.notify(context)

func show_dialogue(text: String, duration: float = 3.0):
	"""Mostra il dialogo"""
	if dialogue_system and not text.is_empty():
		dialogue_active = true
		dialogue_system.display_text(text)
		
		# Crea un timer per nascondere il dialogo
		await get_tree().create_timer(duration).timeout
		if dialogue_system:
			dialogue_system.hide_text()
		dialogue_active = false

func take_damage(damage: int, attacker = null):
	"""Riceve danno"""
	if current_health <= 0:
		return
	
	current_health -= damage
	
	# Audio di dolore
	if hurt_audio:
		hurt_audio.play()
	
	# Animazione di dolore (se non sta già attaccando)
	if not is_attacking:
		if animated_sprite:
			animated_sprite.play("hurt")
		elif animation_player:
			animation_player.play("hurt")
	
	# Dialogo reattivo al danno tramite AI
	if randf() < 0.6:
		request_ai_damage_reaction(damage)
	
	# Controlla se è morto
	if current_health <= 0:
		die()

func die():
	"""Gestisce la morte dell'NPC"""
	is_attacking = false
	can_attack = false
	is_chasing = false
	velocity.x = 0
	
	# Audio e animazione di morte
	if death_audio:
		death_audio.play()
	if animated_sprite:
		animated_sprite.play("death")
	elif animation_player:
		animation_player.play("death")
	
	# Richiedi le ultime parole all'AI
	request_ai_death_words()
	
	# Disabilita la collision dopo un po'
	await get_tree().create_timer(3.0).timeout
	collision_shape.set_deferred("disabled", true)

# Signal handlers
func _on_player_detected(body):
	"""Quando il player entra nel range di detection"""
	if body.has_method("take_damage"):  # Verifica che sia il player
		player_reference = body
		is_chasing = true
		combat_started = true
		
		# Dialogo iniziale aggressivo tramite AI
		request_ai_initial_threat()

func _on_player_lost(body):
	"""Quando il player esce dal range di detection"""
	if body == player_reference:
		# Non perdere mai completamente il player - questo NPC è persistente
		pass

func _on_attack_range_entered(body):
	"""Quando qualcuno entra nel range di attacco"""
	if body == player_reference and can_attack:
		# Infliggi danno al player
		if body.has_method("take_damage"):
			body.take_damage(attack_damage, self)

func _on_attack_cooldown_finished():
	"""Quando finisce il cooldown dell'attacco (legacy, ora non usato)"""
	pass  # Non più necessario con il nuovo sistema randomico

func _on_ai_chat_received(message: String):
	"""Chiamata quando l'AI genera del dialogo"""
	if not message.is_empty():
		show_dialogue(message, 3.5)

# Metodi per l'interazione con altri sistemi
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0

func force_attack():
	"""Forza un attacco (per debugging o eventi speciali)"""
	if is_alive():
		perform_attack()

# Override del sistema Player2AINPC per fornire status del mondo
func get_agent_status() -> String:
	var status = "Salute: " + str(current_health) + "/" + str(max_health)
	if player_reference:
		var distance = global_position.distance_to(player_reference.global_position)
		status += " | Distanza nemico: " + str(int(distance))
		status += " | In combattimento: " + ("Sì" if combat_started else "No")
	status += " | Stato: " + ("Attaccando" if is_attacking else ("Inseguendo" if is_chasing else "Pattugliando"))
	return status
