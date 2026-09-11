# ============================================================================
# Smoke test del cablaggio: AIServerManager -> OraculusEngine -> backend.
#
# La verifica di parita' copre le funzioni pure; questa copre il resto:
# che make_request risponda con la forma attesa, che la memoria per NPC si
# accumuli e si resetti, che gli indovinelli tornino sempre completi anche
# quando il backend non risponde.
#
#   godot --headless --path . res://ai/tests/smoke_check.tscn
# ============================================================================
extends Node

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	var server := get_node_or_null("/root/AIServerManager")
	if server == null:
		push_error("[Smoke] autoload AIServerManager assente")
		if not Engine.is_editor_hint():
			get_tree().quit(1)
		return

	if not server.is_server_ready():
		await server.server_started

	print("=".repeat(70))
	print("  SMOKE TEST — remoto: %s" % str(server.is_using_remote()))
	print("=".repeat(70))

	await _test_chat(server)
	await _test_memoria(server)
	await _test_riddle(server)
	_test_endpoint_inesistente(server)

	print("")
	if _ko.is_empty():
		print("  %d controlli superati." % _ok)
	else:
		print("  %d controlli falliti:" % _ko.size())
		for k in _ko:
			print("    - ", k)
	print("=".repeat(70))

	if not Engine.is_editor_hint():
		get_tree().quit(0 if _ko.is_empty() else 1)


func _test_chat(server: Node) -> void:
	for npc in ["Levias", "Malakai", "Larry"]:
		var res: Variant = await server.make_request("chat", {
			"npc_name": npc,
			"player_input": "Dove porta questa porta chiusa?",
			"hostility": 70,
			"friendship": 0,
		})
		_check("%s: risposta e' un Dictionary" % npc, typeof(res) == TYPE_DICTIONARY)
		if typeof(res) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = res
		_check("%s: nessun errore" % npc, not d.has("error"))
		_check("%s: response non vuota" % npc, not String(d.get("response", "")).is_empty())
		_check("%s: new_hostility in 0..100" % npc,
			int(d.get("new_hostility", -1)) >= 0 and int(d.get("new_hostility", 101)) <= 100)
		_check("%s: intent presente" % npc, not String(d.get("intent", "")).is_empty())
		_check("%s: lingua rilevata" % npc, not String(d.get("detected_language", "")).is_empty())
		print("  [%s] fonte=%s intent=%s ostilita'=%s  «%s»" % [npc,
			d.get("source", "?"), d.get("intent", "?"), d.get("new_hostility", "?"),
			String(d.get("response", "")).substr(0, 60)])

	# player_input vuoto: lo stesso errore del vecchio POST /chat
	var vuoto: Variant = await server.make_request("chat", {"npc_name": "Levias", "player_input": "   "})
	_check("player_input vuoto viene rifiutato",
		typeof(vuoto) == TYPE_DICTIONARY and (vuoto as Dictionary).has("error"))

	# Malakai si sblocca con una parola chiave
	var unlock: Variant = await server.make_request("chat", {
		"npc_name": "Malakai", "player_input": "I deserted the army, I feel shame.",
		"hostility": 90, "friendship": 0,
	})
	_check("Malakai si sblocca con le parole trigger",
		typeof(unlock) == TYPE_DICTIONARY and bool((unlock as Dictionary).get("npc_unlocked", false)))


func _test_memoria(server: Node) -> void:
	await server.make_request("reset", {})
	await server.make_request("chat", {"npc_name": "Rigon", "player_input": "ciao", "hostility": 40})
	var due: Variant = await server.make_request("chat", {"npc_name": "Rigon", "player_input": "e poi?", "hostility": 40})
	var storia: Array = (due as Dictionary).get("history", [])
	_check("la memoria accumula due scambi", storia.size() == 2)

	# Rigon: violenza porta l'ostilita' a 100
	var minaccia: Variant = await server.make_request("chat", {
		"npc_name": "Rigon", "player_input": "ti uccido", "hostility": 40})
	_check("Rigon va a 100 con la violenza", int((minaccia as Dictionary).get("new_hostility", -1)) == 100)

	var reset: Variant = await server.make_request("reset", {"npc_name": "Rigon"})
	_check("reset risponde ok", String((reset as Dictionary).get("status", "")) == "ok")
	var dopo: Variant = await server.make_request("chat", {"npc_name": "Rigon", "player_input": "ancora qui", "hostility": 40})
	_check("dopo il reset la memoria riparte da uno",
		(dopo as Dictionary).get("history", []).size() == 1)


func _test_riddle(server: Node) -> void:
	for door in ["door_entrance", "door_papyrus"]:
		var res: Variant = await server.make_request("riddle", {
			"door_id": door, "language": "inglese", "theme": "", "session_id": "smoke-1",
		})
		_check("%s: indovinello e' un Dictionary" % door, typeof(res) == TYPE_DICTIONARY)
		if typeof(res) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = res
		_check("%s: testo non vuoto" % door, not String(d.get("riddle", "")).is_empty())
		_check("%s: risposta non vuota" % door, not String(d.get("answer", "")).is_empty())
		print("  [%s] risposta=%s  «%s»" % [door, d.get("answer", "?"),
			String(d.get("riddle", "")).replace("\n", " ").substr(0, 60)])

	# Stesso door_id e stessa sessione: l'indovinello di riserva deve essere
	# sempre lo stesso. Lo chiediamo a un motore senza setup(), che quindi non
	# ha backend e risponde sempre dai fallback: cosi' il controllo vale anche
	# quando il modello locale e' installato e risponde davvero.
	var muto := OraculusEngine.new()
	muto.name = "MotoreMuto"
	add_child(muto)
	await get_tree().process_frame
	var params := {"door_id": "d", "language": "italiano", "session_id": "s"}
	var a: Dictionary = await muto.generate_door_riddle(params)
	var b: Dictionary = await muto.generate_door_riddle(params)
	var risposte_di_riserva := PackedStringArray()
	for r in OraculusData.RIDDLE_FALLBACKS["italiano"]:
		risposte_di_riserva.append(String(r["answer"]))
	_check("senza backend l'indovinello arriva dai fallback",
		risposte_di_riserva.has(String(a.get("answer", ""))))
	_check("indovinello di riserva riproducibile a sessione fissa",
		String(a.get("answer", "x")) == String(b.get("answer", "y")))
	muto.queue_free()


func _test_endpoint_inesistente(server: Node) -> void:
	var res: Variant = server.make_request("non_esiste", {})
	_check("endpoint sconosciuto restituisce un errore",
		typeof(res) == TYPE_DICTIONARY and (res as Dictionary).has("error"))


func _check(nome: String, esito: bool) -> void:
	if esito:
		_ok += 1
	else:
		_ko.append(nome)
