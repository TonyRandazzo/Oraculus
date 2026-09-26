extends Node
## Suoni dell'interfaccia (autoload "UiSounds").
##
## Un clic per ogni pulsante a schermo e un rintocco per ogni frase inviata
## (menu, dialogo con gli spiriti, risposta agli indovinelli delle porte). E
## tre suoni di gioco chiamati dagli script: un oggetto raccolto
## (play_pickup, dagli script degli oggetti), un oggetto usato (play_use, da
## hud.gd) e una porta che si apre (play_door, da door.gd).
##
## I pulsanti non vanno collegati a mano: ogni nodo che entra nell'albero
## viene guardato qui, quindi valgono anche quelli delle scene aggiunte in
## futuro. Suonano:
##  - tutti i BaseButton (Button, TextureButton, OptionButton, ...), e per
##    l'OptionButton anche la scelta di una voce;
##  - i TouchScreenButton che fanno qualcosa (hanno un "pressed" collegato
##    oltre al nostro) e non sono legati a un'azione di gioco: Interact,
##    Pausa, gli slot dell'inventario si', i tasti di movimento no, perche'
##    un clic a ogni passo sarebbe rumore.
##
## Il bus e' "SFX": il cursore degli effetti nelle Opzioni regola anche questi.
## Per lo stesso motivo ogni suono del gioco rimasto sul bus Master (i
## nemici, il trampolino, ...) viene spostato su "SFX" quando entra in scena:
## Master e' la somma di tutto, e il cursore della musica agisce sul bus
## "Music", dove le musiche si mettono da sole (music.gd, menu.gd).
##
## I suoni vengono dal pacchetto in oraculus/SFX (Atelier Magicae), la porta
## da Level/Sounds: per cambiarli basta cambiare questi percorsi. Se un file
## manca, il suono corrispondente tace con un avviso, senza errori.
const CLICK_PATH := "res://oraculus/SFX/Fantasy UI SFX/Fantasy/Fantasy_UI (20).wav"
const SEND_PATH := "res://oraculus/SFX/Fantasy UI SFX/Fantasy/Fantasy_UI (24).wav"
const PICKUP_PATH := "res://oraculus/SFX/Fantasy UI SFX/Fantasy/Fantasy_UI (19).wav"
const USE_PATH := "res://oraculus/SFX/Fantasy UI SFX/Fantasy/Fantasy_UI (17).wav"
const DOOR_PATH := "res://oraculus/Level/Sounds/Lock Unlock.wav"
const BUS := &"SFX"
const META := &"_ui_sound"

var _click: AudioStreamPlayer
var _send: AudioStreamPlayer
var _pickup: AudioStreamPlayer
var _use: AudioStreamPlayer
var _door: AudioStreamPlayer


func _ready() -> void:
	# Le Opzioni mettono in pausa l'albero: i loro pulsanti devono suonare lo
	# stesso.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click = _player(CLICK_PATH)
	_send = _player(SEND_PATH)
	_pickup = _player(PICKUP_PATH)
	_use = _player(USE_PATH)
	_door = _player(DOOR_PATH)
	get_tree().node_added.connect(_on_node_added)
	# La prima scena puo' essere gia' nell'albero quando l'autoload parte.
	for n in get_tree().root.find_children("*", "", true, false):
		_on_node_added(n)


func play_click() -> void:
	if _click.stream != null:
		_click.play()


func play_send() -> void:
	if _send.stream != null:
		_send.play()


func play_pickup() -> void:
	if _pickup.stream != null:
		_pickup.play()


func play_use() -> void:
	if _use.stream != null:
		_use.play()


func play_door() -> void:
	if _door.stream != null:
		_door.play()


func _player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path) if ResourceLoader.exists(path) else null
	if p.stream == null:
		push_warning("[UiSounds] suono mancante: " + path)
	p.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	# Clic ravvicinati si sovrappongono invece di troncarsi a vicenda.
	p.max_polyphony = 4
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if (n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D) \
			and n.bus == &"Master" and AudioServer.get_bus_index(BUS) >= 0:
		n.bus = BUS
		return
	if n.has_meta(META):
		return
	if n is BaseButton:
		n.set_meta(META, true)
		n.pressed.connect(play_click)
		if n is OptionButton:
			n.item_selected.connect(func(_i: int) -> void: play_click())
	elif n is TouchScreenButton:
		n.set_meta(META, true)
		n.pressed.connect(_on_touch_pressed.bind(n))


func _on_touch_pressed(b: TouchScreenButton) -> void:
	if not String(b.action).is_empty():
		return
	if b.get_signal_connection_list("pressed").size() > 1:
		play_click()
