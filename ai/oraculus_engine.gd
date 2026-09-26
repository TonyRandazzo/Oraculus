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
#  - la scelta del backend: il Python preferiva sempre il locale; qui i due
#    rami fanno una gara all'avvio e vince il primo che risponde (setup()).
# ============================================================================
class_name OraculusEngine
extends Node

const MEMORY_LIMIT := 10
const LOCAL_TIMEOUT := 60.0
## Quante volte richiedere un indovinello prima di usare RIDDLE_FALLBACKS.
const RIDDLE_ATTEMPTS := 3
## Quante volte rifare una battuta uscita tutta fuori personaggio (vedi
## OraculusLogic.FUORI_PERSONAGGIO) prima di ripiegare su FALLBACK.
const CHAT_ATTEMPTS := 2
## Per forzare un ramo invece della gara: "locale" o "remoto". Serve
## soprattutto ai collaudi, che vogliono esercitare un ramo preciso.
const ENV_BACKEND := "ORACULUS_BACKEND"
## Quanto aspettare il remoto nella gara. Se il locale non c'e' (Web) e il
## remoto non risponde entro questo tempo lo si usa comunque: Render potrebbe
## solo star uscendo dallo sleep.
const REMOTE_RACE_TIMEOUT := 10.0

var memory: Dictionary = {}
var local: OraculusLocalBackend = null
var remote: OraculusRemoteBackend = null

var _using_remote := true
var _available := false
## Generazioni in corso o in coda, dialoghi e indovinelli. Una battuta
## ambientale (senza frase del cavaliere) non parte se non e' zero: vedi
## generate_response().
var _in_volo := 0


func _ready() -> void:
	local = OraculusLocalBackend.new()
	local.name = "LocalBackend"
	add_child(local)
	remote = OraculusRemoteBackend.new()
	remote.name = "RemoteBackend"
	add_child(remote)


## Una gara: locale e remoto partono insieme, ciascuno con una generazione
## vera e minima, e il primo che risponde diventa il ramo della partita.
## L'altro viene chiuso: il modello locale liberato dalla memoria, oppure il
## remoto non riceve piu' richieste. Un errore (402, 404, 500, rete, timeout)
## non e' una risposta: con il credito HF finito vince il locale anche se il
## proxy e' sveglio.
func setup() -> void:
	var forzato := OS.get_environment(ENV_BACKEND).strip_edges().to_lower()
	var t0 := Time.get_ticks_msec()
	var gara := {"vincitore": "", "locale": null, "remoto": null}
	if forzato == "remoto":
		gara["locale"] = false
	else:
		_corri_locale(gara)
	if forzato == "locale":
		gara["remoto"] = false
	else:
		_corri_remoto(gara)

	while String(gara["vincitore"]).is_empty() and (gara["locale"] == null or gara["remoto"] == null):
		await get_tree().process_frame

	var ms := Time.get_ticks_msec() - t0
	match String(gara["vincitore"]):
		"locale":
			remote.chiudi()
			_using_remote = false
			_available = true
			print("[Motore] LLM attivo: locale, ha risposto per primo (%d ms). Remoto chiuso." % ms)
		"remoto":
			local.chiudi()
			_using_remote = true
			_available = true
			print("[Motore] LLM attivo: remoto (%s), ha risposto per primo (%d ms). Locale chiuso." % [
				remote.base_url, ms])
		_:
			local.chiudi()
			_using_remote = true
			if forzato == "locale":
				_available = false
				print("[Motore] ramo locale forzato ma non disponibile: ", local.last_error)
				return
			# Il proxy potrebbe essere solo lento a svegliarsi (Render va in
			# sleep): lo consideriamo comunque utilizzabile e sara' la singola
			# richiesta a fallire, con fallback testuale, invece di spegnere
			# l'AI per la partita.
			remote.assume_available()
			_available = true
			print("[Motore] nessuno ha risposto; remoto non verificato. Remoto: %s | locale: %s" % [
				remote.last_error, local.last_error])


## Il modello caricato non basta: deve generare, come si chiede al remoto.
func _corri_locale(gara: Dictionary) -> void:
	var ok: bool = await local.setup()
	if ok:
		ok = not (await local.generate("Answer with one word.", "Hi", LOCAL_TIMEOUT,
			{"max_tokens": 4})).is_empty()
	gara["locale"] = ok
	if ok and String(gara["vincitore"]).is_empty():
		gara["vincitore"] = "locale"


func _corri_remoto(gara: Dictionary) -> void:
	var ok: bool = await remote.verifica(REMOTE_RACE_TIMEOUT)
	gara["remoto"] = ok
	if ok and String(gara["vincitore"]).is_empty():
		gara["vincitore"] = "remoto"


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
## stesse chiavi del vecchio POST /chat, piu' "direction": un'istruzione di
## regia dello script ("presentati in una frase", "sei stato colpito"). Non e'
## una frase del cavaliere, quindi non passa da intent, sblocco di Malakai e
## memoria, e al modello arriva come nota di scena (build_direction_msg).
## player_input puo' mancare se c'e' direction.
##
## on_partial, se valida, riceve la risposta mentre il modello la scrive,
## gia' ripulita (pulisci_parziale + nome dell'esercito) e solo quando
## cambia. Il valore restituito resta quello definitivo: e' quello da
## mostrare alla fine, e puo' differire di poco nella coda dall'ultimo
## parziale. Senza on_partial la richiesta non va in streaming.
func generate_response(params: Dictionary, on_partial: Callable = Callable()) -> Dictionary:
	var player_input := String(params.get("player_input", "")).strip_edges()
	var direction := String(params.get("direction", "")).strip_edges()
	if player_input.is_empty() and direction.is_empty():
		return {"error": "player_input è obbligatorio"}

	var npc_name := String(params.get("npc_name", "Levias"))
	var hostility: int = clampi(int(params.get("hostility", 70)), 0, 100)
	var friendship: int = clampi(int(params.get("friendship", 0)), 0, 100)
	var language := String(params.get("language", ""))
	var context_vars: Variant = params.get("context_vars", {})

	var detected_lang := language
	if detected_lang.is_empty():
		detected_lang = OraculusLogic.detect_language(player_input) if not player_input.is_empty() else "inglese"
	var intent := OraculusLogic.classify_intent(player_input) if not player_input.is_empty() else "generico"
	var history := get_memory(npc_name)

	var effective_hostility := hostility
	if npc_name == "Malakai" and OraculusLogic.check_malakai_unlock(player_input):
		effective_hostility = mini(hostility, 20)

	# Una battuta ambientale — la presentazione al caricamento della scena, la
	# reazione a un colpo — non si mette in coda: se il modello sta gia'
	# lavorando si usa subito FALLBACK. Al caricamento di main.tscn ~40 NPC
	# chiedono insieme la presentazione, e in fila sull'unico worker locale
	# erano ~47 s (misurato nel log di gioco) davanti alla prima frase del
	# giocatore. Cosi' il giocatore aspetta al massimo una generazione in corso.
	var response := ""
	var occupato := player_input.is_empty() and _in_volo > 0
	if not occupato:
		_in_volo += 1
		response = await _generate(player_input, direction, npc_name, effective_hostility,
			friendship, detected_lang, history, context_vars, on_partial)
		_in_volo -= 1
	var source := "llama"

	if response.is_empty():
		var tier := OraculusLogic.hostility_tier(effective_hostility, friendship)
		var pool: Array = OraculusData.FALLBACK.get(tier, OraculusData.FALLBACK["mid"])
		response = String(pool.pick_random())
		source = "occupato" if occupato else "fallback"
	else:
		response = OraculusLogic.enforce_army_name(response, detected_lang)

	var new_h := OraculusLogic.adjust_hostility(intent, hostility, friendship)
	if npc_name == "Rigon" and intent in ["violenza", "minaccia", "bugia"]:
		new_h = 100

	# Solo le frasi vere del cavaliere: un'istruzione di regia nello storico
	# diventerebbe "Player: Announce presence in ONE short sentence", e il
	# modello la rileggerebbe a ogni turno successivo.
	if not player_input.is_empty():
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


func _generate(player_input: String, direction: String, npc_name: String, hostility: int,
		friendship: int, language: String, history: Array, context_vars: Variant,
		on_partial: Callable = Callable()) -> String:
	if not _available:
		return ""
	var npc_data := _npc_data(npc_name)
	var user_msg := OraculusLogic.decorate_user_msg(player_input, npc_name, language)
	if not direction.is_empty():
		user_msg = OraculusLogic.build_direction_msg(player_input, direction, npc_name, language)

	# Dal testo grezzo che cresce a quello da mostrare: le stesse tre passate
	# della battuta finale (filtro, pulisci, filtro), nella versione che non
	# chiude la frase. Senza il confronto con l'ultimo inviato l'NPC
	# riscriverebbe la stessa battuta a ogni token trattenuto.
	var on_raw := Callable()
	var ultimo := {"testo": ""}
	if on_partial.is_valid():
		on_raw = func(testo_grezzo: String) -> void:
			var parziale := OraculusLogic.filtra_fuori_personaggio_parziale(
				OraculusLogic.pulisci_parziale(
					OraculusLogic.filtra_fuori_personaggio_parziale(testo_grezzo), npc_name))
			parziale = OraculusLogic.enforce_army_name(parziale, language)
			if parziale.is_empty() or parziale == ultimo["testo"]:
				return
			ultimo["testo"] = parziale
			if on_partial.is_valid():
				on_partial.call(parziale)

	for tentativo in CHAT_ATTEMPTS:
		var raw := ""
		if _using_remote:
			var system_msg := OraculusLogic.build_system_msg(npc_name, hostility, friendship,
				language, npc_data, context_vars)
			var messages: Array = [{"role": "system", "content": system_msg}]
			for h in history.slice(maxi(0, history.size() - 3)):
				messages.append({"role": "user", "content": OraculusLogic.knight_line(String(h["player"]))})
				messages.append({"role": "assistant", "content": String(h["npc"])})
			messages.append({"role": "user", "content": user_msg})
			if on_raw.is_valid():
				raw = await remote.chat_completion_stream(messages, OraculusData.MAX_TOKENS,
					OraculusData.TEMPERATURE, OraculusData.TOP_P, on_raw)
			else:
				raw = await remote.chat_completion(messages, OraculusData.MAX_TOKENS,
					OraculusData.TEMPERATURE, OraculusData.TOP_P)
		else:
			# NobodyWho applica da se' il template del modello, quindi lo
			# storico entra nel system prompt con la stessa formattazione di
			# build_prompt.
			var system_msg := OraculusLogic.build_system_msg(npc_name, hostility, friendship,
				language, npc_data, context_vars) + OraculusLogic.build_history_block(history)
			raw = await local.generate(system_msg, user_msg, LOCAL_TIMEOUT,
				{"max_tokens": OraculusData.MAX_TOKENS}, on_raw)

		# Niente testo e' un guasto (rete, credito finito, timeout): rifare la
		# richiesta costerebbe un'altra attesa per lo stesso esito.
		if raw.is_empty():
			return ""
		# Il filtro prima di pulisci() lavora sulle righe vere del modello
		# (un titolo markdown sparisce invece di finire fuso in un elenco);
		# quello dopo vede la battuta come la leggera' il giocatore.
		var filtrato := OraculusLogic.filtra_fuori_personaggio(raw)
		if not filtrato.is_empty():
			var cleaned := OraculusLogic.filtra_fuori_personaggio(
				OraculusLogic.pulisci(filtrato, npc_name))
			if cleaned.length() > 2:
				return cleaned
		print("[Motore] %s: battuta fuori personaggio (tentativo %d), scartata: «%s»" % [
			npc_name, tentativo + 1, raw.substr(0, 160).replace("\n", " ")])
		ultimo["testo"] = ""
	return ""


# --- indovinelli ----------------------------------------------------------

## Equivalente di generate_door_riddle(). Restituisce sempre un indovinello:
## quello del modello se valido, altrimenti uno di RIDDLE_FALLBACKS.
func generate_door_riddle(params: Dictionary) -> Dictionary:
	var door_id := String(params.get("door_id", "door_default"))
	var language := String(params.get("language", "inglese"))
	var theme := String(params.get("theme", ""))
	var session_id := String(params.get("session_id", ""))

	# Un solo tentativo non basta: il modello rispetta il formato
	# RIDDLE:/ANSWER: quasi sempre, ma non sempre — capita che scriva
	# l'indovinello e si fermi prima della riga ANSWER, e allora
	# parse_riddle_response() (giustamente severa: senza risposta la porta non
	# si apre) torna null e il giocatore riceve un indovinello di riserva
	# anche con il modello acceso e funzionante. Ritentare costa ~1 s in
	# locale ed e' l'unica cosa che serve, perche' il fallimento e' casuale.
	for tentativo in RIDDLE_ATTEMPTS:
		_in_volo += 1
		var result: Variant = await _generate_riddle(door_id, language, theme, session_id)
		_in_volo -= 1
		if typeof(result) == TYPE_DICTIONARY:
			var ok: Dictionary = result
			print("[Riddle] door=%s session=%s answer=%s (tentativo %d)" % [
				door_id, session_id, ok["answer"], tentativo + 1])
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
			"max_tokens": OraculusData.RIDDLE_MAX_TOKENS,
		})

	if raw.is_empty():
		return null
	return OraculusLogic.parse_riddle_response(raw)


static func _seed_for(key: String) -> int:
	return absi(key.hash())
