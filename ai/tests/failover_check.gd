# ============================================================================
# Collaudo della gara e del passaggio automatico di ramo.
#
# Un proxy finto (fake_proxy.py) risponde in pochi ms, quindi vince la gara
# di setup(); poi lo si ammutolisce e le richieste devono arrivare comunque,
# dal locale, senza fallback. Poi il contrario: il locale tace e si torna al
# remoto. Infine di nuovo al locale, che stavolta va ricaricato da capo.
#
#   godot --headless --path . res://ai/tests/failover_check.tscn
#
# Servono python3, l'addon NobodyWho e il .gguf: senza il locale il test si
# dichiara saltato.
# ============================================================================
extends Node

const PORTA := 8765

var _ko: Array[String] = []
var _ok := 0
var _pid := -1


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DELLA GARA E DEL FAILOVER")
	print("=".repeat(70))

	# L'autoload fa la sua gara all'avvio e puo' tenere il locale: due .gguf
	# caricati insieme nello stesso processo mandano in crash l'addon, quindi
	# si aspetta che finisca e si libera il suo modello.
	var server := get_node_or_null("/root/AIServerManager")
	if server != null:
		while not server.is_server_ready():
			await get_tree().process_frame
		var suo: OraculusEngine = server._engine
		suo.local.chiudi()
		while suo.local.is_loading() or suo.local.is_busy():
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout

	var url := "http://127.0.0.1:%d" % PORTA
	_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://ai/tests/fake_proxy.py"), str(PORTA)])
	var su := false
	for i in 50:
		if await _post(url + "/vivo"):
			su = true
			break
		await get_tree().create_timer(0.1).timeout
	if not su:
		_fine("SALTATO: il proxy finto non parte (python3?)")
		return

	OS.set_environment("ORACULUS_API_URL", url)
	OS.set_environment("ORACULUS_BACKEND", "")
	var engine := OraculusEngine.new()
	add_child(engine)
	var t0 := Time.get_ticks_msec()
	await engine.setup()
	var ms := Time.get_ticks_msec() - t0
	_check("la gara si chiude entro 3 s", ms <= 3500, "%d ms" % ms)
	_check("il proxy finto, istantaneo, vince la gara", engine.is_using_remote())

	# 1. il remoto tace: la battuta arriva dal locale
	await _post(url + "/muto")
	var r: Dictionary = await engine.generate_response({"npc_name": "Levias", "player_input": "Who are you?", "language": "inglese"})
	if not engine.local.is_available() and engine.is_using_remote():
		_fine("SALTATO: locale non disponibile (%s)" % engine.local.last_error)
		return
	_check("remoto muto: passato al locale", not engine.is_using_remote())
	_check("remoto muto: la battuta non e' un fallback", r["source"] == "llama", str(r))

	# 2. il locale tace: si torna al remoto
	await _post(url + "/vivo")
	engine.local.chiudi()
	r = await engine.generate_response({"npc_name": "Levias", "player_input": "Where am I?", "language": "inglese"})
	_check("locale muto: tornato al remoto", engine.is_using_remote())
	_check("locale muto: la battuta non e' un fallback", r["source"] == "llama", str(r))

	# 3. di nuovo il remoto tace: il locale, liberato, va ricaricato
	await _post(url + "/muto")
	var indovinello: Dictionary = await engine.generate_door_riddle({"door_id": "porta_test", "language": "inglese", "session_id": "x"})
	_check("indovinello col remoto muto: di nuovo sul locale", not engine.is_using_remote())
	_check("indovinello valido", not String(indovinello.get("answer", "")).is_empty(), str(indovinello))

	_fine("")


func _post(url: String) -> bool:
	var req := HTTPRequest.new()
	req.timeout = 2.0
	add_child(req)
	if req.request(url, [], HTTPClient.METHOD_POST, "{}") != OK:
		req.queue_free()
		return false
	var res: Array = await req.request_completed
	req.queue_free()
	return res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200


func _check(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		_ok += 1
		print("  ok    ", nome)
	else:
		_ko.append(nome + ("  (" + extra + ")" if not extra.is_empty() else ""))
		print("  FAIL  ", nome, "  ", extra)


func _fine(saltato: String) -> void:
	if _pid > 0:
		OS.kill(_pid)
	print("")
	if not saltato.is_empty():
		print("  ", saltato)
	elif _ko.is_empty():
		print("  %d controlli superati." % _ok)
	else:
		print("  %d superati, %d FALLITI:" % [_ok, _ko.size()])
		for k in _ko:
			print("    - ", k)
	print("=".repeat(70))
	get_tree().quit(0 if _ko.is_empty() else 1)
