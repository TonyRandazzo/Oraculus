# ============================================================================
# Porting di NPCDialogueEngine (ai/inference.py) + LlamaCppWrapper.
#
# Tiene la memoria per NPC, sceglie il backend di inferenza e applica la
# stessa sequenza di decisioni del Python: rilevamento lingua, intent,
# sblocco di Malakai, fallback quando il modello non risponde, correzione del
# nome dell'esercito, aggiornamento dell'ostilita'.
#
# Differenze deliberate rispetto a inference.py, tutte documentate:
#  - hash(): in Python l'hash delle stringhe e' randomizzato a ogni processo,
#    quindi lo stesso door_id dava indovinelli diversi a ogni riavvio.
#    String.hash() in Godot e' deterministico, cosi' la varieta' e' resa
#    esplicita mescolando session_id (che cambia a ogni partita) nella
#    chiave: stesso comportamento osservabile, ma riproducibile.
#  - il ramo locale passa da NobodyWho, che applica da se' il template della
#    chat: i token esatti del prompt non sono piu' quelli costruiti a mano da
#    build_prompt(), che resta portato e verificato per parita'.
# ============================================================================
class_name OraculusEngine
extends Node

const MEMORY_LIMIT := 10
const LOCAL_TIMEOUT := 60.0

var memory: Dictionary = {}
var local: OraculusLocalBackend = null
var remote: OraculusRemoteBackend = null

var _using_remote := true
var _available := false


func _ready() -> void:
	local = OraculusLocalBackend.new()
	local.name = "LocalBackend"
	add_child(local)
	remote = OraculusRemoteBackend.new()
	remote.name = "RemoteBackend"
	add_child(remote)


## Ordine di preferenza identico a LlamaCppWrapper._try_load(): prima il
## modello locale, poi l'API remota.
func setup() -> void:
	if await local.setup():
		_using_remote = false
		_available = true
		print("[Motore] LLM attivo (locale)")
		return
	print("[Motore] locale non disponibile: ", local.last_error)

	if await remote.probe():
		_using_remote = true
		_available = true
		print("[Motore] LLM attivo (remoto: ", remote.base_url, ")")
		return

	# Il proxy potrebbe essere solo lento a svegliarsi (Render va in sleep):
	# lo consideriamo comunque utilizzabile e sara' la singola richiesta a
	# fallire, con fallback testuale, invece di spegnere l'AI per la partita.
	remote.assume_available()
	_using_remote = true
	_available = true
	print("[Motore] LLM in modalita' remota non verificata: ", remote.last_error)


func is_available() -> bool:
	return _available


func is_using_remote() -> bool:
	return _using_remote


# --- memoria --------------------------------------------------------------

func get_memory(npc_name: String) -> Array:
	return memory.get(npc_name, [])


func _add_to_memory(npc_name: String, player: String, npc_resp: String) -> void:
	var storia: Array = memory.get(npc_name, [])
	storia.append({"player": player, "npc": npc_resp})
	if storia.size() > MEMORY_LIMIT:
		storia = storia.slice(storia.size() - MEMORY_LIMIT)
	memory[npc_name] = storia


func reset_memory(npc_name: Variant = null) -> void:
	if npc_name != null and not String(npc_name).is_empty():
		memory.erase(String(npc_name))
	else:
		memory.clear()


# --- dialogo --------------------------------------------------------------

## Equivalente di NPCDialogueEngine.generate_response(). params accetta le
## stesse chiavi del vecchio POST /chat.
func generate_response(params: Dictionary) -> Dictionary:
	var player_input := String(params.get("player_input", "")).strip_edges()
	if player_input.is_empty():
		return {"error": "player_input è obbligatorio"}

	var npc_name := String(params.get("npc_name", "Levias"))
	var hostility: int = clampi(int(params.get("hostility", 70)), 0, 100)
	var friendship: int = clampi(int(params.get("friendship", 0)), 0, 100)
	var language := String(params.get("language", ""))
	var context_vars: Variant = params.get("context_vars", {})

	var detected_lang := language if not language.is_empty() else OraculusLogic.detect_language(player_input)
	var intent := OraculusLogic.classify_intent(player_input)
	var history := get_memory(npc_name)

	var effective_hostility := hostility
	if npc_name == "Malakai" and OraculusLogic.check_malakai_unlock(player_input):
		effective_hostility = mini(hostility, 20)

	var response := await _generate(player_input, npc_name, effective_hostility, friendship,
		detected_lang, history, context_vars)
	var source := "llama"

	if response.is_empty():
		var tier := OraculusLogic.hostility_tier(effective_hostility, friendship)
		var pool: Array = OraculusData.FALLBACK.get(tier, OraculusData.FALLBACK["mid"])
		response = String(pool.pick_random())
		source = "fallback"
	else:
		response = OraculusLogic.enforce_army_name(response, detected_lang)

	var new_h := OraculusLogic.adjust_hostility(intent, hostility, friendship)
	if npc_name == "Rigon" and intent in ["violenza", "minaccia", "bugia"]:
		new_h = 100

	_add_to_memory(npc_name, player_input, response)

	return {
		"response": response,
		"detected_language": detected_lang,
		"new_hostility": new_h,
		"source": source,
		"intent": intent,
		"retrieval_score": 0.0,
		"npc_unlocked": npc_name == "Malakai" and effective_hostility != hostility,
		"npc_name": npc_name,
		"history": get_memory(npc_name),
	}


func _npc_data(npc_name: String) -> Dictionary:
	if OraculusData.NPC_DATA.has(npc_name):
		return OraculusData.NPC_DATA[npc_name]
	return {"personalita": "You are %s, an ancient spirit." % npc_name}


func _generate(player_input: String, npc_name: String, hostility: int, friendship: int,
		language: String, history: Array, context_vars: Variant) -> String:
	if not _available:
		return ""
	var npc_data := _npc_data(npc_name)
	var raw := ""

	if _using_remote:
		var system_msg := OraculusLogic.build_system_msg(npc_name, hostility, friendship,
			language, npc_data, context_vars)
		var messages: Array = [{"role": "system", "content": system_msg}]
		for h in history.slice(maxi(0, history.size() - 3)):
			messages.append({"role": "user", "content": String(h["player"])})
			messages.append({"role": "assistant", "content": String(h["npc"])})
		messages.append({"role": "user", "content": player_input})
		raw = await remote.chat_completion(messages, OraculusData.MAX_TOKENS,
			OraculusData.TEMPERATURE, OraculusData.TOP_P)
	else:
		# NobodyWho applica da se' il template del modello, quindi lo storico
		# entra nel system prompt con la stessa formattazione di build_prompt.
		var system_msg := OraculusLogic.build_system_msg(npc_name, hostility, friendship,
			language, npc_data, context_vars) + OraculusLogic.build_history_block(history)
		raw = await local.generate(system_msg, player_input, LOCAL_TIMEOUT)

	if raw.is_empty():
		return ""
	var cleaned := OraculusLogic.pulisci(raw, npc_name)
	return cleaned if cleaned.length() > 2 else ""


# --- indovinelli ----------------------------------------------------------

## Equivalente di generate_door_riddle(). Restituisce sempre un indovinello:
## quello del modello se valido, altrimenti uno di RIDDLE_FALLBACKS.
func generate_door_riddle(params: Dictionary) -> Dictionary:
	var door_id := String(params.get("door_id", "door_default"))
	var language := String(params.get("language", "inglese"))
	var theme := String(params.get("theme", ""))
	var session_id := String(params.get("session_id", ""))

	var result: Variant = await _generate_riddle(door_id, language, theme, session_id)
	if typeof(result) == TYPE_DICTIONARY:
		var ok: Dictionary = result
		print("[Riddle] door=%s session=%s answer=%s" % [door_id, session_id, ok["answer"]])
		return ok

	var pool: Array = OraculusData.RIDDLE_FALLBACKS.get(language, OraculusData.RIDDLE_FALLBACKS["inglese"])
	var idx: int = _seed_for(door_id + session_id) % pool.size()
	var chosen: Dictionary = pool[idx]
	print("[Riddle] door=%s session=%s uso il fallback, answer=%s" % [door_id, session_id, chosen["answer"]])
	return chosen


func _generate_riddle(door_id: String, language: String, theme: String, session_id: String) -> Variant:
	if not _available:
		return null

	var chosen_theme := theme
	if chosen_theme.is_empty():
		# Python usava hash(door_id) senza session: dava un tema fisso per
		# porta dentro il processo e diverso a ogni riavvio. Mescolando
		# session_id otteniamo lo stesso effetto in modo riproducibile.
		var idx: int = _seed_for(door_id + session_id) % OraculusData.DEFAULT_RIDDLE_THEMES.size()
		chosen_theme = OraculusData.DEFAULT_RIDDLE_THEMES[idx]

	var system := OraculusLogic.build_riddle_system(chosen_theme, language)
	var user_msg := OraculusLogic.build_riddle_user(language, chosen_theme, session_id)

	var raw := ""
	if _using_remote:
		var messages: Array = [
			{"role": "system", "content": system},
			{"role": "user", "content": user_msg},
		]
		raw = await remote.chat_completion(messages, OraculusData.RIDDLE_MAX_TOKENS,
			OraculusData.RIDDLE_TEMPERATURE, OraculusData.RIDDLE_TOP_P)
	else:
		# Gli indovinelli in Python giravano con parametri di sampling propri.
		raw = await local.generate(system, user_msg, LOCAL_TIMEOUT, {
			"temperature": OraculusData.RIDDLE_TEMPERATURE,
			"top_p": OraculusData.RIDDLE_TOP_P,
			"top_k": OraculusData.RIDDLE_TOP_K,
		})

	if raw.is_empty():
		return null
	return OraculusLogic.parse_riddle_response(raw)


static func _seed_for(key: String) -> int:
	return absi(key.hash())
