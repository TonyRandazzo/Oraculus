extends Node
## Comandi touch per mobile (compresi i browser mobile).
##
## - tieni premuto sulla metà destra/sinistra dello schermo -> cammini in quella direzione
## - doppio tap sullo stesso lato (tenendo premuto il secondo) -> corri
## - tap singolo -> attacchi
## - tap sul lato opposto a quello verso cui stai camminando -> parry
## - swipe orizzontale verso la direzione di marcia -> scivolata
## - swipe verso l'alto -> salto

## Se true i comandi si attivano solo su dispositivi con touchscreen, così il
## mouse su desktop non fa attaccare o camminare il giocatore (con
## emulate_touch_from_mouse anche il mouse genera eventi touch).
@export var only_with_touchscreen: bool = true
## Quanto va tenuto premuto un dito prima che diventi una camminata.
@export var hold_to_walk_time: float = 0.18
## Durata massima di un tocco perché conti come tap (attacco o parry).
@export var tap_max_time: float = 0.25
## Finestra entro cui due tap sullo stesso lato contano come doppio tap (corsa).
@export var double_tap_time: float = 0.3
## Durata massima di uno swipe.
@export var swipe_max_time: float = 0.5
## Lunghezza minima di uno swipe, in frazione dell'altezza del viewport.
@export var swipe_min_ratio: float = 0.05
## Lunghezza minima di uno swipe in pixel (si usa la maggiore fra le due).
@export var swipe_min_pixels: float = 32.0

var player: CharacterBody2D

# index del dito -> stato del tocco
var _touches: Dictionary = {}
# index dei diti che guidano la camminata, dal più vecchio al più recente
var _walk_order: Array[int] = []
var _walk_dir: int = 0
var _running: bool = false
# azione -> frame di physics che le restano prima del rilascio
var _pulses: Dictionary = {}
var _last_tap_time: float = -1.0
var _last_tap_side: int = 0
var _ui_buttons: Array[TouchScreenButton] = []


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null or (only_with_touchscreen and not DisplayServer.is_touchscreen_available()):
		set_process(false)
		set_process_input(false)
		set_physics_process(false)
		return
	var ui_root := player.get_node_or_null("CanvasLayer")
	if ui_root != null:
		_collect_ui_buttons(ui_root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _collect_ui_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is TouchScreenButton:
			_ui_buttons.append(child)
		_collect_ui_buttons(child)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_pressed(event.index, event.position)
		else:
			_on_touch_released(event.index, event.position)
	elif event is InputEventScreenDrag:
		_on_touch_dragged(event.index, event.position)


func _process(_delta: float) -> void:
	if _input_blocked():
		_release_all()
		return
	var now := _now()
	for index in _touches:
		var touch: Dictionary = _touches[index]
		if touch["walking"]:
			continue
		if now - touch["start_time"] >= hold_to_walk_time:
			_start_walking(index, touch)


func _physics_process(_delta: float) -> void:
	for action in _pulses.keys():
		var frames_left: int = _pulses[action] - 1
		if frames_left <= 0:
			Input.action_release(action)
			_pulses.erase(action)
		else:
			_pulses[action] = frames_left


func _on_touch_pressed(index: int, pos: Vector2) -> void:
	if _input_blocked() or _is_over_ui(pos):
		return
	var side := -1 if pos.x < get_viewport().get_visible_rect().size.x * 0.5 else 1
	var now := _now()
	var wants_run: bool = _last_tap_side == side and now - _last_tap_time <= double_tap_time
	if wants_run and player.attacking:
		# Il primo tap del doppio tap aveva già lanciato un attacco: annullalo
		# così la corsa parte subito invece di aspettare l'animazione.
		player.attacking = false
	_touches[index] = {
		"start_pos": pos,
		"pos": pos,
		"start_time": now,
		"side": side,
		"walking": false,
		"run": wants_run,
		"consumed": false,
	}


func _on_touch_dragged(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	touch["pos"] = pos
	if touch["consumed"] or _input_blocked():
		return
	var start_pos: Vector2 = touch["start_pos"]
	var delta := pos - start_pos
	if delta.length() < _swipe_min_distance() or _now() - touch["start_time"] > swipe_max_time:
		return
	if absf(delta.y) > absf(delta.x):
		if delta.y < 0.0:
			_consume(index)
			_pulse(&"jump")
	else:
		var swipe_dir := -1 if delta.x < 0.0 else 1
		if swipe_dir == _facing_direction():
			_consume(index)
			_try_slide(swipe_dir)


func _on_touch_released(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	_touches.erase(index)

	if touch["walking"]:
		_stop_walking(index)
	if touch["consumed"] or _input_blocked():
		return

	# Un tocco breve e fermo resta un tap anche se ha già fatto partire la
	# camminata, così i tap un po' lenti non vanno persi.
	var start_pos: Vector2 = touch["start_pos"]
	var start_time: float = touch["start_time"]
	if _now() - start_time > tap_max_time or (pos - start_pos).length() > _swipe_min_distance() * 0.5:
		return

	var side: int = touch["side"]
	# Tap sul lato opposto alla direzione di marcia -> parry, altrimenti attacco.
	if _walk_dir != 0 and side == -_walk_dir:
		_pulse(&"parry")
	else:
		_pulse(&"attack")
	_last_tap_time = _now()
	_last_tap_side = side


func _start_walking(index: int, touch: Dictionary) -> void:
	touch["walking"] = true
	if not _walk_order.has(index):
		_walk_order.append(index)
	_sync_walk_state()


func _stop_walking(index: int) -> void:
	_walk_order.erase(index)
	if _touches.has(index):
		_touches[index]["walking"] = false
	_sync_walk_state()


## Il dito più recente decide direzione e corsa, così cambiare lato è immediato.
func _sync_walk_state() -> void:
	var dir := 0
	var run := false
	if not _walk_order.is_empty():
		var touch: Dictionary = _touches.get(_walk_order[-1], {})
		dir = touch.get("side", 0)
		run = touch.get("run", false)
	_set_walk(dir, run)


func _set_walk(dir: int, run: bool) -> void:
	if dir == _walk_dir and run == _running:
		return
	# Il doppio tap touch non deve far scattare anche la scivolata da tastiera.
	player.touch_controls_active = true
	if _walk_dir == -1 and dir != -1:
		Input.action_release(&"move_left")
	elif _walk_dir == 1 and dir != 1:
		Input.action_release(&"move_right")
	if dir == -1 and _walk_dir != -1:
		Input.action_press(&"move_left")
	elif dir == 1 and _walk_dir != 1:
		Input.action_press(&"move_right")
	if run and not _running:
		Input.action_press(&"run")
	elif not run and _running:
		Input.action_release(&"run")
	_walk_dir = dir
	_running = run
	if dir == 0:
		player.touch_controls_active = false


## Marca il tocco come "gesto già eseguito": non ne farà partire altri e al
## rilascio non conterà come tap. La camminata invece continua, così uno swipe
## per saltare o scivolare non costringe a rialzare il dito.
func _consume(index: int) -> void:
	if _touches.has(index):
		_touches[index]["consumed"] = true


func _try_slide(dir: int) -> void:
	if player.sliding or player.attacking or player.parrying or player.knockback_active:
		return
	if not player.is_on_floor() and not player.climbing:
		return
	player.start_slide("move_left" if dir < 0 else "move_right")


## Direzione per la scivolata: quella in cui si sta camminando o, in mancanza,
## quella verso cui il personaggio è girato.
func _facing_direction() -> int:
	if _walk_dir != 0:
		return _walk_dir
	if player.sprite == null:
		return 0
	return -1 if player.sprite.flip_h else 1


func _pulse(action: StringName) -> void:
	Input.action_press(action)
	_pulses[action] = 2


func _release_all() -> void:
	_touches.clear()
	_walk_order.clear()
	_set_walk(0, false)
	for action in _pulses.keys():
		Input.action_release(action)
	_pulses.clear()


func _input_blocked() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_physics_processing():
		return true
	if player.hud_label != null and (player.hud_label.visible or player.hud_label.has_focus()):
		return true
	var canvas := player.get_node_or_null("CanvasLayer")
	if canvas != null:
		for panel_name in ["Options", "Win", "Loose"]:
			var panel := canvas.get_node_or_null(panel_name) as CanvasItem
			if panel != null and panel.visible:
				return true
	return false


func _is_over_ui(pos: Vector2) -> bool:
	for button in _ui_buttons:
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.texture_normal == null:
			continue
		var rect := Rect2(Vector2.ZERO, button.texture_normal.get_size())
		if (button.get_global_transform_with_canvas() * rect).has_point(pos):
			return true
	return false


func _swipe_min_distance() -> float:
	return maxf(swipe_min_pixels, get_viewport().get_visible_rect().size.y * swipe_min_ratio)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
