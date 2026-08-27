extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5)   # zoom piu' vicino (bordo area)
@export var max_zoom: Vector2 = Vector2(1, 1)       # zoom piu' lontano (centro area)
@export var zoom_speed: float = 0.15

# Spostamento della camera, interpolato come lo zoom.
# Default a zero: le zone che non lo impostano si comportano come prima.
@export var offset_at_center: Vector2 = Vector2(0, 0)   # al centro dell'area
@export var offset_at_edge: Vector2 = Vector2(0, 0)     # al bordo dell'area

@export var camera_path: NodePath
@export var player_path: NodePath

# Lo zoom di un Camera2D non puo' essere 0 ne' negativo.
const MIN_SAFE_ZOOM := 0.05
# Meta sul Camera2D: dice quale zona sta pilotando la camera in questo momento.
const OWNER_META := "cam_zoom_owner"

var camera: Camera2D
var player: Node2D
var default_zoom: Vector2 = Vector2.ONE
var default_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera2D
	player = get_node_or_null(player_path) as Node2D
	if camera:
		default_zoom = camera.zoom
		default_offset = camera.offset

func _process(_delta: float) -> void:
	if not camera or not player:
		return

	var raw_t := _player_raw_t()

	# Player fuori dall'area: la camera non si tocca piu'.
	# Senza questo controllo tutte le zone CameraDistance della scena
	# scrivevano sullo stesso Camera2D ogni frame, contendendosi lo zoom.
	if raw_t < 0.0 or raw_t > 1.0:
		if _is_owner():
			_restore_step()
		return

	if not _is_owner():
		if _has_owner():
			return   # un'altra zona sta gia' pilotando la camera
		_claim_camera()

	var t := clampf(raw_t, 0.0, 1.0)

	var target_zoom: Vector2 = max_zoom.lerp(min_zoom, t)
	camera.zoom = camera.zoom.lerp(_safe_zoom(target_zoom), zoom_speed)

	var target_offset: Vector2 = offset_at_center.lerp(offset_at_edge, t)
	camera.offset = camera.offset.lerp(target_offset, zoom_speed)

# Posizione del player rispetto al rettangolo dell'area:
# 0 = centro, 1 = bordo, > 1 = fuori. -1 se la forma non e' utilizzabile.
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

# Riporta dolcemente la camera ai valori originali e poi molla il controllo.
func _restore_step() -> void:
	camera.zoom = camera.zoom.lerp(default_zoom, zoom_speed)
	camera.offset = camera.offset.lerp(default_offset, zoom_speed)
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
