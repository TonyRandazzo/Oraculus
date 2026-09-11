# ============================================================================
# Collaudo del ramo locale: NobodyWho (llama.cpp) dentro il processo di Godot.
#
# Gli altri due test non toccano mai l'inferenza vera: parity_check confronta
# le funzioni pure con Python, smoke_check verifica il cablaggio con il
# backend muto. Questo invece carica il .gguf e genera davvero, quindi e'
# l'unico che dimostra che i nomi di proprieta', metodi e segnali
# dell'addon sono quelli che oraculus_backend_local.gd si aspetta.
#
#   godot --headless --path . res://ai/tests/local_check.tscn
#
# Serve l'addon in addons/nobodywho/ e il modello (vedi ai/README.md): senza,
# il test si dichiara saltato invece di fallire.
# ============================================================================
extends Node

const CHAT_TIMEOUT := 120.0

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	var server := get_node_or_null("/root/AIServerManager")
	if server == null:
		push_error("[Locale] autoload AIServerManager assente")
		get_tree().quit(1)
		return
	if not server.is_server_ready():
		await server.server_started

	print("=".repeat(70))
	print("  COLLAUDO DEL RAMO LOCALE (NobodyWho + llama.cpp)")
	print("=".repeat(70))

	var engine: OraculusEngine = server.get_node("OraculusEngine")
	var local: OraculusLocalBackend = engine.local

	if not local.is_available():
		print("")
		print("  SALTATO: backend locale non disponibile.")
		print("  Motivo: ", local.last_error)
		print("=".repeat(70))
		get_tree().quit(0)
		return

	print("  modello: ", local.model_path)
	print("  ctx=%d thread=%d temp=%.2f top_p=%.2f top_k=%d" % [
		OraculusData.N_CTX, OraculusData.N_THREADS,
		OraculusData.TEMPERATURE, OraculusData.TOP_P, OraculusData.TOP_K])
	print("")

	_check("il motore ha scelto il ramo locale", not engine.is_using_remote())
	_check("la catena di sampling e' stata accettata dall'addon",
		local.sampler_configured, local.last_error)

	await _test_system_prompt(local)
	await _test_chat(server)
	await _test_persona(server)
	await _test_riddle(server)

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


## Il system prompt viene sostituito a ogni chiamata: se l'ordine fra
## set system_prompt e reset_context fosse invertito, la seconda risposta
## risponderebbe ancora con il segreto della prima. Chiediamo un dato che
## esiste solo nel system prompt, cosi' il controllo non dipende da quanto
## il modello sia bravo a seguire istruzioni di stile.
func _test_system_prompt(local: OraculusLocalBackend) -> void:
	print("  [1] sostituzione del system prompt")
	var uno := await local.generate(
		"You are a gatekeeper. The password of the gate is ZIRCONE."
		+ " When asked for the password, say it.",
		"What is the password of the gate?", CHAT_TIMEOUT)
	print("      1a: «%s»" % uno)
	_check("la prima generazione locale produce testo", not uno.is_empty())
	_check("la prima generazione vede il suo system prompt",
		uno.to_upper().contains("ZIRCONE"), uno)

	var due := await local.generate(
		"You are a gatekeeper. The password of the gate is MARMO."
		+ " When asked for the password, say it.",
		"What is the password of the gate?", CHAT_TIMEOUT)
	print("      1b: «%s»" % due)
	_check("la seconda generazione vede il system prompt nuovo",
		due.to_upper().contains("MARMO"), due)
	_check("il system prompt vecchio non sopravvive al reset",
		not due.to_upper().contains("ZIRCONE"), due)


func _test_chat(server: Node) -> void:
	print("  [2] dialogo con un NPC")
	var res: Dictionary = await server.make_request("chat", {
		"player_input": "Who guards this place?",
		"npc_name": "Levias",
		"hostility": 70,
		"friendship": 0,
	})
	print("      Levias: «%s»" % String(res.get("response", "")))
	print("      source=%s lingua=%s ostilita'=%s" % [
		res.get("source"), res.get("detected_language"), res.get("new_hostility")])
	_check("la risposta arriva dal modello, non dal fallback",
		res.get("source") == "llama", String(res.get("source", "?")))
	_check("la risposta non e' vuota", not String(res.get("response", "")).is_empty())
	_check("la risposta sta nei 240 caratteri di pulisci()",
		String(res.get("response", "")).length() <= 240)
	_check("la lingua rilevata e' l'inglese", res.get("detected_language") == "inglese",
		String(res.get("detected_language", "?")))


## Due NPC diversi nella stessa sessione: il secondo non deve ereditare la
## persona del primo (e' il caso che il bug sull'ordine del reset romperebbe).
func _test_persona(server: Node) -> void:
	print("  [3] due NPC diversi di fila")
	var a: Dictionary = await server.make_request("chat", {
		"player_input": "Tell me your name.",
		"npc_name": "Rigon",
		"hostility": 90,
	})
	print("      Rigon: «%s»" % String(a.get("response", "")))
	var b: Dictionary = await server.make_request("chat", {
		"player_input": "Tell me your name.",
		"npc_name": "Malakai",
		"hostility": 40,
	})
	print("      Malakai: «%s»" % String(b.get("response", "")))
	_check("entrambi gli NPC rispondono con il modello",
		a.get("source") == "llama" and b.get("source") == "llama")
	_check("le due risposte sono distinte",
		String(a.get("response", "")) != String(b.get("response", "")))
	_check("la memoria resta separata per NPC",
		server.get_node("OraculusEngine").get_memory("Rigon").size() == 1
		and server.get_node("OraculusEngine").get_memory("Malakai").size() == 1)


func _test_riddle(server: Node) -> void:
	print("  [4] indovinello di una porta")
	var res: Dictionary = await server.make_request("riddle", {
		"door_id": "door_entrance",
		"language": "inglese",
		"session_id": "local-check",
	})
	var testo := String(res.get("riddle", ""))
	var risposta := String(res.get("answer", ""))
	print("      «%s»" % testo)
	print("      risposta attesa: %s" % risposta)
	_check("l'indovinello ha un testo", not testo.is_empty())
	_check("l'indovinello ha una risposta", not risposta.is_empty())
	_check("la risposta e' una parola sola", not risposta.strip_edges().contains(" "), risposta)
