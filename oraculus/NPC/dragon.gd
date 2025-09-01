extends Node2D

var speed = 40
var direction = true
var high = 0.3
var can_move_y := false   

@onready var flip_timer: Timer = Timer.new()
@onready var start_y_timer: Timer = Timer.new()

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	$AudioStreamPlayer2D.play()
	
	add_child(flip_timer)
	flip_timer.one_shot = true
	flip_timer.timeout.connect(_on_flip_timer_timeout)
	_start_new_flip_timer()
	
	add_child(start_y_timer)
	start_y_timer.one_shot = true
	start_y_timer.wait_time = 2
	start_y_timer.timeout.connect(_on_start_y_movement)
	start_y_timer.start()


func _physics_process(delta: float) -> void:
	if can_move_y:
		position.y -= high
	
	if direction:
		position.x -= speed * delta
		$AnimatedSprite2D.flip_h = false
	else:
		position.x += speed * delta
		$AnimatedSprite2D.flip_h = true


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("music_player"):
		position.x = 500
		position.y = -100
		direction = false


func _on_flip_timer_timeout() -> void:
	high *= -1
	_start_new_flip_timer()


func _start_new_flip_timer() -> void:
	var wait_time = randf_range(0.5, 1)
	flip_timer.start(wait_time)


func _on_start_y_movement() -> void:
	can_move_y = true
