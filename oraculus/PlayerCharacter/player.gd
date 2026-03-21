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
var climbing: bool = false
var current_stairs: Node = null
@export var climb_speed: float = 100.0
@export var knockback_force: float = 300.0
var knockback_active: bool = false
var running: bool = false
var slide_direction: int = 0
var collision_shape: CollisionShape2D

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

	if knockback_active:
		velocity.y += gravity * delta
		move_and_slide()
		return

	if parrying:
		move_and_slide()
		return

	if sliding:
		collision_shape.rotation = deg_to_rad(90)
		velocity.x = slide_direction * slide_speed
		move_and_slide()
		if is_on_wall():
			_on_slide_timeout()
		sprite.play("slide")
		return
	else:
		collision_shape.rotation = deg_to_rad(0)

	detect_stairs()

	if climbing:
		handle_stairs_movement(delta)
		return

	if is_on_wall() and not is_on_floor() and velocity.y > 80:
		velocity.y = 80
		if not attacking and not sliding and not parrying:
			var wall_normal = get_wall_normal()
			sprite.flip_h = wall_normal.x < 0
			if sprite.animation != "wall_slide":
				sprite.play("wall_slide")

	if Input.is_action_just_pressed("jump") and is_on_wall() and not is_on_floor():
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * wall_jump_force_x
		velocity.y = -wall_jump_force_y
		wall_jumping = true
		jumps_left = max_jumps - 1
		jump_sound.play()
		sprite.play("jump")
		sprite.flip_h = wall_normal.x < 0
		wall_jump_lock_timer.start(wall_jump_lock_time)
		move_and_slide()
		return

	if wall_jumping:
		velocity.y += gravity * delta
		if sprite.animation != "jump":
			sprite.play("jump")
		move_and_slide()
		return

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
		parry_timer.start(parry_window)
		sprite.play("parry")
		velocity.x = 0
		move_and_slide()
		return

	if attacking or parrying:
		move_and_slide()
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

	velocity.x = direction * current_speed

	if is_on_floor() and moving and not walk_sound.playing:
		walk_sound.play()
	elif (not is_on_floor() or not moving) and walk_sound.playing:
		walk_sound.stop()

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
		jumps_left = max_jumps

	if not was_on_floor and is_on_floor():
		walk_sound.play()
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("jump") and jumps_left > 0:
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

	move_and_slide()

	if is_on_wall() and not is_on_floor() and velocity.y > 80 and not attacking and not sliding and not parrying:
		pass
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

	if not (is_on_wall() and not is_on_floor() and velocity.y > 80) and direction != 0 and not sliding and not parrying:
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

func _on_slide_timeout() -> void:
	sliding = false
	slide_direction = 0
	velocity.x = 0
	sprite.position.y = 0
	collision_shape.rotation = deg_to_rad(0)

func detect_stairs():
	var areas = $StairDetector.get_overlapping_areas()
	var stairs_found = false
	for area in areas:
		if area.get_parent().is_in_group("stairs"):
			current_stairs = area.get_parent()
			stairs_found = true
			break
	if stairs_found:
		if not climbing:
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

func handle_stairs_movement(delta):
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir == 0:
		velocity = Vector2.ZERO
	else:
		velocity = current_stairs.direction * input_dir * current_stairs.climb_speed
	move_and_slide()
	if input_dir == 0:
		sprite.play("idle")
	else:
		sprite.play("run")
		sprite.flip_h = input_dir < 0

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
