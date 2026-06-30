extends CanvasLayer

signal completed

@export var min_bounces: int = 1
@export var max_bounces: int = 3
@export var mirror_half_length: float = 28.0
@export var min_bend_degrees: float = 25.0

const SOURCE_POS := Vector2(120, 300)
const TARGET_POS := Vector2(800, 220)
const TARGET_RADIUS := 20.0
const PLAY_Y_MIN := 90.0
const PLAY_Y_MAX := 480.0
const MAX_BOUNCE_STEPS := 8
const BEAM_OVERSHOOT := 1200.0

@onready var draw_panel: Node2D = $DrawPanel
@onready var light_source: Node2D = $DrawPanel/LightSource
@onready var target_node: Node2D = $DrawPanel/Target
@onready var mirrors_node: Node2D = $DrawPanel/Mirrors
@onready var beam_line: Line2D = $DrawPanel/BeamLine
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var close_btn: Button = $HUD/CloseButton
@onready var success_overlay: Control = $SuccessOverlay

var solved: bool = false
var door_id: String = ""
var mirror_data: Array[Dictionary] = []

func _ready() -> void:
	close_btn.pressed.connect(_close)
	visible = false

func activate(id: String) -> void:
	door_id = id
	solved = false
	success_overlay.visible = false
	feedback_label.text = "Move the mouse to aim the source. Bounce the light off the mirrors to hit the target."
	light_source.position = SOURCE_POS
	target_node.position = TARGET_POS
	_generate_layout()

func _process(_delta: float) -> void:
	if not visible or solved:
		return

	var mouse_local := get_viewport().get_mouse_position() - draw_panel.global_position
	var aim_dir := mouse_local - SOURCE_POS
	if aim_dir.length() < 1.0:
		aim_dir = Vector2.RIGHT
	aim_dir = aim_dir.normalized()
	light_source.rotation = aim_dir.angle()

	var result := _compute_beam_path(SOURCE_POS, aim_dir)
	beam_line.points = PackedVector2Array(result["points"])

	if result["hit_target"]:
		_win()

func _input(event: InputEvent) -> void:
	if not visible or solved:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

# ── Generazione procedurale (sempre risolvibile) ──────────────────────────────
func _generate_layout() -> void:
	for c in mirrors_node.get_children():
		c.queue_free()
	mirror_data.clear()

	var bounces := randi_range(min_bounces, max_bounces)
	var x_start := SOURCE_POS.x + 120.0
	var x_end := TARGET_POS.x - 120.0
	var step := (x_end - x_start) / float(max(bounces, 1))

	var full_path: Array[Vector2] = [SOURCE_POS]
	for i in range(bounces):
		var x := x_start + step * i + randf_range(-step * 0.25, step * 0.25)
		var y := randf_range(PLAY_Y_MIN, PLAY_Y_MAX)
		full_path.append(Vector2(x, y))
	full_path.append(TARGET_POS)

	for i in range(1, full_path.size() - 1):
		var prev: Vector2 = full_path[i - 1]
		var cur: Vector2 = full_path[i]
		var nxt: Vector2 = full_path[i + 1]
		var d_in := (cur - prev).normalized()
		var d_out := (nxt - cur).normalized()

		# Garantisce una piegatura minima visibile, altrimenti riprova con un altro y
		var attempts := 0
		while abs(d_in.angle_to(d_out)) < deg_to_rad(min_bend_degrees) and attempts < 12:
			cur.y = randf_range(PLAY_Y_MIN, PLAY_Y_MAX)
			full_path[i] = cur
			d_in = (cur - prev).normalized()
			d_out = (nxt - cur).normalized()
			attempts += 1

		var normal := (d_out - d_in).normalized()
		var tangent := Vector2(-normal.y, normal.x)
		var a := cur - tangent * mirror_half_length
		var b := cur + tangent * mirror_half_length

		mirror_data.append({"a": a, "b": b, "normal": normal})

		var line := Line2D.new()
		line.points = PackedVector2Array([a, b])
		line.width = 5.0
		line.default_color = Color(0.65, 0.8, 0.95, 0.95)
		mirrors_node.add_child(line)

# ── Simulazione del raggio con rimbalzi ────────────────────────────────────────
func _compute_beam_path(start_pos: Vector2, start_dir: Vector2) -> Dictionary:
	var points: Array[Vector2] = [start_pos]
	var pos := start_pos
	var dir := start_dir.normalized()
	var hit_target := false

	for i in range(MAX_BOUNCE_STEPS):
		var nearest_t := INF
		var nearest_point := Vector2.ZERO
		var nearest_type := ""
		var nearest_normal := Vector2.ZERO

		var target_hit = _ray_circle_intersect(pos, dir, TARGET_POS, TARGET_RADIUS)
		if target_hit != null:
			var t: float = (target_hit - pos).length()
			if t < nearest_t:
				nearest_t = t
				nearest_point = target_hit
				nearest_type = "target"

		for m in mirror_data:
			var hit := _ray_segment_intersect(pos, dir, m["a"], m["b"])
			if hit != Vector2.INF:
				var t: float = (hit - pos).length()
				if t > 0.5 and t < nearest_t:
					nearest_t = t
					nearest_point = hit
					nearest_type = "mirror"
					nearest_normal = m["normal"]

		if nearest_type == "":
			points.append(pos + dir * BEAM_OVERSHOOT)
			break

		points.append(nearest_point)

		if nearest_type == "target":
			hit_target = true
			break

		dir = dir.bounce(nearest_normal)
		pos = nearest_point + dir * 0.6

	return {"points": points, "hit_target": hit_target}

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

func _ray_circle_intersect(ro: Vector2, rd: Vector2, center: Vector2, radius: float) -> Variant:
	var oc := ro - center
	var b := oc.dot(rd)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return null
	var sqrt_disc := sqrt(disc)
	var t1 := -b - sqrt_disc
	var t2 := -b + sqrt_disc
	var t := t1 if t1 >= 0.001 else t2
	if t < 0.001:
		return null
	return ro + rd * t

# ── Vittoria / chiusura ────────────────────────────────────────────────────────
func _win() -> void:
	solved = true
	success_overlay.visible = true
	await get_tree().create_timer(2.0).timeout
	visible = false
	emit_signal("completed")

func _close() -> void:
	visible = false
