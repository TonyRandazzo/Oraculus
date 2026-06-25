extends Area2D

@export var min_zoom: Vector2 = Vector2(3.5, 3.5) 
@export var max_zoom: Vector2 = Vector2(0, 0) 
@export var camera_path: NodePath
@export var player_path: NodePath

var camera: Camera2D
var player: Node2D

func _ready():
	camera = get_node(camera_path) as Camera2D
	player = get_node(player_path) as Node2D

func _process(delta: float):
	if player and camera:
		var shape := $CollisionShape2D.shape as RectangleShape2D
		var extents: Vector2 = shape.extents

		var local_pos: Vector2 = to_local(player.global_position)

		var t_x = abs(local_pos.x) / extents.x
		var t_y = abs(local_pos.y) / extents.y

		var t = clamp(max(t_x, t_y), 0.0, 1.0)

		var target_zoom = max_zoom.lerp(min_zoom, t)

		camera.zoom = camera.zoom.lerp(target_zoom, 0.1)
