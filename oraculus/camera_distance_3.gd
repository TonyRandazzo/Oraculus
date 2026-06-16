extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5)
@export var max_zoom: Vector2 = Vector2(0, 0)

@export var zoom_speed: float = 7.0
@export var offset_speed: float = 3.0

@export var camera_path: NodePath
@export var player_path: NodePath

@export var offset_inside: Vector2 = Vector2(0, -40)

var camera: Camera2D
var player: Node2D
var player_inside: bool = false

func _ready() -> void:
	camera = get_node(camera_path) as Camera2D
	player = get_node(player_path) as Node2D

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_inside = false

func _process(delta: float) -> void:
	if not camera:
		return

	var target_zoom: Vector2 = max_zoom if player_inside else min_zoom
	var target_offset: Vector2 = offset_inside if player_inside else Vector2.ZERO

	# Zoom fluido e indipendente dagli FPS
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_speed * delta)

	# Offset fluido e indipendente dagli FPS
	camera.offset = camera.offset.lerp(target_offset, offset_speed * delta)
