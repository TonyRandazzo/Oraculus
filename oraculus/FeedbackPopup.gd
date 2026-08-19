extends Node

# Mostra numeri fluttuanti sopra gli NPC quando cambiano amicizia/ostilità.
# Giallo verso l'alto = amicizia aumentata. Rosso verso il basso = amicizia
# diminuita o ostilità aumentata. Se entrambe cambiano, vengono mostrate in coda.

const FONT := preload("res://oraculus/thirdparty/kenney/fonts/Fonts/Kenney Pixel.ttf")

const RISE_DISTANCE := 40.0
const FALL_DISTANCE := 40.0
const DURATION := 2.1
const QUEUE_GAP := 0.45

func show_stat_change(target: Node2D, friendship_delta: int, hostility_delta: int) -> void:
	var queue: Array = []
	if friendship_delta > 0:
		queue.append({"text": "+%d friendship" % friendship_delta, "color": Color.YELLOW, "rise": true})
	elif friendship_delta < 0:
		queue.append({"text": "%d friendship" % friendship_delta, "color": Color.RED, "rise": false})
	if hostility_delta > 0:
		queue.append({"text": "+%d hostility" % hostility_delta, "color": Color.RED, "rise": false})
	_play_queue(target, queue)

func _play_queue(target: Node2D, queue: Array) -> void:
	if queue.is_empty() or not is_instance_valid(target):
		return
	var entry: Dictionary = queue.pop_front()
	_spawn_popup(target, entry["text"], entry["color"], entry["rise"])
	if not queue.is_empty():
		await get_tree().create_timer(QUEUE_GAP).timeout
		_play_queue(target, queue)

func _spawn_popup(target: Node2D, text: String, color: Color, rise: bool) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 4095
	label.scale = Vector2(0.2, 0.2)
	label.position = Vector2(-1.0, -20.0)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	target.add_child(label)

	var distance := -RISE_DISTANCE if rise else FALL_DISTANCE
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + distance, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(label.queue_free)
