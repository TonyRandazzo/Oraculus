@tool
extends Node2D
## Liana appesa: un Node2D fatto di segmenti (texturizzabili) che si allunga o
## accorcia dall'editor cambiando [member segment_count].
##
## I segmenti sono una vera catena fisica 2D: ogni giunto ha massa, subisce la
## gravità e viene integrato in Verlet, poi i vincoli di distanza tengono uniti i
## segmenti. La liana non è quindi un pendolo rigido: si incurva, frusta e
## conserva lo slancio da sola.
##
## Non ha nessuna collisione fisica: il giocatore ci passa attraverso e non ci si
## può fare wall jump. C'è solo un'area di aggancio: chi la tocca in aria ci si
## aggrappa (stessa animazione dello strisciare sul muro), può salire e scendere
## lungo la liana e spingere a destra e sinistra per prendere slancio.
##
## La spinta del giocatore è una forza orizzontale vera, non un angolo imposto:
## tenendo premuta una direzione la liana si ferma poco oltre la verticale, quindi
## per arrivare in alto bisogna pompare a tempo, e dall'apertura massima si torna
## indietro anche continuando a tenere premuto.

signal grabbed(player: Node)
signal released(player: Node)

@export_group("Forma")
## Quanti segmenti: è così che si allunga o accorcia la liana.
@export_range(1, 64, 1, "or_greater") var segment_count: int = 8:
	set(value):
		segment_count = maxi(1, value)
		_refresh()
## Lunghezza di un segmento in pixel. 0 = usa l'altezza della texture.
@export_range(0.0, 128.0, 0.5, "or_greater") var segment_length: float = 0.0:
	set(value):
		segment_length = maxf(0.0, value)
		_refresh()
## Texture ripetuta su ogni segmento (lasciala vuota per la liana disegnata a linea).
@export var segment_texture: Texture2D:
	set(value):
		segment_texture = value
		_refresh()
## Scala della texture del segmento (1.0 = dimensione originale)
@export_range(0.1, 5.0, 0.05) var segment_texture_scale: float = 1.0:
	set(value):
		segment_texture_scale = maxf(0.1, value)
		_refresh()
## Altezza fissa della texture del segmento in pixel (0 = usa altezza originale * scala)
@export_range(0.0, 512.0, 1.0) var segment_texture_height: float = 0.0:
	set(value):
		segment_texture_height = maxf(0.0, value)
		_refresh()
## Texture opzionale solo per l'ultimo segmento, la punta della liana.
@export var tip_texture: Texture2D:
	set(value):
		tip_texture = value
		_refresh()
## Scala della texture della punta (1.0 = dimensione originale)
@export_range(0.1, 5.0, 0.05) var tip_texture_scale: float = 1.0:
	set(value):
		tip_texture_scale = maxf(0.1, value)
		_refresh()
## Altezza fissa della texture della punta in pixel (0 = usa altezza originale * scala)
@export_range(0.0, 512.0, 1.0) var tip_texture_height: float = 0.0:
	set(value):
		tip_texture_height = maxf(0.0, value)
		_refresh()
## Texture opzionale dell'attacco al soffitto, disegnata sul punto d'ancoraggio.
@export var anchor_texture: Texture2D:
	set(value):
		anchor_texture = value
		_refresh()
## Scala della texture dell'ancoraggio (1.0 = dimensione originale)
@export_range(0.1, 5.0, 0.05) var anchor_texture_scale: float = 1.0:
	set(value):
		anchor_texture_scale = maxf(0.1, value)
		_refresh()
## Altezza fissa della texture dell'ancoraggio in pixel (0 = usa altezza originale * scala)
@export_range(0.0, 512.0, 1.0) var anchor_texture_height: float = 0.0:
	set(value):
		anchor_texture_height = maxf(0.0, value)
		_refresh()
## Specchia un segmento sì e uno no, così la ripetizione si nota meno.
@export var alternate_flip: bool = true:
	set(value):
		alternate_flip = value
		_refresh()
@export_range(0.05, 8.0, 0.05, "or_greater") var texture_scale: float = 1.0:
	set(value):
		texture_scale = maxf(0.05, value)
		_refresh()

@export_group("Disegno senza texture")
@export var line_color: Color = Color(0.29, 0.5, 0.24):
	set(value):
		line_color = value
		queue_redraw()
@export_range(0.5, 16.0, 0.5) var line_width: float = 3.0:
	set(value):
		line_width = maxf(0.5, value)
		queue_redraw()

@export_group("Fisica")
## Gravità che agisce su ogni giunto della catena.
@export var gravity: float = 980.0
## Massa di un singolo segmento di liana.
@export_range(0.1, 20.0, 0.1, "or_greater") var segment_mass: float = 1.0
## Massa del giocatore appeso: più è alta, più la liana è pesante da smuovere.
@export_range(0.1, 40.0, 0.1, "or_greater") var player_mass: float = 6.0
## Forza orizzontale della spinta destra/sinistra. L'accelerazione che ne esce è
## forza / massa, quindi alzare [member player_mass] la rende più faticosa.
@export var swing_force: float = 2000.0
## Attrito della liana appesa: basso = conserva lo slancio fra un'oscillata e l'altra.
@export_range(0.0, 5.0, 0.05) var damping_attached: float = 0.5
## Attrito a liana libera: la riporta ferma da sola.
@export_range(0.0, 5.0, 0.05) var damping_idle: float = 1.5
## Quante volte si risolvono i vincoli di distanza: più alto = catena meno elastica.
@export_range(1, 32) var constraint_iterations: int = 12
## Apertura oltre la quale la liana smette di allargare l'oscillazione.
@export_range(10.0, 89.0, 1.0) var max_angle_degrees: float = 85.0
## Inclinazione della liana ferma, in gradi: serve solo come posa di partenza.
@export_range(-85.0, 85.0, 0.5) var rest_angle_degrees: float = 0.0:
	set(value):
		rest_angle_degrees = value
		_refresh()

@export_group("Aggancio")
## Raggio dell'area di aggancio attorno alla liana (nessuna collisione fisica).
@export_range(1.0, 64.0, 0.5) var grab_radius: float = 10.0:
	set(value):
		grab_radius = maxf(1.0, value)
		_refresh()
## Ci si aggrappa solo stando in aria, così non ci si attacca camminando a terra.
@export var grab_only_in_air: bool = true
## Frazione in alto della liana dove non ci si può aggrappare né arrampicare.
@export_range(0.0, 0.9, 0.05) var min_grab_ratio: float = 0.2
## Velocità con cui si sale e si scende lungo la liana, in pixel al secondo.
@export var climb_speed: float = 70.0
## Scostamento del giocatore rispetto al punto in cui si è aggrappato.
@export var player_offset: Vector2 = Vector2(0, 6)
## Quanto si deve aspettare, dopo essersi staccati, prima di riagganciarsi.
@export var regrab_cooldown: float = 0.4

@export_group("Stacco")
## Quanto viene moltiplicata la velocità orizzontale della liana quando ci si
## stacca: è la spinta in avanti che si guadagna oscillando.
@export var release_horizontal_multiplier: float = 1.8
## Spinta orizzontale fissa in più, nel verso in cui si stava già andando.
## Si attenua da sola se la liana è quasi ferma, così non si viene sparati via
## lasciandosi cadere da una liana immobile.
@export var release_horizontal_boost: float = 120.0
## Sopra questa velocità orizzontale la spinta fissa è al massimo.
@export var release_boost_full_speed: float = 60.0
## Quanta velocità verticale della liana si porta dietro il giocatore.
@export var release_vertical_multiplier: float = 1.15
## Spinta verticale in più quando ci si stacca col salto.
@export var release_jump_boost: float = 260.0
@export var max_release_speed: float = 700.0

# Stato della catena, in coordinate globali: posizione attuale, posizione del
# frame prima (da cui l'integrazione di Verlet ricava la velocità) e massa inversa
# (0 = giunto inchiodato al soffitto).
var _pos: PackedVector2Array = PackedVector2Array()
var _prev: PackedVector2Array = PackedVector2Array()
var _inv_mass: PackedFloat32Array = PackedFloat32Array()
var _last_delta: float = 1.0 / 60.0

var _segments_root: Node2D
var _grab_area: Area2D
var _grab_shapes: Array[CollisionShape2D] = []
var _anchor_sprite: Sprite2D
var _segment_sprites: Array[Sprite2D] = []
var _attached_player: Node = null
var _grab_length: float = 0.0
var _grab_index: int = 1
var _grab_frac: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	_ensure_nodes()
	_refresh()
	if Engine.is_editor_hint():
		# In editor la simulazione è ferma: la catena si ridisegna dritta nella
		# posa di riposo e segue il nodo mentre lo si trascina in scena.
		set_physics_process(false)
		set_notify_transform(true)
	else:
		add_to_group("liana")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_node_ready():
		_reset_points()
		_update_visual()


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if _attached_player != null and not is_instance_valid(_attached_player):
		_attached_player = null
		_cooldown = regrab_cooldown
	# Mentre qualcuno è appeso è il giocatore stesso a chiamare swing_step(), così
	# la simulazione e la sua posizione restano nello stesso frame.
	if _attached_player == null:
		swing_step(delta, 0, 0)
		_try_auto_grab()


# --- API usata dal giocatore -------------------------------------------------

## Avanza la simulazione di un frame.
## [param input_dir]: -1 spinge a sinistra, 1 a destra, 0 nessuna spinta.
## [param climb_dir]: -1 sale lungo la liana, 1 scende.
func swing_step(delta: float, input_dir: int = 0, climb_dir: int = 0) -> void:
	if _pos.size() < 2:
		return
	delta = clampf(delta, 0.0001, 1.0 / 30.0)
	_last_delta = delta
	var attached := _attached_player != null
	if attached and climb_dir != 0:
		_set_grab_length(_grab_length + float(climb_dir) * climb_speed * delta)
	_update_masses()

	var push := Vector2(float(input_dir) * swing_force, 0.0) if attached else Vector2.ZERO
	var damping: float = damping_attached if attached else damping_idle
	var damp_factor: float = maxf(0.0, 1.0 - damping * delta)
	var dt2 := delta * delta

	# Integrazione di Verlet: la velocità è implicita nella differenza fra la
	# posizione attuale e quella del frame precedente.
	for i in range(1, _pos.size()):
		var accel := Vector2(0.0, gravity)
		var weight := _player_weight(i)
		if weight > 0.0:
			accel += push * weight * _inv_mass[i]
		var vel: Vector2 = (_pos[i] - _prev[i]) * damp_factor
		_prev[i] = _pos[i]
		_pos[i] = _pos[i] + vel + accel * dt2

	# Il giunto in cima resta attaccato al nodo, così la liana segue eventuali
	# piattaforme mobili.
	_pos[0] = global_position
	_prev[0] = global_position

	for _i in constraint_iterations:
		_solve_constraints()
	_limit_swing()
	_update_visual()


## Punto globale a cui va tenuto il giocatore appeso.
func get_attach_position() -> Vector2:
	return _sample(_pos) + player_offset


## Velocità globale del punto di aggancio: è lo slancio che si porta via.
func get_attach_velocity() -> Vector2:
	return (_sample(_pos) - _sample(_prev)) / _last_delta


func has_player() -> bool:
	return _attached_player != null


## Quanto è lontano dal soffitto il punto in cui il giocatore è appeso.
func get_grab_length() -> float:
	return _grab_length


## Apertura attuale dell'oscillazione, in gradi rispetto alla verticale.
func get_swing_angle_degrees() -> float:
	var arm := _sample(_pos) - _pos[0]
	if arm.length() < 0.001:
		return 0.0
	return rad_to_deg(atan2(arm.x, arm.y))


## Stacca il giocatore e restituisce la velocità con cui viene lanciato.
func release(with_jump: bool) -> Vector2:
	var player := _attached_player
	var swing := get_attach_velocity()
	var launch := Vector2(swing.x * release_horizontal_multiplier, swing.y * release_vertical_multiplier)
	if absf(swing.x) > 1.0:
		var strength: float = clampf(absf(swing.x) / maxf(release_boost_full_speed, 0.001), 0.0, 1.0)
		launch.x += signf(swing.x) * release_horizontal_boost * strength
	if with_jump:
		launch.y -= release_jump_boost
	launch.x = clampf(launch.x, -max_release_speed, max_release_speed)
	launch.y = clampf(launch.y, -max_release_speed, max_release_speed)
	_attached_player = null
	_cooldown = regrab_cooldown
	_update_masses()
	if player != null:
		released.emit(player)
	return launch


func get_total_length() -> float:
	return _step_length() * float(segment_count)


# --- Simulazione -------------------------------------------------------------

func _solve_constraints() -> void:
	var rest := _step_length()
	for i in range(_pos.size() - 1):
		var delta_pos: Vector2 = _pos[i + 1] - _pos[i]
		var dist := delta_pos.length()
		if dist < 0.0001:
			continue
		var inv_a := _inv_mass[i]
		var inv_b := _inv_mass[i + 1]
		var inv_total := inv_a + inv_b
		if inv_total <= 0.0:
			continue
		# Correzione ripartita in base alla massa: il giunto che porta il
		# giocatore si sposta meno di quello libero.
		var correction: Vector2 = delta_pos * ((dist - rest) / dist)
		_pos[i] += correction * (inv_a / inv_total)
		_pos[i + 1] -= correction * (inv_b / inv_total)


## Toglie la velocità che allargherebbe ancora l'oscillazione oltre il limite.
## Non tiene ferma la liana: la gravità continua a riportarla indietro.
func _limit_swing() -> void:
	var limit := deg_to_rad(max_angle_degrees)
	var arm: Vector2 = _pos[_pos.size() - 1] - _pos[0]
	if arm.length() < 0.001:
		return
	var angle := atan2(arm.x, arm.y)
	if absf(angle) <= limit:
		return
	var outward := signf(angle)
	for i in range(1, _pos.size()):
		var radius: Vector2 = _pos[i] - _pos[0]
		if radius.length() < 0.001:
			continue
		var tangent := radius.orthogonal().normalized()
		var vel: Vector2 = _pos[i] - _prev[i]
		var along := vel.dot(tangent)
		if along * outward > 0.0:
			_prev[i] = _pos[i] - (vel - tangent * along)


func _update_masses() -> void:
	if _inv_mass.size() != _pos.size():
		_inv_mass.resize(_pos.size())
	for i in _pos.size():
		if i == 0:
			_inv_mass[i] = 0.0
			continue
		_inv_mass[i] = 1.0 / maxf(segment_mass + player_mass * _player_weight(i), 0.001)


## Quanta parte del peso del giocatore grava sul giunto [param i]: il carico è
## ripartito fra i due giunti fra cui sta appeso.
func _player_weight(i: int) -> float:
	if _attached_player == null:
		return 0.0
	if i == _grab_index:
		return 1.0 - _grab_frac
	if i == _grab_index + 1:
		return _grab_frac
	return 0.0


func _sample(points: PackedVector2Array) -> Vector2:
	if points.size() < 2:
		return global_position
	var i: int = clampi(_grab_index, 0, points.size() - 2)
	return points[i].lerp(points[i + 1], _grab_frac)


func _set_grab_length(value: float) -> void:
	var step := _step_length()
	var total := get_total_length()
	# Non ci si arrampica fin sopra all'ancoraggio: serve almeno un segmento
	# intero sotto al soffitto perché la spinta abbia presa.
	var lowest: float = minf(maxf(total * min_grab_ratio, step * 1.05), total)
	_grab_length = clampf(value, lowest, total)
	var t: float = _grab_length / maxf(step, 0.001)
	_grab_index = clampi(int(floor(t)), 1, maxi(segment_count - 1, 1))
	_grab_frac = clampf(t - float(_grab_index), 0.0, 1.0)


func _reset_points() -> void:
	var step := _step_length()
	var direction := Vector2(sin(deg_to_rad(rest_angle_degrees)), cos(deg_to_rad(rest_angle_degrees)))
	_pos.resize(segment_count + 1)
	_prev.resize(segment_count + 1)
	_inv_mass.resize(segment_count + 1)
	var origin := global_position
	for i in _pos.size():
		_pos[i] = origin + direction * step * float(i)
		_prev[i] = _pos[i]
	_update_masses()
	_set_grab_length(_grab_length if _grab_length > 0.0 else get_total_length())


# --- Aggancio ----------------------------------------------------------------

func _try_auto_grab() -> void:
	if _cooldown > 0.0 or _grab_area == null:
		return
	for body in _grab_area.get_overlapping_bodies():
		if body.has_method("grab_liana") and _grab(body):
			return


func _grab(player: Node2D) -> bool:
	if grab_only_in_air and player.has_method("is_on_floor") and player.is_on_floor():
		return false
	var along := _closest_length_to(player.global_position)
	if not player.grab_liana(self):
		return false
	_attached_player = player
	_set_grab_length(along)
	_update_masses()
	# La velocità con cui arrivi entra nella catena: saltarci addosso in corsa fa
	# già partire l'oscillazione.
	var incoming: Vector2 = player.velocity if player.get("velocity") != null else Vector2.ZERO
	for i in [_grab_index, _grab_index + 1]:
		var weight := _player_weight(i)
		if weight > 0.0:
			_prev[i] = _pos[i] - incoming * _last_delta * weight
	_update_visual()
	grabbed.emit(player)
	return true


## Distanza dal soffitto del punto della liana più vicino a [param point].
func _closest_length_to(point: Vector2) -> float:
	var step := _step_length()
	var best_length := get_total_length()
	var best_distance := INF
	for i in range(_pos.size() - 1):
		var a: Vector2 = _pos[i]
		var b: Vector2 = _pos[i + 1]
		var segment: Vector2 = b - a
		var len_sq := segment.length_squared()
		var t: float = 0.0 if len_sq < 0.0001 else clampf((point - a).dot(segment) / len_sq, 0.0, 1.0)
		var distance := point.distance_squared_to(a + segment * t)
		if distance < best_distance:
			best_distance = distance
			best_length = (float(i) + t) * step
	return best_length


# --- Geometria e disegno -----------------------------------------------------

func _step_length() -> float:
	if segment_length > 0.0:
		return segment_length
	if segment_texture != null:
		var height := segment_texture_height if segment_texture_height > 0.0 else float(segment_texture.get_height()) * segment_texture_scale
		return height
	if tip_texture != null:
		var height := tip_texture_height if tip_texture_height > 0.0 else float(tip_texture.get_height()) * tip_texture_scale
		return height
	return 16.0


## Rotazione da dare a un nodo perché il suo asse verso il basso segua [param dir].
func _rotation_for(dir: Vector2) -> float:
	return -atan2(dir.x, dir.y)


func _ensure_nodes() -> void:
	_segments_root = get_node_or_null("Segments") as Node2D
	if _segments_root == null:
		_segments_root = Node2D.new()
		_segments_root.name = "Segments"
		add_child(_segments_root)
	_grab_area = get_node_or_null("GrabArea") as Area2D
	if _grab_area == null:
		_grab_area = Area2D.new()
		_grab_area.name = "GrabArea"
		# Nessun layer proprio: la liana non deve essere rilevata da nulla, si
		# limita a guardare chi le passa dentro.
		_grab_area.collision_layer = 0
		_grab_area.collision_mask = 1
		add_child(_grab_area)


func _refresh() -> void:
	if not is_node_ready():
		return
	_ensure_nodes()
	_rebuild_segments()
	_reset_points()
	_update_visual()


func _rebuild_segments() -> void:
	for child in _segments_root.get_children():
		child.queue_free()
	_segment_sprites.clear()
	_anchor_sprite = null
	for shape in _grab_shapes:
		if is_instance_valid(shape):
			shape.queue_free()
	_grab_shapes.clear()

	if anchor_texture != null:
		_anchor_sprite = Sprite2D.new()
		_anchor_sprite.texture = anchor_texture
		var anchor_scale := anchor_texture_scale
		if anchor_texture_height > 0.0:
			var original_height := float(anchor_texture.get_height())
			if original_height > 0.0:
				anchor_scale = anchor_texture_height / original_height
		_anchor_sprite.scale = Vector2.ONE * anchor_scale
		_segments_root.add_child(_anchor_sprite)

	var step := _step_length()
	for i in segment_count:
		var sprite := Sprite2D.new()
		var texture: Texture2D = segment_texture
		var is_tip := i == segment_count - 1 and tip_texture != null
		if is_tip:
			texture = tip_texture
		sprite.texture = texture
		sprite.visible = texture != null
		if texture != null:
			# Origine sul giunto alto del segmento, texture centrata in
			# orizzontale e stesa verso il basso.
			sprite.centered = false
			var texture_width := float(texture.get_width())
			var texture_height := float(texture.get_height())
			sprite.offset = Vector2(-texture_width * 0.5, 0.0)
			if alternate_flip and i % 2 == 1:
				sprite.flip_h = true
			# Imposta la scala in base alle proprietà di ridimensionamento
			var scale_value: float = segment_texture_scale
			var height_override := segment_texture_height
			if is_tip:
				scale_value = tip_texture_scale
				height_override = tip_texture_height
			if height_override > 0.0 and texture_height > 0.0:
				# Scala per raggiungere l'altezza desiderata
				sprite.scale = Vector2(scale_value, height_override / texture_height)
			else:
				sprite.scale = Vector2.ONE * scale_value
		_segments_root.add_child(sprite)
		_segment_sprites.append(sprite)

		# Un'area di aggancio per segmento: così segue la liana anche quando si
		# incurva, invece di approssimarla a un bastone dritto.
		var shape_node := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = grab_radius
		capsule.height = step + grab_radius * 2.0
		shape_node.shape = capsule
		_grab_area.add_child(shape_node)
		_grab_shapes.append(shape_node)


func _update_visual() -> void:
	if _segments_root == null or _pos.size() < 2:
		return
	for i in _segment_sprites.size():
		if i + 1 >= _pos.size():
			break
		var a := to_local(_pos[i])
		var b := to_local(_pos[i + 1])
		var dir := b - a
		var length := maxf(dir.length(), 0.001)
		var sprite := _segment_sprites[i]
		if sprite.texture != null:
			sprite.position = a
			sprite.rotation = _rotation_for(dir)
			# Mantieni la scala orizzontale ma adatta quella verticale alla lunghezza
			var current_scale := sprite.scale
			var texture_height := float(sprite.texture.get_height())
			if texture_height > 0.0:
				sprite.scale = Vector2(current_scale.x, length / texture_height)
			else:
				sprite.scale = Vector2(current_scale.x, length / 16.0)
		if i < _grab_shapes.size():
			var shape_node := _grab_shapes[i]
			shape_node.position = (a + b) * 0.5
			shape_node.rotation = _rotation_for(dir)
			var capsule := shape_node.shape as CapsuleShape2D
			if capsule != null:
				capsule.radius = grab_radius
				capsule.height = length + grab_radius * 2.0
	queue_redraw()


func _draw() -> void:
	# Senza texture la liana si disegna comunque, così è visibile e piazzabile in
	# editor prima ancora di avere l'immagine giusta.
	if segment_texture != null or _pos.size() < 2:
		return
	var points := PackedVector2Array()
	for p in _pos:
		points.append(to_local(p))
	draw_polyline(points, line_color, line_width, true)
	draw_circle(points[points.size() - 1], line_width * 0.9, line_color)
	if anchor_texture == null:
		draw_circle(Vector2.ZERO, line_width * 1.2, line_color.darkened(0.25))
