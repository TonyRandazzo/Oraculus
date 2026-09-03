@tool
extends Area2D
## Trampolino elastico: chi ci finisce sopra viene rilanciato in alto, e il balzo
## è tanto più alto quanto più lunga era la caduta che l'ha portato lì.
##
## L'altezza del rimbalzo non è fissa. Il trampolino misura da quanto in alto sta
## cadendo il corpo in due modi — il punto più alto da cui l'ha visto scendere
## dentro al suo sensore, e l'altezza ricavata dalla velocità con cui lo colpisce
## — e prende la stima maggiore. Quell'altezza viene poi moltiplicata per
## [member bounce_height_ratio], che di base è poco più di 1: si torna sempre un
## po' più su di dov'eri, quindi rimbalzando si sale di volta in volta.
##
## Il tappeto non è solido: non ci si può restare fermi sopra, chi lo tocca
## riparte. Chi ci arriva camminando, senza cadere da nessuna parte, prende
## comunque il balzo minimo di [member min_bounce_height].
##
## Funziona con il giocatore e con qualunque NPC: se il corpo ha un metodo
## bounce(speed) viene chiamato quello (il giocatore lo usa per annullare
## scivolate, salti rimasti e prese sulla liana), altrimenti gli viene impostata
## direttamente la velocità verticale.
##
## L'origine del nodo sta sul telo, cioè sul punto in cui si rimbalza: le gambe
## del telaio sono disegnate sotto, quindi va appoggiato con l'origine
## [member frame_height] pixel sopra il pavimento.

## Emesso quando qualcuno viene lanciato: [param height] è l'altezza in pixel che
## il balzo raggiungerà.
signal bounced(body: Node, height: float)

@export_group("Forma")
## Larghezza del telo, cioè quanto è largo il punto in cui si rimbalza.
@export_range(8.0, 512.0, 1.0, "or_greater") var pad_width: float = 64.0:
	set(value):
		pad_width = maxf(8.0, value)
		_refresh()
## Spessore della zona di rimbalzo: più è alta, meno rischia di essere
## attraversata in un solo frame da chi cade fortissimo.
@export_range(2.0, 64.0, 1.0, "or_greater") var pad_thickness: float = 16.0:
	set(value):
		pad_thickness = maxf(2.0, value)
		_refresh()
## Altezza delle gambe disegnate sotto al telo. Solo estetica.
@export_range(0.0, 128.0, 1.0, "or_greater") var frame_height: float = 14.0:
	set(value):
		frame_height = maxf(0.0, value)
		queue_redraw()
## Quanto in alto arriva il sensore che guarda chi sta scendendo: è la caduta più
## lunga che il trampolino riesce a misurare guardando, oltre quella la ricava
## comunque dalla velocità d'impatto.
@export_range(0.0, 2048.0, 8.0, "or_greater") var sensor_height: float = 480.0:
	set(value):
		sensor_height = maxf(0.0, value)
		_refresh()

@export_group("Rimbalzo")
## Quanto è alto il balzo rispetto alla caduta: 1.0 rimanda esattamente da dove
## si è partiti, sopra 1.0 un po' più in alto.
@export_range(0.1, 4.0, 0.05) var bounce_height_ratio: float = 1.25
## Pixel di altezza aggiunti a ogni balzo, indipendentemente dalla caduta.
@export_range(0.0, 512.0, 1.0, "or_greater") var bounce_height_bonus: float = 0.0
## Balzo di chi ci finisce sopra senza cadere da nessuna parte, in pixel.
@export_range(0.0, 1024.0, 4.0, "or_greater") var min_bounce_height: float = 200.0
## Tetto massimo del balzo: senza, una caduta lunghissima sparerebbe fuori mappa.
@export_range(16.0, 4096.0, 8.0, "or_greater") var max_bounce_height: float = 900.0
## Se vero, rimbalza solo chi ci arriva cadendo: chi ci cammina sopra passa e basta.
@export var only_when_falling: bool = false
## Sotto questa velocità in discesa si è "arrivati camminando", non cadendo.
@export_range(0.0, 400.0, 5.0) var min_fall_speed: float = 40.0
## Quanto aspetta prima di poter rilanciare lo stesso corpo: gli lascia il tempo
## di uscire dal telo senza essere rimbalzato due volte.
@export_range(0.0, 2.0, 0.05) var rebounce_cooldown: float = 0.25
## Gravità usata per i corpi che non espongono la propria: serve a tradurre la
## velocità in altezza e viceversa.
@export var default_gravity: float = 1000.0

@export_group("Effetto")
## Suono del rimbalzo.
@export var bounce_sound: AudioStream:
	set(value):
		bounce_sound = value
		if _sound != null:
			_sound.stream = value
## Di quanti pixel sprofonda il telo nel momento del balzo.
@export_range(0.0, 64.0, 0.5) var squash_depth: float = 12.0
## Quanto è nervosa la vibrata del telo, in oscillazioni al secondo.
@export_range(0.5, 20.0, 0.1) var squash_frequency: float = 5.0
## Quanto in fretta la vibrata si spegne.
@export_range(0.0, 40.0, 0.5) var squash_damping: float = 6.0

@export_group("Disegno")
## Texture del telo, stesa per tutta la larghezza (lasciala vuota per il disegno a linee).
@export var pad_texture: Texture2D:
	set(value):
		pad_texture = value
		queue_redraw()
## Scala della texture (1.0 = dimensione originale)
@export_range(0.1, 5.0, 0.05) var pad_texture_scale: float = 1.0:
	set(value):
		pad_texture_scale = maxf(0.1, value)
		queue_redraw()
## Altezza fissa della texture in pixel (0 = usa altezza originale * scala)
@export_range(0.0, 512.0, 1.0) var pad_texture_height: float = 0.0:
	set(value):
		pad_texture_height = maxf(0.0, value)
		queue_redraw()
## Se true, la texture si allarga per coprire tutta la larghezza del telo
@export var pad_texture_stretch_width: bool = true
## Modalità di allineamento: "center", "left", "right"
@export_enum("center", "left", "right") var pad_texture_align: String = "center"
## Texture opzionale del telaio, disegnata sotto al telo.
@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		queue_redraw()
@export var pad_color: Color = Color(0.85, 0.24, 0.29):
	set(value):
		pad_color = value
		queue_redraw()
@export var frame_color: Color = Color(0.36, 0.29, 0.22):
	set(value):
		frame_color = value
		queue_redraw()
@export_range(0.5, 16.0, 0.5) var line_width: float = 4.0:
	set(value):
		line_width = maxf(0.5, value)
		queue_redraw()

# Un corpo per volta: da dove l'abbiamo visto scendere e a che velocità.
# Chiave = instance id, valore = {"apex": float, "fall_speed": float}.
var _tracked: Dictionary = {}
# Chi è appena stato lanciato e per quanto ancora va ignorato.
var _cooldowns: Dictionary = {}

var _pad_shape: CollisionShape2D
var _sensor: Area2D
var _sensor_shape: CollisionShape2D
var _sound: AudioStreamPlayer2D
# Stato del telo che vibra: 1 = completamente sprofondato, 0 = a riposo.
var _squash: float = 0.0
var _squash_vel: float = 0.0


func _ready() -> void:
	_ensure_nodes()
	_refresh()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	else:
		add_to_group("trampoline")


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	# Prima si guarda chi sta scendendo verso il telo, così quando arriva
	# sappiamo già da che altezza è partito, anche se il pavimento sotto gli ha
	# azzerato la velocità nello stesso frame in cui ci tocca.
	var seen: Dictionary = {}
	if _sensor != null:
		for body in _sensor.get_overlapping_bodies():
			_track(body)
			seen[body.get_instance_id()] = true
	for body in get_overlapping_bodies():
		_track(body)
		seen[body.get_instance_id()] = true
		if _can_bounce(body):
			_bounce(body)
	# Chi è uscito da entrambe le aree riparte da zero la prossima volta.
	for id in _tracked.keys():
		if not seen.has(id):
			_tracked.erase(id)


func _process(delta: float) -> void:
	if _squash == 0.0 and _squash_vel == 0.0:
		return
	# Oscillatore armonico smorzato: il telo sprofonda e poi rimbalza da solo.
	var omega := TAU * squash_frequency
	_squash_vel += (-omega * omega * _squash - 2.0 * squash_damping * _squash_vel) * delta
	_squash += _squash_vel * delta
	if absf(_squash) < 0.001 and absf(_squash_vel) < 0.01:
		_squash = 0.0
		_squash_vel = 0.0
	queue_redraw()


# --- Rimbalzo ----------------------------------------------------------------

## Lancia [param body] come se ci fosse caduto sopra da [param fall_height] pixel.
## Utile per far partire il balzo da un trigger invece che dal contatto.
func bounce_body(body: Node, fall_height: float) -> void:
	var height := clampf(fall_height * bounce_height_ratio + bounce_height_bonus, min_bounce_height, max_bounce_height)
	var body_gravity := _gravity_of(body)
	var speed := sqrt(2.0 * body_gravity * height)
	if body.has_method("bounce"):
		body.call("bounce", speed)
	elif body is CharacterBody2D:
		var character := body as CharacterBody2D
		character.velocity.y = -speed
	elif body is RigidBody2D:
		var rigid := body as RigidBody2D
		rigid.linear_velocity.y = -speed
	else:
		return
	_cooldowns[body.get_instance_id()] = rebounce_cooldown
	_tracked.erase(body.get_instance_id())
	_squash = 1.0
	_squash_vel = 0.0
	if _sound != null and _sound.stream != null:
		_sound.play()
	bounced.emit(body, height)


func _bounce(body: Node) -> void:
	bounce_body(body, _fall_height_of(body))


func _can_bounce(body: Node) -> bool:
	if _cooldowns.has(body.get_instance_id()):
		return false
	if not (body is CharacterBody2D or body is RigidBody2D or body.has_method("bounce")):
		return false
	# Chi sta già salendo (per esempio ci passa dentro da sotto saltando) non
	# viene toccato: il trampolino spinge in su, non schiaccia in giù.
	if _velocity_of(body).y < -1.0:
		return false
	if only_when_falling and _fall_speed_of(body) < min_fall_speed:
		return false
	return true


## Da quanto in alto sta cadendo [param body], in pixel. Prende la stima più
## generosa fra quella vista dal sensore e quella ricavata dalla velocità.
func _fall_height_of(body: Node) -> float:
	var entry: Dictionary = _tracked.get(body.get_instance_id(), {})
	var by_sight: float = 0.0
	if entry.has("apex"):
		by_sight = maxf(_bounce_y(body) - float(entry["apex"]), 0.0)
	var speed := _fall_speed_of(body)
	var by_speed := speed * speed / (2.0 * _gravity_of(body))
	return maxf(by_sight, by_speed)


## Velocità di discesa più alta vista da quando il corpo è entrato nel sensore.
func _fall_speed_of(body: Node) -> float:
	var entry: Dictionary = _tracked.get(body.get_instance_id(), {})
	var tracked: float = float(entry.get("fall_speed", 0.0))
	return maxf(tracked, _velocity_of(body).y)


func _track(body: Node) -> void:
	if _cooldowns.has(body.get_instance_id()):
		return
	var id := body.get_instance_id()
	var entry: Dictionary = _tracked.get(id, {"apex": _bounce_y(body), "fall_speed": 0.0})
	entry["apex"] = minf(float(entry["apex"]), _bounce_y(body))
	entry["fall_speed"] = maxf(float(entry["fall_speed"]), _velocity_of(body).y)
	_tracked[id] = entry


func _tick_cooldowns(delta: float) -> void:
	for id in _cooldowns.keys():
		var left: float = float(_cooldowns[id]) - delta
		if left <= 0.0 or not is_instance_id_valid(id):
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left


## Altezza a cui si trova il corpo. Conta solo come differenza fra due istanti
## dello stesso corpo, quindi l'origine dove sta non cambia il conto della caduta.
func _bounce_y(body: Node) -> float:
	if body is Node2D:
		return (body as Node2D).global_position.y
	return global_position.y


func _velocity_of(body: Node) -> Vector2:
	if body is CharacterBody2D:
		return (body as CharacterBody2D).velocity
	if body is RigidBody2D:
		return (body as RigidBody2D).linear_velocity
	var value: Variant = body.get("velocity")
	if value is Vector2:
		return value
	return Vector2.ZERO


## Gravità del corpo, così l'altezza del balzo esce giusta anche per chi cade più
## piano del giocatore. Chi non ce l'ha (o ce l'ha a zero perché sta su una
## scala) usa quella di default.
func _gravity_of(body: Node) -> float:
	var value: Variant = body.get("gravity")
	if value is float or value is int:
		var body_gravity := float(value)
		if body_gravity > 1.0:
			return body_gravity
	return maxf(default_gravity, 1.0)


# --- Nodi e forma ------------------------------------------------------------

func _ensure_nodes() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_pad_shape = get_node_or_null("PadShape") as CollisionShape2D
	if _pad_shape == null:
		_pad_shape = CollisionShape2D.new()
		_pad_shape.name = "PadShape"
		add_child(_pad_shape)
	_sensor = get_node_or_null("FallSensor") as Area2D
	if _sensor == null:
		_sensor = Area2D.new()
		_sensor.name = "FallSensor"
		add_child(_sensor)
	# Il sensore non deve essere visto da nessuno: guarda e basta.
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	_sensor_shape = _sensor.get_node_or_null("SensorShape") as CollisionShape2D
	if _sensor_shape == null:
		_sensor_shape = CollisionShape2D.new()
		_sensor_shape.name = "SensorShape"
		_sensor.add_child(_sensor_shape)
	_sound = get_node_or_null("Sound") as AudioStreamPlayer2D
	if _sound == null:
		_sound = AudioStreamPlayer2D.new()
		_sound.name = "Sound"
		add_child(_sound)
	_sound.stream = bounce_sound


func _refresh() -> void:
	if not is_node_ready():
		return
	_ensure_nodes()
	var pad := _pad_shape.shape as RectangleShape2D
	if pad == null:
		pad = RectangleShape2D.new()
		_pad_shape.shape = pad
	pad.size = Vector2(pad_width, pad_thickness)
	# L'origine del nodo sta sulla superficie del telo: la zona di rimbalzo
	# scende da lì.
	_pad_shape.position = Vector2(0.0, pad_thickness * 0.5)

	var sensor := _sensor_shape.shape as RectangleShape2D
	if sensor == null:
		sensor = RectangleShape2D.new()
		_sensor_shape.shape = sensor
	sensor.size = Vector2(pad_width, maxf(sensor_height, 1.0))
	_sensor_shape.position = Vector2(0.0, -sensor_height * 0.5)
	_sensor.monitoring = sensor_height > 0.0
	queue_redraw()


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	var half := pad_width * 0.5
	var dip := _squash * squash_depth
	if frame_texture != null:
		var frame_size := frame_texture.get_size()
		draw_texture_rect(frame_texture, Rect2(-half, 0.0, pad_width, maxf(frame_height, frame_size.y)), false)
	elif frame_height > 0.0:
		# Due gambe divaricate e la traversa che le tiene.
		var splay := pad_width * 0.12
		draw_line(Vector2(-half, 0.0), Vector2(-half - splay, frame_height), frame_color, line_width, true)
		draw_line(Vector2(half, 0.0), Vector2(half + splay, frame_height), frame_color, line_width, true)
		draw_line(Vector2(-half - splay, frame_height), Vector2(half + splay, frame_height), frame_color, line_width * 0.75, true)

	if pad_texture != null:
		var texture_size := pad_texture.get_size()
		var target_height := pad_texture_height if pad_texture_height > 0.0 else texture_size.y * pad_texture_scale
		var target_width := texture_size.x * pad_texture_scale
		
		if pad_texture_stretch_width:
			target_width = pad_width
		
		var rect := Rect2(Vector2.ZERO, Vector2(target_width, target_height))
		
		# Allineamento orizzontale
		match pad_texture_align:
			"left":
				rect.position.x = -half
			"right":
				rect.position.x = half - target_width
			_: # center
				rect.position.x = -target_width / 2.0
		
		rect.position.y = dip
		
		# Usa region per disegnare con ridimensionamento
		var region := Rect2(Vector2.ZERO, texture_size)
		draw_texture_rect_region(pad_texture, rect, region)
		return

	# Telo disegnato come una curva che sprofonda al centro: senza texture il
	# trampolino si vede e si piazza lo stesso.
	var points := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		# Bezier quadratica: agli estremi resta agganciato al telaio, in mezzo
		# scende del doppio del controllo, cioè di dip.
		var a := Vector2(-half, 0.0).lerp(Vector2(0.0, dip * 2.0), t)
		var b := Vector2(0.0, dip * 2.0).lerp(Vector2(half, 0.0), t)
		points.append(a.lerp(b, t))
	draw_polyline(points, pad_color, line_width, true)
