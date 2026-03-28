extends Node2D

@onready var cutscene_sprite = $cutscene
@onready var text = $Label

var timer_1: Timer
var timer_2: Timer
var http_request: HTTPRequest
var is_server_responding: bool = false
var retry_count: int = 0
var max_retries: int = -1  # -1 significa ritenta all'infinito

func _ready():
	timer_1 = Timer.new()
	timer_1.wait_time = 5.0
	timer_1.one_shot = true
	timer_1.timeout.connect(_on_first_timer_timeout)
	add_child(timer_1)
	timer_1.start()
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

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
	# Inizia il tentativo di connessione al server
	_attempt_server_connection()

func _attempt_server_connection():
	if is_server_responding:
		return  # Se il server ha già risposto, non fare ulteriori tentativi
	
	retry_count += 1
	var url = "http://localhost:5000"
	var error = http_request.request(url)
	
	if error != OK:
		print("Errore nella richiesta HTTP (tentativo ", retry_count, "): ", error)
		# Se c'è errore nella richiesta, riprova dopo 2 secondi
		_retry_connection()

func _retry_connection():
	# Crea un timer per riprovare dopo 2 secondi
	var retry_timer = Timer.new()
	retry_timer.wait_time = 2.0
	retry_timer.one_shot = true
	retry_timer.timeout.connect(_attempt_server_connection)
	add_child(retry_timer)
	retry_timer.start()

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if is_server_responding:
		return  # Se abbiamo già ricevuto una risposta, ignora ulteriori callback
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("Server risponde correttamente dopo ", retry_count, " tentativi, cambio scena...")
		is_server_responding = true
		# Cambia scena a res://oraculus/main.tscn
		get_tree().change_scene_to_file("res://oraculus/main.tscn")
	else:
		print("Server non risponde (tentativo ", retry_count, "), riprovo tra 2 secondi...")
		_retry_connection()
