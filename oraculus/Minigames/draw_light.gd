extends CanvasLayer

signal completed

const MAX_POINTS := 400
const HIT_RADIUS := 28.0
const MIN_DRAW_LENGTH := 40.0

@onready var overlay: ColorRect = $Overlay
@onready var light_source: Node2D = $DrawPanel/LightSource
@onready var target_node: Node2D = $DrawPanel/Target
@onready var light_flow: Line2D = $DrawPanel/LightFlow
@onready var drawn_path: Line2D = $DrawPanel/DrawnPath
@onready var reflected_beam: Line2D = $DrawPanel/ReflectedBeam
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var reset_btn: Button = $HUD/ResetButton
@onready var close_btn: Button = $HUD/CloseButton
@onready var success_overlay: Control = $SuccessOverlay

var drawing: bool = false
var solved: bool = false
var door_id: String = ""

func _ready() -> void:
	reset_btn.pressed.connect(_reset_drawing)
	close_btn.pressed.connect(_close)
	visible = false

func activate(id: String) -> void:
	door_id = id
	solved = false
	_reset_drawing()
	success_overlay.visible = false
	feedback_label.text = "Draw a path to redirect the light beam to the target."

func _input(event: InputEvent) -> void:
	if not visible or solved:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing = true
			drawn_path.clear_points()
			reflected_beam.clear_points()
			get_viewport().set_input_as_handled()
		else:
			drawing = false
			if drawn_path.get_point_count() > 1:
				_check_solution()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and drawing:
		var local_pos := _to_panel_local(event.position)
		if drawn_path.get_point_count() == 0 or local_pos.distance_to(drawn_path.get_point_position(drawn_path.get_point_count() - 1)) > 4.0:
			drawn_path.add_point(local_pos)
			if drawn_path.get_point_count() > MAX_POINTS:
				drawn_path.remove_point(0)
			_update_reflected_beam()
		get_viewport().set_input_as_handled()

func _to_panel_local(screen_pos: Vector2) -> Vector2:
	var panel := $DrawPanel
	return screen_pos - panel.global_position

func _update_reflected_beam() -> void:
	reflected_beam.clear_points()
	if drawn_path.get_point_count() < 2:
		return

	var source_pos := light_source.position
	var flow_dir := _get_flow_direction()

	# Find intersection of LightFlow with DrawnPath
	var intersect := _find_intersection(source_pos, flow_dir)
	if intersect == Vector2.INF:
		return

	# Mirror normal at intersection
	var path_normal := _get_path_normal_at(intersect)
	var reflected_dir := flow_dir.reflect(path_normal)

	reflected_beam.add_point(intersect)
	reflected_beam.add_point(intersect + reflected_dir * 600.0)

func _get_flow_direction() -> Vector2:
	if light_flow.get_point_count() < 2:
		return Vector2.RIGHT
	var p0 := light_flow.get_point_position(0)
	var p1 := light_flow.get_point_position(1)
	return (p1 - p0).normalized()

func _find_intersection(ray_origin: Vector2, ray_dir: Vector2) -> Vector2:
	var pts := drawn_path.get_point_count()
	if pts < 2:
		return Vector2.INF

	var best := Vector2.INF
	var best_dist := INF

	for i in range(pts - 1):
		var a := drawn_path.get_point_position(i)
		var b := drawn_path.get_point_position(i + 1)
		var hit := _ray_segment_intersect(ray_origin, ray_dir, a, b)
		if hit != Vector2.INF:
			var d := ray_origin.distance_to(hit)
			if d < best_dist:
				best_dist = d
				best = hit

	return best

func _ray_segment_intersect(ro: Vector2, rd: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var seg := b - a
	var denom := rd.x * seg.y - rd.y * seg.x
	if abs(denom) < 0.0001:
		return Vector2.INF
	var t := ((a.x - ro.x) * seg.y - (a.y - ro.y) * seg.x) / denom
	var u := ((a.x - ro.x) * rd.y - (a.y - ro.y) * rd.x) / denom
	if t >= 0.0 and u >= 0.0 and u <= 1.0:
		return ro + rd * t
	return Vector2.INF

func _get_path_normal_at(point: Vector2) -> Vector2:
	var pts := drawn_path.get_point_count()
	var best_idx := 0
	var best_dist := INF
	for i in range(pts):
		var d := point.distance_to(drawn_path.get_point_position(i))
		if d < best_dist:
			best_dist = d
			best_idx = i

	var i0 = max(best_idx - 1, 0)
	var i1 = min(best_idx + 1, pts - 1)
	var tangent := (drawn_path.get_point_position(i1) - drawn_path.get_point_position(i0)).normalized()
	return Vector2(-tangent.y, tangent.x)

func _check_solution() -> void:
	if reflected_beam.get_point_count() < 2:
		feedback_label.text = "The light doesn't touch your path. Try again."
		return

	var beam_end := reflected_beam.get_point_position(1)
	var target_pos := target_node.position

	if beam_end.distance_to(target_pos) <= HIT_RADIUS:
		_win()
	else:
		feedback_label.text = "Close, but the beam misses the target. Adjust your path."

func _win() -> void:
	solved = true
	success_overlay.visible = true
	await get_tree().create_timer(2.0).timeout
	visible = false
	emit_signal("completed")

func _reset_drawing() -> void:
	drawn_path.clear_points()
	reflected_beam.clear_points()
	drawing = false
	if feedback_label:
		feedback_label.text = "Draw a path to redirect the light."

func _close() -> void:
	visible = false
