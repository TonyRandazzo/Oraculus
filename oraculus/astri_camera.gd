extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5)   
@export var max_zoom: Vector2 = Vector2(1, 1)       
@export var threshold: float = 0.7
@export var offset_at_center: Vector2 = Vector2(0, 0)
@export var offset_at_edge: Vector2 = Vector2(0, 0)
@export var camera_path: NodePath
@export var player_path: NodePath

@export_group("Modalita' camera fissa")
@export var fixed_camera_point: NodePath
@export var fixed_zoom: Vector2 = Vector2(1.5, 1.5)     
@export var lerp_speed: float = 0.1


const MIN_SAFE_ZOOM := 0.05
const OWNER_META := "cam_zoom_owner"
const RELEASE_MARGIN := 1.5

var camera: Camera2D
var player: Node2D
var fixed_point_node: Node2D
var is_fixed: bool = false
var camera_local_pos_before: Vector2
var default_zoom: Vector2 = Vector2.ONE
var default_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera2D
	player = get_node_or_null(player_path) as Node2D
	if fixed_camera_point != NodePath():
		fixed_point_node = get_node_or_null(fixed_camera_point) as Node2D
	if camera:
		default_zoom = camera.zoom
		default_offset = camera.offset

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body == player and not is_fixed:
		_enter_fixed()

func _on_body_exited(body: Node2D) -> void:
	if body == player and is_fixed:
		_exit_fixed()

func _enter_fixed() -> void:
	player.z_index = 2
	is_fixed = true
	_claim_camera()
	camera_local_pos_before = camera.position
	var g := camera.global_position
	camera.top_level = true
	camera.global_position = g   

func _exit_fixed() -> void:
	player.z_index = 1
	is_fixed = false
	camera.top_level = false
	camera.position = camera_local_pos_before

func _process(_delta: float) -> void:
	if not player or not camera:
		return

	var raw_t := _player_raw_t()

	if is_fixed:
		if raw_t > RELEASE_MARGIN:
			_exit_fixed()
			return
		if fixed_point_node:
			camera.global_position = camera.global_position.lerp(fixed_point_node.global_position, lerp_speed)
		camera.zoom = camera.zoom.lerp(_safe_zoom(fixed_zoom), lerp_speed)
		return

	if raw_t < 0.0 or raw_t > 1.0:
		if _is_owner():
			_restore_step()
		return

	if not _is_owner():
		if _has_owner():
			return   
		_claim_camera()

	var t := clampf(raw_t, 0.0, 1.0)
	var t_mapped: float
	if t <= threshold:
		t_mapped = 0.0
	else:
		t_mapped = (t - threshold) / (1.0 - threshold)

	var target_zoom: Vector2 = max_zoom.lerp(min_zoom, t_mapped)
	camera.zoom = camera.zoom.lerp(_safe_zoom(target_zoom), lerp_speed)

	var target_offset: Vector2 = offset_at_center.lerp(offset_at_edge, t_mapped)
	camera.offset = camera.offset.lerp(target_offset, lerp_speed)

func _player_raw_t() -> float:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return -1.0
	var shape := col.shape as RectangleShape2D
	if shape == null:
		return -1.0
	var extents: Vector2 = shape.size * 0.5
	if extents.x <= 0.0 or extents.y <= 0.0:
		return -1.0
	var local_pos: Vector2 = col.to_local(player.global_position)
	return maxf(absf(local_pos.x) / extents.x, absf(local_pos.y) / extents.y)

func _restore_step() -> void:
	camera.zoom = camera.zoom.lerp(default_zoom, lerp_speed)
	camera.offset = camera.offset.lerp(default_offset, lerp_speed)
	if camera.zoom.distance_to(default_zoom) < 0.01 and camera.offset.distance_to(default_offset) < 0.5:
		camera.zoom = default_zoom
		camera.offset = default_offset
		_release_camera()

func _safe_zoom(z: Vector2) -> Vector2:
	return Vector2(maxf(z.x, MIN_SAFE_ZOOM), maxf(z.y, MIN_SAFE_ZOOM))

func _claim_camera() -> void:
	camera.set_meta(OWNER_META, get_instance_id())

func _release_camera() -> void:
	if _is_owner():
		camera.remove_meta(OWNER_META)

func _has_owner() -> bool:
	if not camera.has_meta(OWNER_META):
		return false
	return is_instance_id_valid(int(camera.get_meta(OWNER_META)))

func _is_owner() -> bool:
	if not camera.has_meta(OWNER_META):
		return false
	return int(camera.get_meta(OWNER_META)) == get_instance_id()
