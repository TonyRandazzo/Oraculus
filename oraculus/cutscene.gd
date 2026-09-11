extends Node2D

@onready var cutscene_sprite = $cutscene
@onready var text = $Label

const MAX_AI_WAIT := 20.0

var timer_1: Timer
var timer_2: Timer
var _entered: bool = false

func _ready():
	timer_1 = Timer.new()
	timer_1.wait_time = 5.0
	timer_1.one_shot = true
	timer_1.timeout.connect(_on_first_timer_timeout)
	add_child(timer_1)
	timer_1.start()

func _on_first_timer_timeout():
	if cutscene_sprite:
		var new_texture = load("res://cutscene2.jpg")
		if new_texture:
			cutscene_sprite.texture = new_texture
		else:
			print("Errore: Immagine non trovata in res://cutscene2.jpg")
	
	text.text = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?"
	
	timer_2 = Timer.new()
	timer_2.wait_time = 5.0
	timer_2.one_shot = true
	timer_2.timeout.connect(_on_second_timer_timeout)
	add_child(timer_2)
	timer_2.start()

func _on_second_timer_timeout():
	_wait_for_ai()

func _wait_for_ai() -> void:
	# Prima qui si interrogava http://localhost:5000 ritentando all'infinito:
	# la cutscene non finiva finche' il server Python non rispondeva. Ora il
	# motore e' in-process, quindi basta aspettare che l'autoload sia pronto.
	var server := get_node_or_null("/root/AIServerManager")
	if server == null or server.is_server_ready():
		_enter_game()
		return

	server.server_started.connect(_enter_game, CONNECT_ONE_SHOT)

	# Rete di sicurezza: senza modello e senza rete si entra comunque, le
	# risposte arrivano dai fallback invece di bloccare il giocatore qui.
	await get_tree().create_timer(MAX_AI_WAIT).timeout
	if not _entered:
		print("[Cutscene] AI non pronta entro ", MAX_AI_WAIT, "s: entro comunque.")
		_enter_game()

func _enter_game() -> void:
	if _entered:
		return
	_entered = true
	get_tree().change_scene_to_file("res://oraculus/main.tscn")
