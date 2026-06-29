extends CanvasLayer

signal completed

@export var piece_count: int = 9          # deve essere quadrato perfetto: 4, 9, 16
@export var placement_timeout: float = 7.0
@export var snap_radius: float = 36.0
# Immagine del puzzle — assegnala nell'Inspector
@export var puzzle_texture: Texture2D

@onready var board: Control = $PuzzleBoard
@onready var preview: TextureRect = $PuzzleBoard/PreviewImage
@onready var slots_node: Node2D = $PuzzleBoard/Slots
@onready var pieces_node: Node2D = $PuzzleBoard/Pieces
@onready var timer_bar: ProgressBar = $TimerBar
@onready var timer_node: Timer = $PlacementTimer
@onready var key_status: Label = $HUD/KeyStatusLabel
@onready var instructions: Label = $HUD/InstructionsLabel
@onready var close_btn: Button = $HUD/CloseButton
@onready var success_overlay: Control = $SuccessOverlay

const BOARD_OFFSET := Vector2(120, 80)
const PIECE_SIZE := Vector2(64, 64)

var slots: Array[Control] = []
var pieces: Array[Control] = []
var piece_placed: Array[bool] = []
var dragging_piece: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var timer_running: bool = false
var solved: bool = false
var door_id: String = ""

func _ready() -> void:
	close_btn.pressed.connect(_close)
	timer_node.timeout.connect(_on_timer_timeout)
	timer_node.wait_time = placement_timeout
	timer_bar.max_value = placement_timeout
	timer_bar.value = placement_timeout
	visible = false

func activate(id: String) -> void:
	door_id = id
	solved = false
	timer_running = false
	timer_node.stop()
	timer_bar.value = placement_timeout
	success_overlay.visible = false
	_rebuild_puzzle()
	_update_key_status()

	if not GameState.is_connected("puzzle_key_collected", _update_key_status):
		GameState.puzzle_key_collected.connect(_update_key_status)

func _rebuild_puzzle() -> void:
	for c in slots_node.get_children():
		c.queue_free()
	for c in pieces_node.get_children():
		c.queue_free()
	slots.clear()
	pieces.clear()
	piece_placed.clear()

	var cols := int(sqrt(float(piece_count)))
	var rows := cols

	for r in range(rows):
		for c in range(cols):
			var idx := r * cols + c
			var target_pos := BOARD_OFFSET + Vector2(c, r) * PIECE_SIZE

			# Slot
			var slot := ColorRect.new()
			slot.color = Color(1, 1, 1, 0.12)
			slot.size = PIECE_SIZE - Vector2(2, 2)
			slot.position = target_pos
			slot.set_meta("slot_index", idx)
			slot.set_meta("target_pos", target_pos)
			slots_node.add_child(slot)
			slots.append(slot)

			# Piece
			var piece := ColorRect.new()
			piece.color = _piece_color(idx)
			piece.size = PIECE_SIZE - Vector2(4, 4)
			piece.set_meta("piece_index", idx)
			piece.set_meta("target_pos", target_pos)
			piece.position = _random_scatter_pos(cols, rows)
			pieces_node.add_child(piece)
			pieces.append(piece)
			piece_placed.append(false)

			# Piece label
			var lbl := Label.new()
			lbl.text = str(idx + 1)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			piece.add_child(lbl)

func _piece_color(idx: int) -> Color:
	var h := fmod(float(idx) / float(piece_count) + 0.05, 1.0)
	return Color.from_hsv(h, 0.55, 0.8)

func _random_scatter_pos(cols: int, rows: int) -> Vector2:
	var puzzle_w := cols * PIECE_SIZE.x
	var scatter_x := randf_range(BOARD_OFFSET.x + puzzle_w + 30, BOARD_OFFSET.x + puzzle_w + 200)
	var scatter_y := randf_range(BOARD_OFFSET.y, BOARD_OFFSET.y + rows * PIECE_SIZE.y)
	return Vector2(scatter_x, scatter_y)

func _process(delta: float) -> void:
	if not visible or solved:
		return
	if timer_running:
		timer_bar.value = timer_node.time_left
	if dragging_piece:
		dragging_piece.position = get_viewport().get_mouse_position() - board.global_position - drag_offset

func _input(event: InputEvent) -> void:
	if not visible or solved:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
			if dragging_piece:
				get_viewport().set_input_as_handled()
		else:
			if dragging_piece:
				_try_drop()
				get_viewport().set_input_as_handled()

func _try_grab(screen_pos: Vector2) -> void:
	var local := screen_pos - board.global_position
	for piece in pieces:
		var idx: int = piece.get_meta("piece_index")
		if piece_placed[idx]:
			continue
		var rect := Rect2(piece.position, piece.size)
		if rect.has_point(local):
			dragging_piece = piece
			drag_offset = local - piece.position
			pieces_node.move_child(piece, pieces_node.get_child_count() - 1)
			return

func _try_drop() -> void:
	if dragging_piece == null:
		return
	var piece := dragging_piece
	dragging_piece = null
	var idx: int = piece.get_meta("piece_index")
	var target: Vector2 = piece.get_meta("target_pos")

	if piece.position.distance_to(target - board.global_position) <= snap_radius:
		piece.position = target - board.global_position
		piece_placed[idx] = true
		piece.color = Color(piece.color.r, piece.color.g, piece.color.b, 1.0)
		_restart_timer()
		_check_complete()
	else:
		_restart_timer()

func _restart_timer() -> void:
	timer_node.stop()
	timer_node.start(placement_timeout)
	timer_bar.value = placement_timeout
	timer_running = true

func _on_timer_timeout() -> void:
	timer_running = false
	timer_bar.value = placement_timeout
	_scatter_all()
	instructions.text = "Time's up! The pieces fell apart. Try again."

func _scatter_all() -> void:
	var cols := int(sqrt(float(piece_count)))
	var rows := cols
	for i in range(pieces.size()):
		piece_placed[i] = false
		pieces[i].position = _random_scatter_pos(cols, rows)
		pieces[i].color = Color(pieces[i].color.r, pieces[i].color.g, pieces[i].color.b, 0.75)

func _check_complete() -> void:
	if piece_placed.any(func(v): return not v):
		return
	if not GameState.puzzle_key_found:
		instructions.text = "Puzzle complete! But you still need the hidden key..."
		return
	_win()

func _win() -> void:
	solved = true
	timer_node.stop()
	timer_running = false
	success_overlay.visible = true
	await get_tree().create_timer(2.0).timeout
	visible = false
	emit_signal("completed")

func _update_key_status() -> void:
	if GameState.puzzle_key_found:
		key_status.text = "Key: FOUND"
		key_status.add_theme_color_override("font_color", Color(0.2, 1, 0.3))
		# Se il puzzle era già completo, sblocca ora
		if not solved and not piece_placed.is_empty() and piece_placed.all(func(v): return v):
			_win()
	else:
		key_status.text = "Key: Not found"
		key_status.add_theme_color_override("font_color", Color(1, 0.4, 0.2))

func _close() -> void:
	timer_node.stop()
	timer_running = false
	visible = false
