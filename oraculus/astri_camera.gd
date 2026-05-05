extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5)
@export var max_zoom: Vector2 = Vector2(0, 0)
@export var zoom_speed: float = 0.1
@export var camera_path: NodePath
@export var player_path: NodePath
@export var offset_inside: Vector2 = Vector2(0, -40) 
@export var offset_speed: float = 0.1

var camera: Camera2D
var player: Node2D
var player_inside: bool = false

func _ready():
	camera = get_node(camera_path) as Camera2D
	player = get_node(player_path) as Node2D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body == player:
		player_inside = true

func _on_body_exited(body: Node2D):
	if body == player:
		player_inside = false

func _process(delta: float):
	if camera:
		var target_zoom = max_zoom if player_inside else min_zoom
		camera.zoom = camera.zoom.lerp(target_zoom, zoom_speed)

		var target_offset = offset_inside if player_inside else Vector2.ZERO
		camera.offset = camera.offset.lerp(target_offset, offset_speed)
