extends CanvasLayer

signal completed

@export var piece_count: int = 9          # deve essere quadrato perfetto: 4, 9, 16
@export var placement_timeout: float = 7.0
@export var snap_radius: float = 36.0
# Immagine del puzzle — assegnala nell'Inspector
@export var puzzle_texture: Texture2D

const PIXEL_FONT := preload("res://oraculus/thirdparty/kenney/fonts/Fonts/Kenney Pixel.ttf")
const FRAME_TEXTURE := preload("res://oraculus/thirdparty/kenney/ui-pack-adventure/PNG/Default/panel_border_brown.png")

@onready var board: Control = $PuzzleBoard
@onready var preview: TextureRect = $PuzzleBoard/PreviewImage
@onready var slots_node: Node2D = $PuzzleBoard/Slots
@onready var pieces_node: Node2D = $PuzzleBoard/Pieces
@onready var snap_particles: CPUParticles2D = $PuzzleBoard/SnapParticles
@onready var win_particles: CPUParticles2D = $PuzzleBoard/WinParticles
@onready var timer_bar: ProgressBar = $TimerBar
@onready var timer_node: Timer = $PlacementTimer
@onready var key_status: Label = $HUD/KeyStatusPanel/KeyStatusLabel
@onready var instructions: Label = $HUD/InstructionsPanel/InstructionsLabel
@onready var close_btn: Button = $HUD/CloseButton
@onready var success_overlay: Control = $SuccessOverlay
@onready var success_label: Label = $SuccessOverlay/Label

const PIECE_SIZE := Vector2(64, 64)

var board_offset: Vector2 = Vector2.ZERO

var slots: Array[Control] = []
var pieces: Array[Control] = []
var piece_placed: Array[bool] = []
var dragging_piece: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var timer_running: bool = false
var solved: bool = false
var door_id: String = ""
var _timer_fill_style: StyleBoxFlat

func _ready() -> void:
	close_btn.pressed.connect(_close)
	timer_node.timeout.connect(_on_timer_timeout)
	timer_node.wait_time = placement_timeout
	timer_bar.max_value = placement_timeout
	timer_bar.value = placement_timeout
	_timer_fill_style = timer_bar.get_theme_stylebox("fill")
	visible = false

func activate(id: String) -> void:
	door_id = id
	solved = false
	timer_running = false
	timer_node.stop()
	timer_bar.value = placement_timeout
	timer_bar.modulate = Color(1, 1, 1, 1)
	success_overlay.visible = false
	success_overlay.modulate = Color(1, 1, 1, 0)
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

	var viewport_size := get_viewport().get_visible_rect().size
	var grid_size := Vector2(cols, rows) * PIECE_SIZE
	board_offset = ((viewport_size - grid_size) / 2.0).round()
	preview.position = board_offset
	preview.size = grid_size

	_build_board_frame(cols, rows)

	for r in range(rows):
		for c in range(cols):
			var idx := r * cols + c
			var target_pos := board_offset + Vector2(c, r) * PIECE_SIZE

			# Slot
			var slot := Panel.new()
			var slot_style := StyleBoxFlat.new()
			slot_style.bg_color = Color(0.9, 0.75, 0.5, 0.12)
			slot_style.border_width_left = 2
			slot_style.border_width_top = 2
			slot_style.border_width_right = 2
			slot_style.border_width_bottom = 2
			slot_style.border_color = Color(0.85, 0.65, 0.25, 0.4)
			slot_style.corner_radius_top_left = 6
			slot_style.corner_radius_top_right = 6
			slot_style.corner_radius_bottom_right = 6
			slot_style.corner_radius_bottom_left = 6
			slot.add_theme_stylebox_override("panel", slot_style)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.size = PIECE_SIZE - Vector2(2, 2)
			slot.position = target_pos
			slot.set_meta("slot_index", idx)
			slot.set_meta("target_pos", target_pos)
			slots_node.add_child(slot)
			slots.append(slot)

			var slot_lbl := Label.new()
			slot_lbl.text = str(idx + 1)
			slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot_lbl.add_theme_font_override("font", PIXEL_FONT)
			slot_lbl.add_theme_font_size_override("font_size", 16)
			slot_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 0.3))
			slot.add_child(slot_lbl)

			# Piece
			var piece := Panel.new()
			var piece_style := StyleBoxFlat.new()
			piece_style.bg_color = _piece_color(idx)
			piece_style.border_width_left = 2
			piece_style.border_width_top = 2
			piece_style.border_width_right = 2
			piece_style.border_width_bottom = 2
			piece_style.border_color = Color(0.9, 0.72, 0.35, 0.85)
			piece_style.corner_radius_top_left = 8
			piece_style.corner_radius_top_right = 8
			piece_style.corner_radius_bottom_right = 8
			piece_style.corner_radius_bottom_left = 8
			piece_style.shadow_size = 6
			piece_style.shadow_color = Color(0.1, 0.05, 0.02, 0.4)
			piece.add_theme_stylebox_override("panel", piece_style)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.size = PIECE_SIZE - Vector2(4, 4)
			piece.pivot_offset = piece.size / 2.0
			piece.set_meta("piece_index", idx)
			piece.set_meta("target_pos", target_pos)
			piece.set_meta("style", piece_style)
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
			lbl.add_theme_font_override("font", PIXEL_FONT)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
			lbl.add_theme_constant_override("outline_size", 3)
			piece.add_child(lbl)

func _build_board_frame(cols: int, rows: int) -> void:
	var frame := Panel.new()
	var frame_style := StyleBoxTexture.new()
	frame_style.texture = FRAME_TEXTURE
	frame_style.texture_margin_left = 14.0
	frame_style.texture_margin_top = 14.0
	frame_style.texture_margin_right = 14.0
	frame_style.texture_margin_bottom = 14.0
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = board_offset - Vector2(16, 16)
	frame.size = Vector2(cols, rows) * PIECE_SIZE + Vector2(32, 32)
	slots_node.add_child(frame)

func _piece_color(idx: int) -> Color:
	var h := fmod(float(idx) / float(piece_count) + 0.05, 1.0)
	return Color.from_hsv(h, 0.65, 0.9)

func _random_scatter_pos(cols: int, rows: int) -> Vector2:
	var puzzle_w := cols * PIECE_SIZE.x
	var scatter_x := randf_range(board_offset.x + puzzle_w + 30, board_offset.x + puzzle_w + 200)
	var scatter_y := randf_range(board_offset.y, board_offset.y + rows * PIECE_SIZE.y)
	return Vector2(scatter_x, scatter_y)

func _process(delta: float) -> void:
	if not visible or solved:
		return
	if timer_running:
		timer_bar.value = timer_node.time_left
		var frac: float = clamp(timer_node.time_left / placement_timeout, 0.0, 1.0)
		if _timer_fill_style:
			_timer_fill_style.bg_color = Color(0.95, 0.25, 0.25).lerp(Color(0.3, 0.9, 0.45), frac)
		if timer_node.time_left < 2.0:
			timer_bar.modulate = Color(1, 1, 1, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02))
		else:
			timer_bar.modulate = Color(1, 1, 1, 1)
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
	var target_local: Vector2 = target - board.global_position

	if piece.position.distance_to(target_local) <= snap_radius:
		_snap_piece(piece, idx, target_local)
		_restart_timer()
		_check_complete()
	else:
		_flash_piece_wrong(piece)
		_restart_timer()

func _snap_piece(piece: Control, idx: int, target_local: Vector2) -> void:
	piece.position = target_local
	piece_placed[idx] = true
	var style: StyleBoxFlat = piece.get_meta("style")
	style.bg_color.a = 1.0
	var orig_border := style.border_color

	var tw := create_tween()
	tw.tween_property(piece, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(piece, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_property(style, "border_color", Color(0.4, 1.0, 0.5, 1.0), 0.1)
	tw2.tween_property(style, "border_color", orig_border, 0.4)

	snap_particles.position = target_local + PIECE_SIZE / 2.0
	snap_particles.restart()
	snap_particles.emitting = true

func _flash_piece_wrong(piece: Control) -> void:
	var style: StyleBoxFlat = piece.get_meta("style")
	var original := style.border_color
	var tw := create_tween()
	tw.tween_property(style, "border_color", Color(1, 0.25, 0.25, 0.95), 0.06)
	tw.tween_property(style, "border_color", original, 0.35)

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
		var style: StyleBoxFlat = pieces[i].get_meta("style")
		style.bg_color.a = 0.75
		var tw := create_tween()
		tw.tween_property(pieces[i], "position", _random_scatter_pos(cols, rows), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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

	var cols := int(sqrt(float(piece_count)))
	win_particles.position = board_offset + Vector2(cols, cols) * PIECE_SIZE / 2.0
	win_particles.restart()
	win_particles.emitting = true

	success_overlay.visible = true
	success_overlay.modulate = Color(1, 1, 1, 0)
	success_label.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(success_overlay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(success_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
