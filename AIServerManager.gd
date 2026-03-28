extends Node

const MAX_STARTUP_WAIT = 30.0
const CHECK_INTERVAL = 1.0
const REMOTE_API_URL = "https://oraculus-ai-api.onrender.com"

var _python_thread: Thread = null
var _server_ready: bool = false
var _server_process: int = 0
var _checking: bool = false
var _using_remote: bool = false

signal server_started
signal server_failed(error_message)

func _ready():
	_check_and_setup_python()

func _get_base_dir() -> String:
	return OS.get_executable_path().get_base_dir() + "/"

func _check_and_setup_python():
	if OS.get_name() == "Web":
		_switch_to_remote()
		return

	var base_dir = _get_base_dir()
	var script_path = base_dir + "ai/ai_server.py"

	if not FileAccess.file_exists(script_path):
		_switch_to_remote()
		return

	_python_thread = Thread.new()
	_python_thread.start(_setup_and_run_server.bind(script_path, base_dir))

func _switch_to_remote():
	print("[ServerManager] Fallback su server remoto: ", REMOTE_API_URL)
	_using_remote = true
	_server_ready = true
	emit_signal("server_started")

func _kill_existing_server():
	if OS.get_name() == "Windows":
		var output = []
		OS.execute("cmd", ["/c", "for /f \"tokens=5\" %a in ('netstat -aon ^| findstr :5000 ^| findstr LISTENING') do taskkill /F /PID %a"], output, true)
	else:
		var output = []
		OS.execute("bash", ["-c", "fuser -k 5000/tcp"], output, true)

func _setup_and_run_server(script_path: String, base_dir: String):
	var venv_dir = base_dir + "python_venv"

	_kill_existing_server()

	var dir = DirAccess.open(base_dir)
	if not dir.dir_exists("python_venv"):
		dir.make_dir("python_venv")

	var python_exe = ""
	if OS.get_name() == "Windows":
		python_exe = venv_dir + "/Scripts/python.exe"
	else:
		python_exe = venv_dir + "/bin/python3"

	if not FileAccess.file_exists(python_exe):
		var python_cmd = "python" if OS.get_name() == "Windows" else "python3"
		var output = []
		var exit_code = OS.execute(python_cmd, ["-m", "venv", venv_dir], output, true)
		if exit_code != 0:
			call_deferred("_switch_to_remote")
			return false

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
				call_deferred("_switch_to_remote")
				return false

		var file = FileAccess.open(marker_file, FileAccess.WRITE)
		file.store_string("installed")
		file.close()

	_server_process = OS.create_process(python_exe, [script_path])

	if _server_process < 0:
		call_deferred("_switch_to_remote")
		return false

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
			_using_remote = false
			emit_signal("server_started")
			return
		await get_tree().create_timer(CHECK_INTERVAL).timeout

	_checking = false
	_switch_to_remote()

func _check_server_ready_once() -> bool:
	if OS.get_name() == "Web":
		var result = await _make_request_web(REMOTE_API_URL + "/health", "{}")
		if result == null or result.has("error"):
			return false
		return result.get("status", "") == "ok"

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

func is_using_remote() -> bool:
	return _using_remote

func get_api_url() -> String:
	if _using_remote:
		return REMOTE_API_URL
	return "http://localhost:5000"

func make_request(endpoint: String, data: Dictionary = {}) -> Variant:
	var url = get_api_url() + "/" + endpoint
	var json_data = JSON.stringify(data)

	print("Richiesta a: ", url)
	print("Payload: ", json_data)

	if OS.get_name() == "Web":
		return await _make_request_web(url, json_data)

	var http = HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)

	var headers = ["Content-Type: application/json"]
	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_data)
	if error != OK:
		http.queue_free()
		return {"error": "Errore di connessione: " + str(error)}

	var result = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if response_code == 0:
		return {"error": "Timeout o connessione persa"}

	var response_text = body.get_string_from_utf8()
	print("Risposta - Codice: ", response_code, " Body: ", response_text)

	if response_code != 200:
		return {"error": "Errore server: " + str(response_code)}

	var json = JSON.new()
	if json.parse(response_text) != OK:
		return {"error": "Errore parsing: " + response_text}

	return json.get_data()

func _make_request_web(url: String, json_data: String) -> Variant:
	var safe_body = json_data \
		.replace("\\", "\\\\") \
		.replace("`", "\\`") \
		.replace("$", "\\$")

	JavaScriptBridge.eval("window._gd_done = false; window._gd_result = null;")

	JavaScriptBridge.eval("""
		(async () => {
			try {
				const r = await fetch('%s', {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: `%s`
				});
				const t = await r.text();
				window._gd_result = JSON.stringify({ok: r.ok, status: r.status, body: t});
			} catch(e) {
				window._gd_result = JSON.stringify({ok: false, status: 0, body: String(e)});
			}
			window._gd_done = true;
		})();
	""" % [url, safe_body])

	var elapsed = 0.0
	while elapsed < 90.0:
		await get_tree().process_frame
		var done = JavaScriptBridge.eval("window._gd_done ? 1 : 0")  # ritorna int, non bool
		if done == 1:
			break
		elapsed += get_process_delta_time()

	if elapsed >= 90.0:
		return {"error": "Timeout WebGL fetch (90s)"}

	var raw = str(JavaScriptBridge.eval("window._gd_result"))
	print("[WebGL] Raw response: ", raw)

	var outer = JSON.new()
	if outer.parse(raw) != OK:
		return {"error": "JSON esterno non valido: " + raw}
	var obj = outer.get_data()

	if not obj.get("ok", false):
		return {"error": "HTTP " + str(obj.get("status", 0)) + ": " + str(obj.get("body", ""))}

	var inner = JSON.new()
	if inner.parse(str(obj.get("body", ""))) != OK:
		return {"error": "JSON risposta AI non valido"}

	return inner.get_data()

func make_request_sync(endpoint: String, data: Dictionary = {}) -> Variant:
	var url = get_api_url() + "/" + endpoint
	var headers = ["Content-Type: application/json"]
	var json_data = JSON.stringify(data)

	print("[Sync] Richiesta a: ", url)
	print("[Sync] Payload: ", json_data)

	var client = HTTPClient.new()

	var use_https = url.begins_with("https://")
	var without_scheme = url.replace("https://", "").replace("http://", "")

	var slash_pos = without_scheme.find("/")
	var host_port: String
	var path: String
	if slash_pos == -1:
		host_port = without_scheme
		path = "/"
	else:
		host_port = without_scheme.substr(0, slash_pos)
		path = without_scheme.substr(slash_pos)

	var host: String
	var port: int
	var colon_pos = host_port.find(":")
	if colon_pos == -1:
		host = host_port
		port = 443 if use_https else 80
	else:
		host = host_port.substr(0, colon_pos)
		port = int(host_port.substr(colon_pos + 1))

	print("[Sync] Host: ", host, " Porta: ", port, " Path: ", path)

	var err = client.connect_to_host(host, port)
	if err != OK:
		return {"error": "Connessione fallita: " + str(err)}

	var waited = 0.0
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		OS.delay_msec(50)
		client.poll()
		waited += 0.05
		if waited > 10.0:
			return {"error": "Timeout connessione"}

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "Connessione fallita, status: " + str(client.get_status())}

	err = client.request(HTTPClient.METHOD_POST, path, headers, json_data)
	if err != OK:
		return {"error": "Errore richiesta: " + str(err)}

	waited = 0.0
	while waited < 60.0:
		OS.delay_msec(100)
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_CONNECTED:
			break
		elif status == HTTPClient.STATUS_DISCONNECTED:
			return {"error": "Disconnesso durante l'attesa"}
		waited += 0.1

	var response_body := PackedByteArray()
	waited = 0.0
	while waited < 20.0:
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				response_body.append_array(chunk)
				waited = 0.0
			else:
				OS.delay_msec(50)
				waited += 0.05
		else:
			break

	if response_body.size() > 0:
		var text = response_body.get_string_from_utf8()
		print("[Sync] Risposta ricevuta: ", text)
		var json = JSON.new()
		if json.parse(text) == OK:
			return json.get_data()
		else:
			return {"error": "Errore parsing JSON: " + text}
	else:
		return {"error": "Nessuna risposta ricevuta"}

func stop_server():
	_server_ready = false
	_checking = false
	_using_remote = false

	if _server_process > 0:
		OS.kill(_server_process)
		_server_process = 0

	if _python_thread and _python_thread.is_alive():
		_python_thread.wait_to_finish()
	_python_thread = null

func _exit_tree():
	stop_server()
