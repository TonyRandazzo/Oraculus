extends CharacterBody2D

@export var speed: float = 120.0
var normal_speed: float
@export var run_speed_multiplier: float = 1.8
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0
@export var max_jumps: int = 2
@export var max_health: int = 100
@export var attack_damage: int = 10
@export var invincibility_time: float = 0.5
@export var damage: int = 10
@export var slide_speed: float = 100.0
@export var slide_duration: float = 0.7
var sliding: bool = false
var slide_timer: Timer
var last_input_time: Dictionary = {"move_left": 0.0, "move_right": 0.0}
@export var double_tap_time: float = 0.3
var crouching: bool = false
var jumps_left: int = 0
var defense_potion_timer: Timer
var attacking: bool = false
var sprite: AnimatedSprite2D
var was_on_floor: bool = true
var current_health: int
var can_take_damage: bool = true
var invincibility_timer: Timer
var can_interact: bool = false
var defense_potion_active: bool
var current_demon: Node2D = null
var climbing: bool = false
var current_stairs: Node = null
@export var climb_speed: float = 100.0
@export var knockback_force: float = 300.0
var knockback_active: bool = false
var running: bool = false
var slide_direction: int = 0
var collision_shape: CollisionShape2D
var _stuck_on_wall_frames: int = 0
# Layer corrente delle scale: 1 = foreground (default), 2 = background.
# Cambialo via codice o da un trigger in scena per attivare le scale del layer corretto.
var current_stair_layer: int = 1

@export var wall_jump_force_x: float = 280.0
@export var wall_jump_force_y: float = 380.0
@export var wall_jump_lock_time: float = 0.18
var wall_jumping: bool = false
var wall_jump_lock_timer: Timer

@export var parry_window: float = 0.15
var parry_active: bool = false
var parrying: bool = false
var parry_timer: Timer

@onready var walk_sound = $Walk
@onready var jump_sound = $Jump
@onready var attack_sound = $Attack
@onready var hurt_sound = $Hurt
@onready var death_sound = $Death
@onready var wall_jump_anim: AnimatedSprite2D = $WallJumpAnim

var _wall_jump_anim_home_pos: Vector2
var _wall_jump_anim_pinned: bool = false
@onready var hud_label: TextEdit = $CanvasLayer/HUD/Label
@onready var hud = $CanvasLayer/HUD/Label
@onready var health_bar = $CanvasLayer/HUD/HP/HP
@onready var hit_box = $HitBox/CollisionShape2D
@onready var attack_box = $AttackBox/CollisionShape2D
@onready var animation_player = $AnimationPlayer
@onready var interact_banner = $CanvasLayer/HUD/Interact

func _ready() -> void:
	speed = 120
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
	
	collision_shape = $CollisionShape2D

	_wall_jump_anim_home_pos = wall_jump_anim.position
	wall_jump_anim.visible = false

	slide_timer = Timer.new()
	slide_timer.one_shot = true
	add_child(slide_timer)
	slide_timer.timeout.connect(_on_slide_timeout)

	invincibility_timer = Timer.new()
	add_child(invincibility_timer)
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)

	parry_timer = Timer.new()
	parry_timer.one_shot = true
	add_child(parry_timer)
	parry_timer.timeout.connect(_on_parry_timeout)

	wall_jump_lock_timer = Timer.new()
	wall_jump_lock_timer.one_shot = true
	add_child(wall_jump_lock_timer)
	wall_jump_lock_timer.timeout.connect(_on_wall_jump_lock_timeout)

	defense_potion_timer = Timer.new()
	defense_potion_timer.one_shot = true
	add_child(defense_potion_timer)
	defense_potion_timer.timeout.connect(_on_defense_potion_timeout)

func _on_defense_potion_timeout() -> void:
	defense_potion_active = false
	$VFX2.play("default")

func apply_stairs_movement(input_dir: float) -> void:
	if climbing and current_stairs:
		var current_speed = speed * run_speed_multiplier if running else speed
		velocity = current_stairs.direction * input_dir * current_speed

func _physics_process(delta: float) -> void:
	if $CanvasLayer/Options.visible == true:
		$CanvasLayer/Pause.visible = false
	else:
		$CanvasLayer/Pause.visible = true

	if hud_label.has_focus():
		velocity.x = 0
		sprite.play("idle")
		move_and_slide()
		return

	detect_stairs()

	if knockback_active:
		velocity.y += gravity * delta
		move_and_slide()
		return

	if parrying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if sliding:
		collision_shape.rotation = deg_to_rad(90)
		collision_shape.position.y = 10
		if climbing and current_stairs:
			velocity = slide_direction * current_stairs.direction * slide_speed
		else:
			velocity.x = slide_direction * slide_speed
		var _pre_slide_pos := global_position
		move_and_slide()
		var _slide_moved := (global_position - _pre_slide_pos).length()
		if _slide_moved < 1.0 and get_slide_collision_count() == 0:
			_try_unstick_slide(_pre_slide_pos)
		elif is_on_wall():
			_on_slide_timeout()
		sprite.play("slide")
		return
	else:
		collision_shape.rotation = deg_to_rad(0)
		collision_shape.position.y = 0

	if is_on_floor():
		if Input.is_action_just_pressed("crouch"):
			crouching = not crouching
	else:
		crouching = false

	if crouching:
		sprite.position.y = 5
	else:
		sprite.position.y = 0

	if crouching:
		collision_shape.rotation = deg_to_rad(90)
		collision_shape.position.y = 10
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
		velocity.x = direction * (speed * 0.5)
		if direction != 0:
			sprite.flip_h = direction < 0
		move_and_slide()
		return

	if Input.is_action_just_pressed("interact") and can_interact and current_demon:
		hud_label.editable = true
		hud.show()
		hud_label.grab_focus()
		return

	if can_interact == true:
		interact_banner.visible = true
	else:
		interact_banner.visible = false

	if Input.is_action_just_pressed("parry") and not attacking and not sliding and not parrying and not parry_active:
		parry_active = true
		parrying = true
		sprite.play("parry")
		velocity.x = 0
		if not defense_potion_active:
			parry_timer.start(parry_window)
		move_and_slide()
		return

	if attacking or parrying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_wall() and not is_on_floor() and not climbing:
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * wall_jump_force_x
		velocity.y = -wall_jump_force_y
		wall_jumping = true
		jumps_left = max_jumps - 1
		jump_sound.play()
		walk_sound.play()
		sprite.play("jump")
		sprite.flip_h = wall_normal.x < 0
		_pin_wall_jump_anim(wall_normal)
		wall_jump_lock_timer.start(wall_jump_lock_time)
		move_and_slide()
		return

	if wall_jumping:
		velocity.y += gravity * delta
		if sprite.animation != "jump":
			sprite.play("jump")
		var _pre_wj_pos := global_position
		move_and_slide()
		if (global_position - _pre_wj_pos).length() < 0.5 and get_slide_collision_count() == 0:
			_try_unstick_wall()
		return

	var direction = 0
	var moving = false
	running = Input.is_action_pressed("run")
	var current_speed = speed * run_speed_multiplier if running else speed

	if (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")) and is_on_floor():
		var action = "move_left" if Input.is_action_just_pressed("move_left") else "move_right"
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_input_time[action] <= double_tap_time:
			start_slide(action)
		last_input_time[action] = now

	if Input.is_action_pressed("move_left"):
		direction -= 1
		moving = true
	if Input.is_action_pressed("move_right"):
		direction += 1
		moving = true

	if climbing and not attacking and not parrying and not sliding:
		apply_stairs_movement(direction)
	elif climbing:
		velocity = Vector2.ZERO
	else:
		velocity.x = direction * current_speed

	if is_on_floor() and moving and not walk_sound.playing:
		walk_sound.play()
	elif (not is_on_floor() or not moving) and walk_sound.playing:
		walk_sound.stop()

	if not climbing:
		velocity.y += gravity * delta

	if is_on_floor():
		velocity.y = 0
		jumps_left = max_jumps

	if not was_on_floor and is_on_floor():
		walk_sound.play()
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		if climbing:
			climbing = false
			current_stairs = null
			gravity = 1000.0
		velocity.y = -jump_force
		if running and direction != 0:
			velocity.y = -jump_force
			velocity.x = direction * current_speed * 1.5
		jumps_left -= 1
		jump_sound.play()

	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		var attack_animations = ["attack", "attack1"]
		var random_attack = attack_animations[randi() % attack_animations.size()]
		sprite.play(random_attack)
		attack_sound.play()
		velocity.x = 0
		attack_box.disabled = false
		get_tree().create_timer(0.3).timeout.connect(_disable_attack_box)
		move_and_slide()
		return

	var _pre_move_pos := global_position
	move_and_slide()

	# Stuck-in-wall detection per il wall_slide normale
	if is_on_wall() and not is_on_floor() and not wall_jumping:
		if (global_position - _pre_move_pos).length() < 0.5:
			_stuck_on_wall_frames += 1
			if _stuck_on_wall_frames >= 20:
				_try_unstick_wall()
		else:
			_stuck_on_wall_frames = 0
	else:
		_stuck_on_wall_frames = 0

	if climbing:
		if direction != 0:
			if running:
				sprite.play("sprint")
			else:
				sprite.play("run")
			sprite.flip_h = direction < 0
		else:
			sprite.play("idle")
	elif is_on_wall() and not is_on_floor() and velocity.y > 80 and not attacking and not sliding and not parrying:
		var wall_normal = get_wall_normal()
		sprite.flip_h = wall_normal.x < 0
		if sprite.animation != "wall_slide":
			sprite.play("wall_slide")
	elif sliding:
		sprite.play("slide")
	elif not is_on_floor():
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")
	elif direction != 0:
		if running:
			sprite.play("sprint")
		else:
			sprite.play("run")
	elif not parry_active and not attacking and not parrying:
		sprite.play("idle")

	if not wall_jumping and not (is_on_wall() and not is_on_floor() and velocity.y > 80) and direction != 0 and not sliding and not parrying and not climbing:
		sprite.flip_h = direction < 0

	health_bar.value += 2 * delta

func _on_wall_jump_lock_timeout() -> void:
	wall_jumping = false

func _disable_attack_box():
	attack_box.disabled = true

func start_slide(action: String) -> void:
	sliding = true
	slide_direction = -1 if action == "move_left" else 1
	sprite.position.y = 10
	sprite.play("slide")
	velocity.x = slide_direction * slide_speed
	slide_timer.start(slide_duration)

func _pin_wall_jump_anim(wall_normal: Vector2) -> void:
	# Al nuovo wall jump, prima riporta l'animazione precedente alla posizione originale
	if _wall_jump_anim_pinned:
		wall_jump_anim.top_level = false
		wall_jump_anim.position = _wall_jump_anim_home_pos
		wall_jump_anim.visible = false
		_wall_jump_anim_pinned = false

	# Poi la fissa sul muro appena usato, rivolta verso di esso
	wall_jump_anim.top_level = true
	wall_jump_anim.global_position = global_position + Vector2(-wall_normal.x * 10.0, 9.0)
	wall_jump_anim.flip_h = wall_normal.x < 0
	wall_jump_anim.visible = true
	wall_jump_anim.stop()
	wall_jump_anim.play("wall jump")
	_wall_jump_anim_pinned = true

func _try_unstick_wall() -> void:
	wall_jumping = false
	wall_jump_lock_timer.stop()
	_stuck_on_wall_frames = 0

	var normal := get_wall_normal() if is_on_wall() else Vector2.RIGHT
	var offsets: Array[Vector2] = [
		normal * 14,
		normal * 14 + Vector2(0, -10),
		Vector2(0, -16),
		normal * 24,
		normal * 14 + Vector2(0, -20),
		Vector2(0, -28),
	]
	for offset in offsets:
		var candidate := global_position + offset
		var t := global_transform
		t.origin = candidate
		if not test_move(t, Vector2.ZERO):
			global_position = candidate
			velocity = Vector2.ZERO
			return
	velocity = Vector2.ZERO

func _on_slide_timeout() -> void:
	sliding = false
	slide_direction = 0
	velocity.x = 0
	sprite.position.y = 0
	collision_shape.rotation = deg_to_rad(0)
	collision_shape.position.y = 0

func _try_unstick_slide(fallback_pos: Vector2) -> void:
	# Candidati ordinati: prima avanti nella direzione della slide, poi indietro, poi in alto
	var offsets: Array[Vector2] = [
		Vector2(slide_direction * 10, 0),
		Vector2(slide_direction * 10, -10),
		Vector2(0, -12),
		Vector2(-slide_direction * 10, 0),
		Vector2(-slide_direction * 10, -10),
		Vector2(0, -20),
		Vector2(slide_direction * 20, 0),
		Vector2(-slide_direction * 20, 0),
	]
	for offset in offsets:
		var candidate := global_position + offset
		var t := global_transform
		t.origin = candidate
		if not test_move(t, Vector2.ZERO):
			global_position = candidate
			_on_slide_timeout()
			return
	# Nessuna posizione libera trovata: torna dove eri prima del frame
	global_position = fallback_pos
	_on_slide_timeout()

func detect_stairs():
	var areas = $StairDetector.get_overlapping_areas()
	var stairs_found = false
	for area in areas:
		var parent = area.get_parent()
		if not parent.is_in_group("stairs"):
			continue
		# Ignora scale che appartengono a un layer diverso da quello corrente
		var layer = parent.get("stair_layer")
		if layer != null and layer != current_stair_layer:
			continue
		current_stairs = parent
		stairs_found = true
		break
	if stairs_found:
		if not climbing and velocity.y >= 0:
			climbing = true
			gravity = 0
	else:
		if climbing:
			climbing = false
			current_stairs = null
			gravity = 1000.0

func camera_shake(intensity: float, duration: float) -> void:
	var cam = $Camera2D
	if not cam:
		return
	var tween = create_tween()
	for i in range(int(duration * 60)):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(cam, "offset", offset, 0.016)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func shake_on_hit_enemy():
	camera_shake(1.5, 0.05)

func shake_on_take_damage():
	camera_shake(3.0, 0.3)

func _on_animation_finished() -> void:
	if sprite.animation == "attack" or sprite.animation == "attack1":
		attacking = false
	if sprite.animation == "parry":
		parrying = false
		parry_active = false
		can_take_damage = true

func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("demon") and can_take_damage:
		if parry_active:
			parry_active = false
			parry_timer.stop()
			parrying = true
			can_take_damage = false
			velocity.x = 0
			sprite.play("parry")
			$VFX.play("vanishing")
			return

		var damage_amount = 10
		var damage_source = area.get_parent()
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
			shake_on_hit_enemy()

func take_damage(amount: float) -> void:
	if not can_take_damage:
		return
	current_health -= amount
	hurt_sound.play()
	update_health()
	shake_on_take_damage()
	var knockback_direction = 1 if sprite.flip_h else -1
	velocity.x = knockback_direction * knockback_force
	velocity.y = -knockback_force * 0.5
	knockback_active = true
	can_take_damage = false
	invincibility_timer.start(invincibility_time)
	animation_player.play("hit_flash")
	get_tree().create_timer(0.3).timeout.connect(_end_knockback)
	if current_health <= 0:
		die()

func _end_knockback():
	knockback_active = false

func _on_invincibility_timeout():
	can_take_damage = true
	animation_player.stop()
	sprite.modulate = Color(1, 1, 1, 1)

func _on_parry_timeout() -> void:
	if defense_potion_active:
		return
	parry_active = false
	if not parrying:
		sprite.play("idle")

func update_health() -> void:
	health_bar.value = current_health
	health_bar.max_value = max_health

func die() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	sprite.position.y = 15
	death_sound.play()
	sprite.play("death")
	await sprite.animation_finished
	var transition = get_tree().create_timer(0.5)
	await transition.timeout
	$CanvasLayer/Loose.visible = true

func win():
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	$CanvasLayer/Win.visible = true
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
	GameState.reset_all()
	await get_tree().process_frame
	get_tree().reload_current_scene()



func _on_reset_area_entered(area: Area2D) -> void:
	current_stair_layer = 1
