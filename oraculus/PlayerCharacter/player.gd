extends CharacterBody2D

@export var speed: float = 120.0
var normal_speed: float
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0
@export var max_jumps: int = 2
@export var max_health: int = 100
@export var attack_damage: int = 10
@export var invincibility_time: float = 0.5
@export var damage: int = 10
@export var slide_speed: float = 400.0
@export var slide_duration: float = 0.5
var sliding: bool = false
var slide_timer: Timer
var last_input_time: Dictionary = {"move_left": 0.0, "move_right": 0.0}
@export var double_tap_time: float = 0.3
var crouching: bool = false
var jumps_left: int = 0
var attacking: bool = false
var sprite: AnimatedSprite2D
var was_on_floor: bool = true
var current_health: int
var can_take_damage: bool = true
var invincibility_timer: Timer
var can_interact: bool = false
var current_demon: Node2D = null

# Nodi AudioStreamPlayer
@onready var walk_sound = $Walk
@onready var jump_sound = $Jump
@onready var attack_sound = $Attack
@onready var hurt_sound = $Hurt
@onready var death_sound = $Death
@onready var hud_label: TextEdit = $Camera2D/HUD/Label
@onready var hud = $Camera2D/HUD/Label
@onready var health_bar = $Camera2D/HUD/HP/HP
@onready var hit_box = $HitBox/CollisionShape2D
@onready var attack_box = $AttackBox/CollisionShape2D
@onready var animation_player = $AnimationPlayer
@onready var interact_banner = $Camera2D/HUD/Interact


func _ready() -> void:
	normal_speed = speed
	jumps_left = max_jumps
	current_health = max_health
	sprite = $Player
	sprite.connect("animation_finished", _on_animation_finished)
	was_on_floor = is_on_floor()
	$Area2D.connect("area_entered", _on_interaction_area_entered)
	$Area2D.connect("area_exited", _on_interaction_area_exited)
	$HitBox.connect("area_entered", _on_hit_box_area_entered)
	$AttackBox.connect("area_entered", _on_attack_box_area_entered)
	hud_label.editable = false
	hud.hide()
	attack_box.disabled = true
	update_health()
	slide_timer = Timer.new()
	slide_timer.one_shot = true
	add_child(slide_timer)
	slide_timer.timeout.connect(_on_slide_timeout)
	# Configura timer invincibilità
	invincibility_timer = Timer.new()
	add_child(invincibility_timer)
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)

func _physics_process(delta: float) -> void:
	if $Camera2D/Options.visible == true:
		$Camera2D/Pause.visible = false
	else:
		$Camera2D/Pause.visible = true
	# Blocca i controlli se il giocatore sta scrivendo
	if hud_label.has_focus():
		velocity.x = 0
		sprite.play("idle")
		move_and_slide()
		return
	# Se sto sliddando → ignoro altri input e scivolo
	if sliding:
		$CollisionShape2D.disabled = true
		move_and_slide()
		return
	else:
		$CollisionShape2D.disabled = false

	# Gestione crouch toggle
	if is_on_floor():
		if Input.is_action_just_pressed("crouch"):
			crouching = not crouching
	else:
		crouching = false
	if crouching:
		sprite.position.y = 5
	else:
		sprite.position.y = 0
	# Se sono crouching, imposto le animazioni e movimenti ridotti
	if crouching:
		if is_on_floor():
			if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
				sprite.play("crouch_walk")
			else:
				sprite.play("crouch")
		var direction = 0

		if Input.is_action_pressed("move_left"):
			direction -= 1
		if Input.is_action_pressed("move_right"):
			direction += 1
		velocity.x = direction * (speed * 0.5) # metà della speed
		if direction != 0:
			sprite.flip_h = direction < 0

		move_and_slide()
		return
	# Gestione input interazione
	if Input.is_action_just_pressed("interact") and can_interact and current_demon:
		hud_label.editable = true
		hud.show()
		hud_label.grab_focus()
		return
		
	if can_interact == true:
		interact_banner.visible = true
	else:
		interact_banner.visible = false
		
	if attacking:
		move_and_slide()
		return

	var direction = 0
	var moving = false
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		var action = "move_left" if Input.is_action_just_pressed("move_left") else "move_right"
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_input_time[action] <= double_tap_time:
			start_slide(action)
		last_input_time[action] = now
	# Movimento sinistra/destra
	if Input.is_action_pressed("move_left"):
		direction -= 1
		moving = true
	if Input.is_action_pressed("move_right"):
		direction += 1
		moving = true

	velocity.x = direction * speed

	# Suono camminata
	if is_on_floor() and moving and not walk_sound.playing:
		walk_sound.play()
	elif (not is_on_floor() or not moving) and walk_sound.playing:
		walk_sound.stop()

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
		jumps_left = max_jumps

	# Rileva atterraggio
	if not was_on_floor and is_on_floor():
		walk_sound.play()
	was_on_floor = is_on_floor()

	# Salto
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		velocity.y = -jump_force
		jumps_left -= 1
		jump_sound.play()

	# Attacco
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		sprite.play("attack")
		attack_sound.play()
		velocity.x = 0
		attack_box.disabled = false
		get_tree().create_timer(0.3).timeout.connect(_disable_attack_box)
		move_and_slide()
		return

	move_and_slide()

	# Animazioni
	if sliding:
		sprite.play("slide")
	elif not is_on_floor():
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")
	elif direction != 0:
		sprite.play("run")
	else:
		sprite.play("idle")

	if direction != 0:
		sprite.flip_h = direction < 0
	
	health_bar.value += 2*delta
func _disable_attack_box():
	attack_box.disabled = true

func start_slide(action: String) -> void:
	sliding = true
	sprite.position.y = 10
	sprite.play("slide")
	var dir = -1 if action == "move_left" else 1
	velocity.x = dir * slide_speed
	slide_timer.start(slide_duration)

func _on_slide_timeout() -> void:
	sliding = false
	velocity.x = 0
	sprite.position.y = 0



func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		attacking = false

func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("demon") and can_take_damage:
		var damage_amount = 10
		var damage_source = area.get_parent()
		
		# Prova diversi metodi per ottenere il danno
		if damage_source.has_method("get_damage"):
			damage_amount = damage_source.get_damage()
		elif "attack_damage" in damage_source:
			damage_amount = damage_source.attack_damage
		elif "damage" in damage_source:
			damage_amount = damage_source.damage
		
		take_damage(damage_amount)

func _on_attack_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("hit_demon"):
		var demon = area.get_parent()
		if demon.has_method("take_damage"):
			demon.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if not can_take_damage:
		return
		
	current_health -= amount
	hurt_sound.play()
	update_health()
	
	# Attiva l'invincibilità
	can_take_damage = false
	invincibility_timer.start(invincibility_time)
	animation_player.play("hit_flash")
	
	if current_health <= 0:
		die()

func _on_invincibility_timeout():
	can_take_damage = true
	animation_player.stop()
	sprite.modulate = Color(1, 1, 1, 1)

func update_health() -> void:
	health_bar.value = current_health
	health_bar.max_value = max_health

func die() -> void:
	# Disabilita tutte le interazioni
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	sprite.position.y = 15
	death_sound.play()
	sprite.play("death")
	await sprite.animation_finished
	
	# Crea una transizione
	var transition = get_tree().create_timer(0.5)
	await transition.timeout
	
	# Ricarica in modo sicuro
	$Camera2D/Loose.visible = true
func _input(event):
	if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
		if hud_label.has_focus():
			var answer = hud_label.text.strip_edges()
			if answer != "" and current_demon:
				current_demon.receive_player_answer(answer)
				hud_label.text = ""
				hud_label.release_focus()
				hud.hide()

func _on_interaction_area_entered(area):
	if area.is_in_group("demon_detection"):
		can_interact = true
		current_demon = area.get_parent()

func _on_interaction_area_exited(area):
	if area.is_in_group("demon_detection"):
		can_interact = false
		current_demon = null
		hud_label.editable = false
		hud.hide()
		hud_label.release_focus()


func _on_interact_pressed() -> void:
	can_interact = true


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_stair_speed_area_entered(area: Area2D) -> void:
	speed = 70

func _on_stair_speed_area_exited(area: Area2D) -> void:
	speed = normal_speed
