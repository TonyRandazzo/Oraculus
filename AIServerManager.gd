# AIServerManager.gd
extends Node

const PYTHON_VENV_DIR = "user://python_venv"
const AI_SERVER_SCRIPT = "res://ai/ai_server.py"
const MAX_STARTUP_WAIT = 30.0
const CHECK_INTERVAL = 1.0

var _python_thread: Thread = null
var _server_ready: bool = false
var _server_process: int = 0
var _checking: bool = false
var _installation_complete: bool = false

signal server_started
signal server_failed(error_message)

func _ready():
	print("[AIServerManager] Inizializzazione...")
	_check_and_setup_python()

func _check_and_setup_python():
	var script_path = ProjectSettings.globalize_path(AI_SERVER_SCRIPT)
	print("[AIServerManager] Script path: ", script_path)

	if not FileAccess.file_exists(script_path):
		print("[AIServerManager] ERRORE: Script non trovato!")
		emit_signal("server_failed", "Script AI server non trovato")
		return

	print("[AIServerManager] Avvio thread di installazione...")
	_python_thread = Thread.new()
	_python_thread.start(_setup_and_run_server.bind(script_path))

func _setup_and_run_server(script_path: String):
	print("[AIServerManager] Thread avviato")

	var venv_dir = ProjectSettings.globalize_path(PYTHON_VENV_DIR)
	print("[AIServerManager] Directory venv: ", venv_dir)

	# Crea directory
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("python_venv"):
		print("[AIServerManager] Creazione directory python_venv...")
		dir.make_dir("python_venv")

	# Percorsi Python
	var python_exe = ""
	if OS.get_name() == "Windows":
		python_exe = venv_dir + "/Scripts/python.exe"
	else:
		python_exe = venv_dir + "/bin/python3"

	# Verifica se il venv esiste, altrimenti crealo
	if not FileAccess.file_exists(python_exe):
		print("[AIServerManager] Python non trovato in: ", python_exe)
		print("[AIServerManager] Creazione nuovo ambiente virtuale...")

		var create_venv_args = []
		var python_cmd = ""
		if OS.get_name() == "Windows":
			python_cmd = "python"
		else:
			python_cmd = "python3"
		create_venv_args = ["-m", "venv", venv_dir]

		var output = []
		var exit_code = OS.execute(python_cmd, create_venv_args, output, true)

		if exit_code != 0:
			print("[AIServerManager] ERRORE creazione venv! Output: ", output)
			call_deferred("emit_signal", "server_failed", "Creazione ambiente virtuale fallita")
			return false

	# Installa dipendenze se non già fatto
	var marker_file = venv_dir + "/.installed"
	if not FileAccess.file_exists(marker_file):
		print("[AIServerManager] Installazione dipendenze...")

		var pip_exe = ""
		if OS.get_name() == "Windows":
			pip_exe = venv_dir + "/Scripts/pip.exe"
		else:
			pip_exe = venv_dir + "/bin/pip"

		var dependencies = ["llama-cpp-python", "requests"]

		for dep in dependencies:
			print("[AIServerManager] Installazione: ", dep)
			var output = []
			var exit_code = OS.execute(pip_exe, ["install", dep], output, true)

			if exit_code != 0:
				print("[AIServerManager] ERRORE installazione ", dep, " — Output: ", output)
				call_deferred("emit_signal", "server_failed", "Installazione " + dep + " fallita")
				return false

		# Crea file marcatore per evitare reinstallazioni
		var file = FileAccess.open(marker_file, FileAccess.WRITE)
		file.store_string("installed")
		file.close()
		print("[AIServerManager] Dipendenze installate con successo")
	else:
		print("[AIServerManager] Dipendenze già installate")

	# ─── AVVIO SERVER (FIX: usa create_process invece di execute con blocking=false) ───
	print("[AIServerManager] Avvio server AI...")

	_server_process = OS.create_process(python_exe, [script_path])

	if _server_process < 0:
		print("[AIServerManager] ERRORE: Impossibile avviare il processo Python")
		call_deferred("emit_signal", "server_failed", "Impossibile avviare il server AI")
		return false

	print("[AIServerManager] Server avviato con PID: ", _server_process)

	# Avvia il ciclo di controllo sulla main thread
	call_deferred("_start_server_ready_check")

	return true

func _start_server_ready_check():
	if _checking:
		return
	_checking = true
	print("[AIServerManager] Avvio controllo server...")
	_check_server_ready_async()

func _check_server_ready_async():
	var start_time = Time.get_ticks_msec() / 1000.0

	while Time.get_ticks_msec() / 1000.0 - start_time < MAX_STARTUP_WAIT:
		print("[AIServerManager] Controllo server...")
		if await _check_server_ready_once():
			print("[AIServerManager] ✅ Server AI pronto!")
			_server_ready = true
			_checking = false
			emit_signal("server_started")
			return
		await get_tree().create_timer(CHECK_INTERVAL).timeout

	print("[AIServerManager] ❌ Timeout avvio server")
	_checking = false
	emit_signal("server_failed", "Timeout avvio server")

# ─── FIX: usa await http.request_completed invece di polling manuale ───
func _check_server_ready_once() -> bool:
	var http = HTTPRequest.new()
	add_child(http)

	var error = http.request("http://localhost:5000/health")
	if error != OK:
		http.queue_free()
		return false

	# Attende il segnale reale di completamento della richiesta
	var result = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body: PackedByteArray]
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if response_code == 200:
		var json = JSON.new()
		var text = body.get_string_from_utf8()
		if json.parse(text) == OK:
			var data = json.get_data()
			return data.has("status") and data["status"] == "ok"

	return false

func is_server_ready() -> bool:
	return _server_ready

# ─── FIX: usa OS.kill() per terminare il processo figlio ───
func stop_server():
	print("[AIServerManager] Arresto server...")
	_server_ready = false
	_checking = false

	if _server_process > 0:
		OS.kill(_server_process)
		_server_process = 0
		print("[AIServerManager] Processo server terminato")

	if _python_thread and _python_thread.is_alive():
		_python_thread.wait_to_finish()
	_python_thread = null

func _exit_tree():
	stop_server()
