# AIServerManager.gd
extends Node

const PYTHON_VENV_DIR = "res://python_venv"  # Cambiato da user:// a res://
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
	_check_and_setup_python()

func _check_and_setup_python():
	var script_path = ProjectSettings.globalize_path(AI_SERVER_SCRIPT)

	if not FileAccess.file_exists(script_path):
		emit_signal("server_failed", "Script AI server non trovato")
		return

	_python_thread = Thread.new()
	_python_thread.start(_setup_and_run_server.bind(script_path))

func _setup_and_run_server(script_path: String):

	# Ottieni il percorso assoluto della directory del progetto
	var project_dir = ProjectSettings.globalize_path("res://")
	var venv_dir = project_dir + "python_venv"

	# Crea directory nella cartella del progetto
	var dir = DirAccess.open(project_dir)
	if not dir.dir_exists("python_venv"):
		dir.make_dir("python_venv")

	# Percorsi Python
	var python_exe = ""
	if OS.get_name() == "Windows":
		python_exe = venv_dir + "/Scripts/python.exe"
	else:
		python_exe = venv_dir + "/bin/python3"

	# Verifica se il venv esiste, altrimenti crealo
	if not FileAccess.file_exists(python_exe):


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
			call_deferred("emit_signal", "server_failed", "Creazione ambiente virtuale fallita")
			return false

	# Installa dipendenze se non già fatto
	var marker_file = venv_dir + "/.installed"
	if not FileAccess.file_exists(marker_file):

		var pip_exe = ""
		if OS.get_name() == "Windows":
			pip_exe = venv_dir + "/Scripts/pip.exe"
		else:
			pip_exe = venv_dir + "/bin/pip"

		var dependencies = ["llama-cpp-python", "requests"]

		for dep in dependencies:
			var output = []
			var exit_code = OS.execute(pip_exe, ["install", dep], output, true)

			if exit_code != 0:
				call_deferred("emit_signal", "server_failed", "Installazione " + dep + " fallita")
				return false

		# Crea file marcatore per evitare reinstallazioni
		var file = FileAccess.open(marker_file, FileAccess.WRITE)
		file.store_string("installed")
		file.close()


	_server_process = OS.create_process(python_exe, [script_path])

	if _server_process < 0:
		call_deferred("emit_signal", "server_failed", "Impossibile avviare il server AI")
		return false


	# Avvia il ciclo di controllo sulla main thread
	call_deferred("_start_server_ready_check")

	return true

func _start_server_ready_check():
	if _checking:
		return
	_checking = true
	_check_server_ready_async()

func _check_server_ready_async():
	var start_time = Time.get_ticks_msec() / 1000.0

	while Time.get_ticks_msec() / 1000.0 - start_time < MAX_STARTUP_WAIT:
		if await _check_server_ready_once():
			_server_ready = true
			_checking = false
			emit_signal("server_started")
			return
		await get_tree().create_timer(CHECK_INTERVAL).timeout

	_checking = false
	emit_signal("server_failed", "Timeout avvio server")

func _check_server_ready_once() -> bool:
	var http = HTTPRequest.new()
	add_child(http)

	var error = http.request("http://localhost:5000/health")
	if error != OK:
		http.queue_free()
		return false

	var result = await http.request_completed
	http.queue_free()

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

func stop_server():
	_server_ready = false
	_checking = false

	if _server_process > 0:
		OS.kill(_server_process)
		_server_process = 0

	if _python_thread and _python_thread.is_alive():
		_python_thread.wait_to_finish()
	_python_thread = null

func _exit_tree():
	stop_server()
