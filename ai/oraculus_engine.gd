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
#    rami fanno una gara all'avvio e vince il primo che risponde (setup()),
#    e se il vincitore smette di rispondere la partita passa all'altro
#    (_passa_all_altro()).
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
## Quanto dura la gara di setup(). Chi non ha risposto entro questo tempo
## l'ha persa; se non ha risposto nessuno vedi setup().
const RACE_TIMEOUT := 3.0
## Tetto di una richiesta remota durante la partita. Una battuta da 80 token
## arriva in ~3 s: oltre questo il proxy si considera muto e si passa al
## locale, invece di lasciare il giocatore davanti ai puntini per 90 s.
const REMOTE_REQUEST_TIMEOUT := 15.0

var memory: Dictionary = {}
var local: OraculusLocalBackend = null
var remote: OraculusRemoteBackend = null

var _using_remote := true
var _available := false
## Il ramo imposto da ORACULUS_BACKEND, "" se decide la gara. Un ramo imposto
## non cede mai il posto all'altro.
var _forzato := ""
## Vero mentre _passa_all_altro() sta cambiando ramo: gli altri NPC che nel
## frattempo trovano il ramo muto aspettano quel passaggio invece di
## avviarne un secondo.
var _cambio_in_corso := false
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
	remote.request_timeout = REMOTE_REQUEST_TIMEOUT
	add_child(remote)
	# Anche qui, non solo in setup(): i collaudi che saltano la gara e
	# impongono un ramo non devono vederlo cedere il posto all'altro.
	_forzato = _ramo_forzato()


static func _ramo_forzato() -> String:
	var ramo := OS.get_environment(ENV_BACKEND).strip_edges().to_lower()
	return ramo if ramo in ["locale", "remoto"] else ""


## Una gara: locale e remoto partono insieme, ciascuno con una generazione
## vera e minima, e il primo che risponde entro RACE_TIMEOUT diventa il ramo
## della partita. L'altro viene chiuso: il modello locale liberato dalla
## memoria, oppure il remoto non riceve piu' richieste. Un errore (402, 404,
## 500, rete, timeout) non e' una risposta: con il credito HF finito vince il
## locale anche se il proxy e' sveglio.
##
## La scelta vale per tutta la partita, attraverso i cambi di scena (il
## motore vive nell'autoload AIServerManager), finche' il ramo scelto non
## smette di rispondere: allora _passa_all_altro().
func setup() -> void:
	_forzato = _ramo_forzato()
	var t0 := Time.get_ticks_msec()
	var scadenza := t0 + int(RACE_TIMEOUT * 1000.0)
	var gara := {"vincitore": "", "locale": null, "remoto": null}
	if _forzato == "remoto":
		gara["locale"] = false
	else:
		_corri_locale(gara)
	if _forzato == "locale":
		gara["remoto"] = false
	else:
		_corri_remoto(gara)

	while String(gara["vincitore"]).is_empty() \
			and (gara["locale"] == null or gara["remoto"] == null) \
			and Time.get_ticks_msec() < scadenza:
		await get_tree().process_frame

	var ms := Time.get_ticks_msec() - t0
	var vincitore := String(gara["vincitore"])
	if vincitore.is_empty() and gara["locale"] == null:
		# Nessuno ha risposto in tempo, ma il locale sta ancora caricando
		# senza aver fallito (primo avvio, .gguf da estrarre dal .pck): e' il
		# ramo piu' prevedibile, le richieste aspetteranno che finisca.
		vincitore = "locale"
		print("[Motore] nessuna risposta in %d ms: tengo il locale, ancora in caricamento." % ms)

	match vincitore:
		"locale":
			remote.chiudi()
			_using_remote = false
			_available = true
			print("[Motore] LLM attivo: locale (%d ms). Remoto chiuso." % ms)
		"remoto":
			local.chiudi()
			_using_remote = true
			_available = true
			print("[Motore] LLM attivo: remoto (%s), ha risposto per primo (%d ms). Locale chiuso." % [
				remote.base_url, ms])
			_scalda_remoto()
		_:
			local.chiudi()
			_using_remote = true
			if _forzato == "locale":
				_available = false
				print("[Motore] ramo locale forzato ma non disponibile: ", local.last_error)
				return
			# Il proxy potrebbe essere solo lento a svegliarsi (Render va in
			# sleep): lo consideriamo comunque utilizzabile e sara' la singola
			# richiesta a fallire, con fallback testuale, invece di spegnere
			# l'AI per la partita.
			remote.riapri()
			_available = true
			print("[Motore] nessuno ha risposto; remoto non verificato. Remoto: %s | locale: %s" % [
				remote.last_error, local.last_error])


## In background, dopo la vittoria del remoto: vedi remote.scalda(). Conta
## come una generazione in corso, cosi' le presentazioni degli NPC che
## arrivano nel frattempo ripiegano subito su FALLBACK invece di mettersi in
## fila dietro ai ~15 s del primo prompt.
func _scalda_remoto() -> void:
	_in_volo += 1
	var t0 := Time.get_ticks_msec()
	var ok: bool = await remote.scalda()
	_in_volo -= 1
	print("[Motore] contesto in cache sul remoto: %s (%d ms)" % ["ok" if ok else "fallito", Time.get_ticks_msec() - t0])


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
	var ok: bool = await remote.verifica(RACE_TIMEOUT)
	gara["remoto"] = ok
	if ok and String(gara["vincitore"]).is_empty():
		gara["vincitore"] = "remoto"


## Il ramo in uso (da_remoto dice quale era) non ha risposto a una richiesta:
## la partita passa all'altro, senza che il giocatore se ne accorga — la
## richiesta viene rifatta li' e la battuta arriva comunque. Restituisce true
## se c'e' un ramo nuovo su cui riprovare.
##
## Un solo passaggio per volta: con ~40 NPC in scena, molti trovano il ramo
## muto insieme, e solo il primo cambia ramo; gli altri aspettano e
## riprovano sul ramo nuovo.
func _passa_all_altro(da_remoto: bool) -> bool:
	while _cambio_in_corso:
		await get_tree().process_frame
	if _using_remote != da_remoto:
		return true
	if not _forzato.is_empty():
		return false

	_cambio_in_corso = true
	var ok := true
	if da_remoto:
		local.riapri()
		ok = await _locale_pronto()
		if ok:
			remote.chiudi()
			_using_remote = false
			print("[Motore] il remoto non risponde (%s): passo al locale." % remote.last_error)
		else:
			local.chiudi()
			print("[Motore] il remoto non risponde e il locale non c'e' (%s): resto sul remoto." % local.last_error)
	else:
		remote.riapri()
		local.chiudi()
		_using_remote = true
		print("[Motore] il locale non risponde (%s): passo al remoto." % local.last_error)
	_cambio_in_corso = false
	return ok


## Aspetta il caricamento in corso del modello locale, o lo ricarica se
## era stato liberato. False se il locale non c'e' (Web, addon o .gguf
## mancanti).
func _locale_pronto() -> bool:
	while local.is_loading():
		await get_tree().process_frame
	if local.is_available():
		return true
	return await local.setup()


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
		var su_remoto := _using_remote
		var raw := await _chiedi_battuta(su_remoto, user_msg, npc_name, hostility, friendship,
			language, npc_data, history, context_vars, on_raw)
		# Il ramo e' muto: si rifa' la stessa richiesta sull'altro.
		if raw.is_empty() and await _passa_all_altro(su_remoto):
			ultimo["testo"] = ""
			raw = await _chiedi_battuta(_using_remote, user_msg, npc_name, hostility, friendship,
				language, npc_data, history, context_vars, on_raw)

		# Niente testo neanche dall'altro ramo e' un guasto (rete, credito
		# finito, timeout): rifare la richiesta costerebbe un'altra attesa per
		# lo stesso esito.
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


## Una sola richiesta di battuta sul ramo indicato, testo grezzo o "".
func _chiedi_battuta(su_remoto: bool, user_msg: String, npc_name: String, hostility: int,
		friendship: int, language: String, npc_data: Dictionary, history: Array,
		context_vars: Variant, on_raw: Callable) -> String:
	var system_msg := OraculusLogic.build_system_msg(npc_name, hostility, friendship,
		language, npc_data, context_vars)
	if su_remoto:
		var messages: Array = [{"role": "system", "content": system_msg}]
		for h in history.slice(maxi(0, history.size() - 3)):
			messages.append({"role": "user", "content": OraculusLogic.knight_line(String(h["player"]))})
			messages.append({"role": "assistant", "content": String(h["npc"])})
		messages.append({"role": "user", "content": user_msg})
		if on_raw.is_valid():
			return await remote.chat_completion_stream(messages, OraculusData.MAX_TOKENS,
				OraculusData.TEMPERATURE, OraculusData.TOP_P, on_raw)
		return await remote.chat_completion(messages, OraculusData.MAX_TOKENS,
			OraculusData.TEMPERATURE, OraculusData.TOP_P)

	# Il locale puo' aver vinto la gara mentre caricava ancora il modello.
	while local.is_loading():
		await get_tree().process_frame
	# NobodyWho applica da se' il template del modello, quindi lo storico
	# entra nel system prompt con la stessa formattazione di build_prompt.
	return await local.generate(system_msg + OraculusLogic.build_history_block(history),
		user_msg, LOCAL_TIMEOUT, {"max_tokens": OraculusData.MAX_TOKENS}, on_raw)


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

	var user_msg := OraculusLogic.build_riddle_user(language, chosen_theme, session_id)

	var su_remoto := _using_remote
	var raw := await _chiedi_indovinello(su_remoto, chosen_theme, language, user_msg)
	if raw.is_empty() and await _passa_all_altro(su_remoto):
		raw = await _chiedi_indovinello(_using_remote, chosen_theme, language, user_msg)

	if raw.is_empty():
		return null
	return OraculusLogic.parse_riddle_response(raw)


func _chiedi_indovinello(su_remoto: bool, theme: String, language: String, user_msg: String) -> String:
	# Sul remoto STORY_CONTEXT va in testa: vedi build_riddle_system().
	var system := OraculusLogic.build_riddle_system(theme, language, su_remoto)
	if su_remoto:
		var messages: Array = [
			{"role": "system", "content": system},
			{"role": "user", "content": user_msg},
		]
		return await remote.chat_completion(messages, OraculusData.RIDDLE_MAX_TOKENS,
			OraculusData.RIDDLE_TEMPERATURE, OraculusData.RIDDLE_TOP_P)
	while local.is_loading():
		await get_tree().process_frame
	# Gli indovinelli in Python giravano con parametri di sampling propri.
	return await local.generate(system, user_msg, LOCAL_TIMEOUT, {
		"temperature": OraculusData.RIDDLE_TEMPERATURE,
		"top_p": OraculusData.RIDDLE_TOP_P,
		"top_k": OraculusData.RIDDLE_TOP_K,
		"max_tokens": OraculusData.RIDDLE_MAX_TOKENS,
	})


static func _seed_for(key: String) -> int:
	return absi(key.hash())
