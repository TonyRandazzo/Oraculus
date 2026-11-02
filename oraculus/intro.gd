extends Control

const MENU_SCENE := "res://oraculus/menu.tscn"
const FADE_DURATION := 0.8
const HOLD_DURATION := 0.9

@onready var logo: TextureRect = $CenterContainer/Logo

var _transition: Tween
var _finished := false

func _ready() -> void:
	logo.modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_property(logo, "modulate:a", 1.0, FADE_DURATION)
	_transition.tween_interval(HOLD_DURATION)
	_transition.tween_property(logo, "modulate:a", 0.0, FADE_DURATION)
	_transition.tween_callback(_finish)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		_transition.kill()
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	TransizioneScena.vai_a(get_tree(), MENU_SCENE)
