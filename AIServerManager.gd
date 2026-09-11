# ============================================================================
# Facciata sottile sopra OraculusEngine.
#
# Prima questo autoload creava un venv, installava llama-cpp-python con pip,
# lanciava ai/ai_server.py con OS.create_process, uccideva chi occupava la
# porta 5000 e aspettava fino a 90 secondi un healthcheck HTTP. Ora il motore
# di dialogo e' GDScript e gira nel processo del gioco: niente Python
# installato sulla macchina del giocatore, niente porte, niente attesa.
#
# La firma pubblica e' rimasta la stessa (make_request, is_server_ready,
# is_using_remote, server_started, server_failed) perche' il resto del gioco
# la usa: door.gd aspetta server_started, gli NPC chiamano make_request.
# ============================================================================
extends Node

signal server_started
signal server_failed(error_message)

var _engine: OraculusEngine = null
var _ready_flag := false


func _ready() -> void:
	_engine = OraculusEngine.new()
	_engine.name = "OraculusEngine"
	add_child(_engine)
	await _engine.setup()
	_ready_flag = true
	if _engine.is_available():
		server_started.emit()
	else:
		server_failed.emit("Nessun backend di inferenza disponibile.")
		# Anche senza modello il gioco resta giocabile: le risposte arrivano
		# da FALLBACK e gli indovinelli da RIDDLE_FALLBACKS.
		server_started.emit()


func is_server_ready() -> bool:
	return _ready_flag


func is_using_remote() -> bool:
	return _engine != null and _engine.is_using_remote()


## Conservata per compatibilita': un tempo era l'URL del server HTTP.
func get_api_url() -> String:
	if _engine != null and _engine.is_using_remote():
		return _engine.remote.base_url
	return "in-process"


## Stesso contratto del vecchio POST su ai_server.py: gli endpoint sono
## rimasti "chat", "riddle", "reset", "set_context", "health".
func make_request(endpoint: String, data: Dictionary = {}) -> Variant:
	if _engine == null:
		return {"error": "Motore non inizializzato"}

	match endpoint:
		"chat":
			return await _engine.generate_response(data)
		"riddle":
			return await _engine.generate_door_riddle(data)
		"reset":
			var npc: Variant = data.get("npc_name", null)
			_engine.reset_memory(npc)
			var msg := "Tutta la memoria resettata"
			if npc != null and not String(npc).is_empty():
				msg = "Memoria di '%s' resettata" % String(npc)
			return {"status": "ok", "message": msg}
		"set_context":
			# Il contesto viaggia dentro il payload di "chat" (context_vars),
			# quindi qui non c'e' piu' nulla da memorizzare lato server.
			var npc_name := String(data.get("npc_name", ""))
			if npc_name.is_empty():
				return {"error": "npc_name è obbligatorio"}
			return {
				"status": "ok",
				"npc_name": npc_name,
				"context_vars": data.get("context_vars", {}),
			}
		"health":
			return {
				"status": "ok",
				"engine": "gdscript+nobodywho" if not _engine.is_using_remote() else "gdscript+remote",
				"llama": _engine.is_available(),
			}
		"npcs":
			var nomi := PackedStringArray(OraculusData.NPC_DATA.keys())
			nomi.sort()
			return {"npcs": nomi}

	return {"error": "Endpoint non trovato: " + endpoint}


## Deprecata. Esisteva per chiamare il server HTTP da dentro un Thread; ora
## l'inferenza e' asincrona a segnali e i Thread sono stati rimossi dai
## chiamanti. Se qualcosa la invoca ancora, e' un residuo da convertire in
## `await make_request(...)`.
func make_request_sync(endpoint: String, _data: Dictionary = {}) -> Variant:
	push_warning("[ServerManager] make_request_sync è deprecata (endpoint '%s'): usa await make_request()." % endpoint)
	return {"error": "make_request_sync non è più supportata: usa await make_request()"}


func reset_memory(npc_name: Variant = null) -> void:
	if _engine != null:
		_engine.reset_memory(npc_name)


func stop_server() -> void:
	_ready_flag = false
