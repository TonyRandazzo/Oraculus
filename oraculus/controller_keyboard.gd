extends CanvasLayer

## Tastiera integrata per Steam Deck e altri gamepad. Non richiede Steamworks.
signal submitted

const KEYS := [
	"q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
	"a", "s", "d", "f", "g", "h", "j", "k", "l", "z",
	"x", "c", "v", "b", "n", "m", "à", "è", "é", "ì",
	"ò", "ù", "á", "í", "ó", "ú", "ä", "ö", "ü", "ñ",
	"ç", "ß", "?", "!", ".", ",", "'", "-", " ", "⌫",
	"⇧", "Invia", "Chiudi",
]
const COLS := 10

var _target: Control
var _keys: Array[Button] = []
var _selected := 0
var _upper := false
var _preview: Label


func show_for(target: Control) -> void:
	_target = target
	_build()
	_update_selection()
	_update_preview()


func _build() -> void:
	layer = 100
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.04, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)
	var hint := Label.new()
	hint.text = "D-pad: scegli   A: inserisci   B: chiudi"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	panel.add_child(hint)
	_preview = Label.new()
	_preview.custom_minimum_size = Vector2(800, 46)
	_preview.clip_text = true
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_theme_font_size_override("font_size", 25)
	panel.add_child(_preview)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	for i in range(KEYS.size()):
		var b := Button.new()
		b.text = "Spazio" if KEYS[i] == " " else KEYS[i]
		b.custom_minimum_size = Vector2(76, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(_press.bind(i))
		grid.add_child(b)
		_keys.append(b)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		queue_free()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_press(_selected)
		return
	var delta := 0
	if event.is_action_pressed("ui_left"):
		delta = -1
	elif event.is_action_pressed("ui_right"):
		delta = 1
	elif event.is_action_pressed("ui_up"):
		delta = -COLS
	elif event.is_action_pressed("ui_down"):
		delta = COLS
	if delta != 0:
		_selected = clampi(_selected + delta, 0, KEYS.size() - 1)
		_update_selection()
		get_viewport().set_input_as_handled()


func _press(index: int) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	var key: String = KEYS[index]
	var current := String(_target.get("text"))
	match key:
		"⌫":
			if not current.is_empty():
				_target.set("text", current.substr(0, current.length() - 1))
		"⇧":
			_upper = not _upper
		"Invia":
			submitted.emit()
			queue_free()
			return
		"Chiudi":
			queue_free()
			return
		_:
			_target.set("text", current + (key.to_upper() if _upper else key))
	_update_preview()


func _update_selection() -> void:
	for i in range(_keys.size()):
		_keys[i].modulate = Color(1.0, 0.8, 0.3) if i == _selected else Color.WHITE


func _update_preview() -> void:
	_preview.text = String(_target.get("text")) if is_instance_valid(_target) else ""
