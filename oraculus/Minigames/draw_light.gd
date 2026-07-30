extends CanvasLayer

signal completed

@export var min_bounces: int = 3
@export var max_bounces: int = 5
@export var mirror_half_length: float = 38.0
@export var min_bend_degrees: float = 25.0
@export var max_bend_degrees: float = 150.0

const SOURCE_POS := Vector2(120, 300)
const TARGET_POS := Vector2(800, 220)
const TARGET_RADIUS := 20.0
const PLAY_Y_MIN := 90.0
const PLAY_Y_MAX := 480.0
const MAX_BOUNCE_STEPS := 8
const BEAM_OVERSHOOT := 1200.0

# Barriera fissa che blocca sempre la linea diretta sorgente → bersaglio:
# la luce può raggiungere il bersaglio solo rimbalzando sugli specchi.
const WALL_A := Vector2(460, 220)
const WALL_B := Vector2(460, 300)

@onready var overlay_rect: ColorRect = $Overlay
@onready var draw_panel: Node2D = $DrawPanel
@onready var light_source: Node2D = $DrawPanel/LightSource
@onready var light_glow: Sprite2D = $DrawPanel/LightSource/Glow
@onready var target_node: Node2D = $DrawPanel/Target
@onready var target_glow: Sprite2D = $DrawPanel/Target/Glow
@onready var target_ring_node: Node2D = $DrawPanel/Target/TargetRing
@onready var mirrors_node: Node2D = $DrawPanel/Mirrors
@onready var beam_line: Line2D = $DrawPanel/BeamLine
@onready var beam_glow: Line2D = $DrawPanel/BeamGlow
@onready var win_particles: CPUParticles2D = $DrawPanel/WinParticles
@onready var feedback_label: Label = $HUD/FeedbackPanel/FeedbackLabel
@onready var close_btn: Button = $HUD/CloseButton
@onready var success_overlay: Control = $SuccessOverlay
@onready var success_label: Label = $SuccessOverlay/Label

var solved: bool = false
var door_id: String = ""
var mirror_data: Array[Dictionary] = []
var _t: float = 0.0
var _light_glow_base_scale: Vector2
var _target_glow_base_scale: Vector2
var _target_ring_line: Line2D

func _ready() -> void:
	close_btn.pressed.connect(_close)
	visible = false
	_light_glow_base_scale = light_glow.scale
	_target_glow_base_scale = target_glow.scale
	_build_target_ring()

func _build_target_ring() -> void:
	var ring := Line2D.new()
	ring.width = 2.5
	ring.closed = true
	ring.default_color = Color(1, 0.82, 0.35, 0.9)
	var pts := PackedVector2Array()
	var radius := TARGET_RADIUS + 8.0
	for i in range(33):
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.points = pts
	target_ring_node.add_child(ring)
	_target_ring_line = ring

func activate(id: String) -> void:
	door_id = id
	solved = false
	success_overlay.visible = false
	success_overlay.modulate = Color(1, 1, 1, 0)
	feedback_label.text = "Move the mouse to aim the source. Bounce the light off the mirrors to hit the target."
	light_source.position = SOURCE_POS
	target_node.position = TARGET_POS
	_generate_layout()

func _process(delta: float) -> void:
	if not visible:
		return

	_t += delta
	light_glow.scale = _light_glow_base_scale * (1.0 + 0.12 * sin(_t * 4.0))
	target_glow.scale = _target_glow_base_scale * (1.0 + 0.1 * sin(_t * 3.0 + 1.0))
	target_ring_node.scale = Vector2.ONE * (1.0 + 0.14 * sin(_t * 3.2))
	if _target_ring_line:
		_target_ring_line.modulate.a = 0.6 + 0.4 * sin(_t * 3.2)

	if solved:
		return

	var mouse_local := get_viewport().get_mouse_position() - draw_panel.global_position
	var aim_dir := mouse_local - SOURCE_POS
	if aim_dir.length() < 1.0:
		aim_dir = Vector2.RIGHT
	aim_dir = aim_dir.normalized()
	light_source.rotation = aim_dir.angle()

	var result := _compute_beam_path(SOURCE_POS, aim_dir)
	beam_line.points = PackedVector2Array(result["points"])
	beam_glow.points = beam_line.points

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

		# Garantisce una piegatura sempre "obliqua" (mai troppo dritta né un
		# rimbalzo quasi perpendicolare all'indietro) e che nessun tratto del
		# percorso tagli la barriera centrale, altrimenti riprova con un altro y
		var attempts := 0
		var bend: float = abs(d_in.angle_to(d_out))
		var blocked := _segments_intersect(prev, cur, WALL_A, WALL_B) or _segments_intersect(cur, nxt, WALL_A, WALL_B)
		while (bend < deg_to_rad(min_bend_degrees) or bend > deg_to_rad(max_bend_degrees) or blocked) and attempts < 30:
			cur.y = randf_range(PLAY_Y_MIN, PLAY_Y_MAX)
			full_path[i] = cur
			d_in = (cur - prev).normalized()
			d_out = (nxt - cur).normalized()
			bend = abs(d_in.angle_to(d_out))
			blocked = _segments_intersect(prev, cur, WALL_A, WALL_B) or _segments_intersect(cur, nxt, WALL_A, WALL_B)
			attempts += 1

		var normal := (d_out - d_in).normalized()
		var tangent := Vector2(-normal.y, normal.x)
		var a := cur - tangent * mirror_half_length
		var b := cur + tangent * mirror_half_length

		mirror_data.append({"a": a, "b": b, "normal": normal})
		_add_mirror_visual(a, b)

func _add_mirror_visual(a: Vector2, b: Vector2) -> void:
	var outline := Line2D.new()
	outline.points = PackedVector2Array([a, b])
	outline.width = 9.0
	outline.default_color = Color(0.12, 0.07, 0.03, 0.6)
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	mirrors_node.add_child(outline)

	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = 5.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(0.6, 0.45, 0.22, 0.7),
		Color(1.0, 0.94, 0.75, 1.0),
		Color(0.6, 0.45, 0.22, 0.7),
	])
	line.gradient = grad
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

		var wall_hit := _ray_segment_intersect(pos, dir, WALL_A, WALL_B)
		if wall_hit != Vector2.INF:
			var t: float = (wall_hit - pos).length()
			if t > 0.5 and t < nearest_t:
				nearest_t = t
				nearest_point = wall_hit
				nearest_type = "wall"

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

		if nearest_type == "wall":
			break

		dir = dir.bounce(nearest_normal)
		pos = nearest_point + dir * 0.6

	return {"points": points, "hit_target": hit_target}

func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1 := p2 - p1
	var d2 := p4 - p3
	var denom := d1.x * d2.y - d1.y * d2.x
	if abs(denom) < 0.0001:
		return false
	var t := ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denom
	var u := ((p3.x - p1.x) * d1.y - (p3.y - p1.y) * d1.x) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

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
	_flash_screen()
	win_particles.position = target_node.position
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

func _flash_screen() -> void:
	var original_color := overlay_rect.color
	var tw := create_tween()
	tw.tween_property(overlay_rect, "color", Color(1, 0.92, 0.7, 0.85), 0.08)
	tw.tween_property(overlay_rect, "color", original_color, 0.4)

func _close() -> void:
	visible = false
