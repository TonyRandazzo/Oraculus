extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5)
@export var max_zoom: Vector2 = Vector2(0, 0)
@export var threshold: float = 0.7
@export var offset_at_center: Vector2 = Vector2(0, 0)
@export var offset_at_edge: Vector2 = Vector2(0, 0)
@export var camera_path: NodePath
@export var player_path: NodePath

@export_group("Modalita' camera fissa")
@export var fixed_camera_point: NodePath   
@export var fixed_zoom: Vector2 = Vector2(0, 0)
@export var lerp_speed: float = 0.1

var camera: Camera2D
var player: Node2D
var fixed_point_node: Node2D
var is_fixed: bool = false
var camera_local_pos_before: Vector2  

func _ready():
	camera = get_node(camera_path) as Camera2D
	player = get_node(player_path) as Node2D
	if fixed_camera_point != NodePath():
		fixed_point_node = get_node(fixed_camera_point) as Node2D

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body == player and not is_fixed:
		player.z_index = 2
		is_fixed = true
		camera_local_pos_before = camera.position
		camera.top_level = true

func _on_body_exited(body: Node2D) -> void:
	if body == player and is_fixed:
		player.z_index = 1
		is_fixed = false
		camera.top_level = false
		camera.position = camera_local_pos_before

func _process(delta: float) -> void:
	if not player or not camera:
		return

	if is_fixed:
		# --- Camera ferma su un punto fisso, zoom (0,0) ---
		if fixed_point_node:
			camera.global_position = camera.global_position.lerp(fixed_point_node.global_position, lerp_speed)
		camera.zoom = camera.zoom.lerp(fixed_zoom, lerp_speed)
		return

	# --- Comportamento originale: zoom/offset in base alla posizione del player nell'area ---
	var shape := $CollisionShape2D.shape as RectangleShape2D
	var extents: Vector2 = shape.extents
	var local_pos: Vector2 = to_local(player.global_position)
	var t_x = abs(local_pos.x) / extents.x
	var t_y = abs(local_pos.y) / extents.y
	var t = clamp(max(t_x, t_y), 0.0, 1.0)
	var t_mapped: float
	if t <= threshold:
		t_mapped = 0.0
	else:
		t_mapped = (t - threshold) / (1.0 - threshold)

	var target_zoom = max_zoom.lerp(min_zoom, t_mapped)
	camera.zoom = camera.zoom.lerp(target_zoom, 0.1)

	var target_offset = offset_at_center.lerp(offset_at_edge, t_mapped)
	camera.offset = camera.offset.lerp(target_offset, 0.1)
