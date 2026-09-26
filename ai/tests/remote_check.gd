# ============================================================================
# Collaudo del ramo remoto: il proxy su Render, visto da GDScript.
#
# Gli altri test non lo toccano mai: parity_check confronta funzioni pure,
# smoke_check gira col backend muto, local_check carica il .gguf. Questo e'
# l'unico che dimostra che il percorso remoto funziona davvero — probe(),
# chat_completion(), e la catena completa build_system_msg -> HTTP ->
# pulisci() / parse_riddle_response().
#
#   godot --headless --path . res://ai/tests/remote_check.tscn
#
# Serve la rete e il proxy in piedi: senza, si dichiara saltato invece di
# fallire. L'URL si sovrascrive con ORACULUS_API_URL.
# ============================================================================
extends Node

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DEL RAMO REMOTO (proxy su Render)")
	print("=".repeat(70))

	# Un motore nostro, non l'autoload: l'autoload sceglie il ramo locale se il
	# .gguf c'e', e qui vogliamo esercitare proprio quello remoto.
	var engine := OraculusEngine.new()
	engine.name = "OraculusEngineRemoto"
	add_child(engine)
	await get_tree().process_frame

	print("  url: ", engine.remote.base_url)

	if not await engine.remote.probe():
		print("")
		print("  SALTATO: il proxy non ha inferenza.")
		print("  Motivo: ", engine.remote.last_error)
		print("=".repeat(70))
		get_tree().quit(0)
		return

	_check("il proxy dichiara inferenza disponibile", engine.remote.is_available())

	# Forziamo il ramo remoto, senza la gara di setup().
	engine._using_remote = true
	engine._available = true

	await _test_chat(engine)
	await _test_memoria(engine)
	await _test_riddle(engine)

	print("")
	if _ko.is_empty():
		print("  %d controlli superati." % _ok)
	else:
		print("  %d superati, %d FALLITI:" % [_ok, _ko.size()])
		for k in _ko:
			print("    - ", k)
	print("=".repeat(70))
	get_tree().quit(0 if _ko.is_empty() else 1)


func _check(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		_ok += 1
	else:
		_ko.append(nome + ("  (" + extra + ")" if not extra.is_empty() else ""))


func _test_chat(engine: OraculusEngine) -> void:
	print("  [1] dialogo con un NPC")
	var res: Dictionary = await engine.generate_response({
		"player_input": "Who guards this place?",
		"npc_name": "Levias",
		"hostility": 70,
		"friendship": 0,
	})
	var testo := String(res.get("response", ""))
	print("      Levias: «%s»" % testo)
	print("      source=%s lingua=%s ostilita'=%s" % [
		res.get("source"), res.get("detected_language"), res.get("new_hostility")])
	_check("la risposta arriva dal modello, non dal fallback",
		res.get("source") == "llama", String(res.get("source", "?")))
	_check("la risposta non e' vuota", not testo.is_empty())
	_check("la risposta sta nei 240 caratteri di pulisci()", testo.length() <= 240,
		str(testo.length()))
	_check("la lingua rilevata e' l'inglese", res.get("detected_language") == "inglese",
		String(res.get("detected_language", "?")))


## L'italiano e' il caso che conta: detect_language sceglie la lingua e
## build_system_msg la impone al modello. Se il proxy rispondesse in inglese a
## una domanda italiana, il giocatore lo vedrebbe subito.
func _test_memoria(engine: OraculusEngine) -> void:
	print("  [2] lingua e memoria")
	var uno: Dictionary = await engine.generate_response({
		"player_input": "Chi sei? Come ti chiami?",
		"npc_name": "Malakai",
		"hostility": 30,
	})
	print("      Malakai: «%s»" % String(uno.get("response", "")))
	_check("la lingua rilevata e' l'italiano", uno.get("detected_language") == "italiano",
		String(uno.get("detected_language", "?")))
	_check("anche in italiano risponde il modello", uno.get("source") == "llama",
		String(uno.get("source", "?")))

	var due: Dictionary = await engine.generate_response({
		"player_input": "E cosa custodisci?",
		"npc_name": "Malakai",
		"hostility": 30,
	})
	print("      Malakai: «%s»" % String(due.get("response", "")))
	_check("la memoria dell'NPC si e' accumulata",
		engine.get_memory("Malakai").size() == 2,
		str(engine.get_memory("Malakai").size()))
	_check("la memoria resta separata per NPC", engine.get_memory("Levias").size() == 1)


func _test_riddle(engine: OraculusEngine) -> void:
	print("  [3] indovinello di una porta")
	var res: Dictionary = await engine.generate_door_riddle({
		"door_id": "door_entrance",
		"language": "inglese",
		"session_id": "remote-check",
	})
	var testo := String(res.get("riddle", ""))
	var risposta := String(res.get("answer", ""))
	print("      «%s»" % testo)
	print("      risposta attesa: %s" % risposta)
	_check("l'indovinello ha un testo", not testo.is_empty())
	_check("l'indovinello ha una risposta", not risposta.is_empty())
	_check("la risposta e' una parola sola", not risposta.strip_edges().contains(" "),
		risposta)
