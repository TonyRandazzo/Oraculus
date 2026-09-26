# ============================================================================
# Ramo di inferenza locale: sostituisce llama_cpp.Llama(...).
#
# Usa NobodyWho (GDExtension su llama.cpp, in addons/nobodywho/). L'addon
# viene raggiunto per riflessione, mai per nome di classe: se non e'
# installato questo file compila comunque e il backend si dichiara non
# disponibile, cosi' il motore ripiega sul ramo remoto senza rompere il
# progetto.
#
# Sui nomi: verificati su NobodyWho v11.0.0 (NobodyWhoModel.model_path,
# NobodyWhoChat.model_node / context_length / thread_count / start_worker /
# say, segnali worker_started, worker_failed, response_finished). Le versioni
# precedenti usavano altri nomi, quindi per ogni concetto proviamo una lista
# di candidati e ci fermiamo al primo che esiste davvero.
#
# Sul percorso del modello: llama.cpp vuole un file vero sul filesystem, un
# .gguf dentro il .pck non e' leggibile. Se il modello esiste solo in res://
# lo copiamo una volta in user:// e usiamo quello.
# ============================================================================
class_name OraculusLocalBackend
extends Node

const CLASS_MODEL := "NobodyWhoModel"
const CLASS_CHAT := "NobodyWhoChat"
const CLASS_SAMPLER_BUILDER := "NobodyWhoSamplerBuilder"
const ENV_MODEL_PATH := "ORACULUS_MODEL_PATH"
const COPY_CHUNK := 4 * 1024 * 1024
const WORKER_TIMEOUT := 120.0
## Quanto aspettare response_finished dopo aver fermato noi la generazione.
const STOP_GRACE := 3.0
## llama.cpp guarda indietro di 64 token per la penalita' di ripetizione:
## e' anche il default di llama-cpp-python, che inference.py non cambiava.
const PENALTY_LAST_N := 64

var last_error: String = ""
var model_path: String = ""
## True quando la catena di sampling e' stata accettata dall'addon.
var sampler_configured := false

var _available := false
var _busy := false
var _worker_ready := false
var _model: Node = null
var _chat: Node = null
var _sampler_applied := {}
## Chiuso da OraculusEngine quando il remoto ha vinto la gara di setup():
## da li' in poi il ramo locale non genera piu' e il modello viene liberato.
var _chiuso := false
var _in_setup := false


func is_available() -> bool:
	return _available


func is_busy() -> bool:
	return _busy


## Carica il modello locale e aspetta che il worker sia davvero pronto.
## Restituisce false (con last_error popolato) se l'addon manca, il .gguf non
## si trova o llama.cpp rifiuta il modello: e' un esito normale, non fatale.
## False anche se nel frattempo il ramo e' stato chiuso (vedi chiudi()).
func setup() -> bool:
	if _chiuso:
		return false
	_in_setup = true
	var ok: bool = await _setup()
	_in_setup = false
	if _chiuso:
		_libera()
		return false
	return ok


## Chiude il ramo locale: il remoto ha risposto prima nella gara di
## OraculusEngine.setup(), e il modello resterebbe in RAM e VRAM per niente.
## Se sta ancora caricando o generando lo si libera appena finisce: togliere
## i nodi dell'addon a meta' lavoro lascerebbe i suoi segnali senza
## destinatario.
func chiudi() -> void:
	_chiuso = true
	_available = false
	last_error = "chiuso: il remoto ha risposto per primo (ORACULUS_BACKEND=locale per forzarlo)"
	if not _in_setup and not _busy:
		_libera()


func _libera() -> void:
	for n in [_chat, _model]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_chat = null
	_model = null
	_worker_ready = false
	_available = false


func _setup() -> bool:
	if OS.get_name() == "Web":
		last_error = "le GDExtension native non girano in wasm"
		return false
	if not ClassDB.class_exists(CLASS_CHAT) or not ClassDB.class_exists(CLASS_MODEL):
		last_error = "addon NobodyWho non installato (addons/nobodywho/)"
		return false

	model_path = _resolve_model_path()
	if model_path.is_empty():
		last_error = "modello non trovato: " + OraculusData.MODEL_PATH
		return false
	# Il remoto puo' aver gia' vinto mentre si cercava (o si estraeva) il
	# .gguf: inutile caricarlo in memoria per poi buttarlo.
	if _chiuso:
		return false

	var model_obj: Object = ClassDB.instantiate(CLASS_MODEL)
	if not (model_obj is Node):
		last_error = CLASS_MODEL + " non e' un Node: versione di NobodyWho incompatibile"
		return false
	_model = model_obj
	_model.name = "NobodyWhoModel"
	if not _set_first(_model, ["model_path"], model_path):
		last_error = "proprieta' model_path assente su " + CLASS_MODEL
		return false
	add_child(_model)

	var chat_obj: Object = ClassDB.instantiate(CLASS_CHAT)
	if not (chat_obj is Node):
		last_error = CLASS_CHAT + " non e' un Node: versione di NobodyWho incompatibile"
		return false
	_chat = chat_obj
	_chat.name = "NobodyWhoChat"
	# v11 la chiama model_node; le versioni piu' vecchie model. Senza questa
	# il worker parte e muore con "Model node was not set".
	if not _set_first(_chat, ["model_node", "model"], _model):
		last_error = "nessuna proprieta' per collegare il modello su " + CLASS_CHAT
		return false
	_set_first(_chat, ["context_length", "n_ctx"], OraculusData.N_CTX)
	_set_first(_chat, ["thread_count", "n_threads"], OraculusData.N_THREADS)
	add_child(_chat)

	if not _chat.has_signal("response_finished"):
		last_error = "segnale response_finished assente: versione di NobodyWho incompatibile"
		return false

	if not await _start_worker():
		return false

	# Dopo l'avvio, non prima: a worker fermo l'addon scarta la
	# configurazione del sampler con un semplice warning.
	sampler_configured = _apply_sampler(
		OraculusData.TEMPERATURE, OraculusData.TOP_P, OraculusData.TOP_K, _new_seed())
	if not sampler_configured:
		push_warning("[Oraculus/locale] sampling ai valori di default dell'addon: " + last_error)

	_available = true
	if not _chiuso:
		print("[Oraculus/locale] NobodyWho attivo, modello: ", model_path)
	return true


## Avvia il worker e aspetta worker_started. Il caricamento del .gguf avviene
## in un thread dell'addon: senza questa attesa dichiareremmo il backend
## pronto mentre llama.cpp sta ancora leggendo (o ha gia' fallito).
func _start_worker() -> bool:
	var box := {"ok": false, "fail": "", "done": false}
	var on_started := func() -> void:
		box["ok"] = true
		box["done"] = true
	var on_failed := func(err: String) -> void:
		box["fail"] = err
		box["done"] = true
	var has_signals := _chat.has_signal("worker_started") and _chat.has_signal("worker_failed")
	if has_signals:
		_chat.connect("worker_started", on_started, CONNECT_ONE_SHOT)
		_chat.connect("worker_failed", on_failed, CONNECT_ONE_SHOT)

	if not _call_first(_chat, ["start_worker", "start"]):
		last_error = "nessun metodo di avvio su " + CLASS_CHAT
		return false

	if not has_signals:
		# Versione senza segnali di avvio: non c'e' niente da aspettare.
		_worker_ready = true
		return true

	var elapsed := 0.0
	while not bool(box["done"]) and elapsed < WORKER_TIMEOUT:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if _chat.is_connected("worker_started", on_started):
		_chat.disconnect("worker_started", on_started)
	if _chat.is_connected("worker_failed", on_failed):
		_chat.disconnect("worker_failed", on_failed)

	if not bool(box["done"]):
		last_error = "timeout nel caricamento del modello (%.0fs)" % WORKER_TIMEOUT
		return false
	if not bool(box["ok"]):
		last_error = "llama.cpp ha rifiutato il modello: " + String(box["fail"])
		return false
	_worker_ready = true
	return true


## Catena di sampling equivalente a quella che inference.py passava a
## llama_cpp: penalties -> top_k -> top_p -> temperature -> seed -> dist.
## In v11 non esiste piu' NobodyWhoSampler: si costruisce con un builder e si
## passa a set_sampler_config(). Ripieghiamo sui preset se il builder manca.
##
## Il seed non e' un dettaglio: l'addon, se non glielo si dice, ne usa uno
## fisso (1234). Con un seed fisso lo stesso prompt produce SEMPRE la stessa
## identica risposta — lo stesso NPC, interrogato due volte allo stesso modo,
## ripete la battuta parola per parola anche in partite diverse, e un
## indovinello che esce malformato resta malformato per sempre, quindi
## ritentarlo e' inutile. llama_cpp, in inference.py, usava il proprio default
## (seed casuale): passandone uno nuovo a ogni generazione torniamo a quel
## comportamento.
func _apply_sampler(temperature: float, top_p: float, top_k: int, seed: int) -> bool:
	if not _worker_ready:
		# A worker fermo l'addon scarta la configurazione e va avanti con i
		# suoi default: meglio accorgersene qui che chiedersi perche' le
		# risposte sembrano piu' sregolate di quelle del Python.
		last_error = "sampler configurato prima dell'avvio del worker"
		return false

	var wanted := {"t": temperature, "p": top_p, "k": top_k, "s": seed}
	if _sampler_applied == wanted:
		return true

	if ClassDB.class_exists(CLASS_SAMPLER_BUILDER) and _chat.has_method("set_sampler_config"):
		var builder: Object = ClassDB.instantiate(CLASS_SAMPLER_BUILDER)
		if builder != null:
			var cfg: Variant = builder
			cfg = cfg.call("penalties", PENALTY_LAST_N, OraculusData.REPEAT_PENALTY, 0.0, 0.0)
			cfg = cfg.call("top_k", top_k)
			cfg = cfg.call("top_p", top_p, 1)
			cfg = cfg.call("temperature", temperature)
			if builder.has_method("seed"):
				cfg = cfg.call("seed", seed)
			cfg = cfg.call("dist")
			if cfg != null:
				_chat.call("set_sampler_config", cfg)
				_sampler_applied = wanted
				return true

	if _chat.has_method("set_sampler_preset_temperature"):
		_chat.call("set_sampler_preset_temperature", temperature)
		_sampler_applied = wanted
		return true

	last_error = "nessun modo di configurare il sampling su " + CLASS_CHAT
	return false


## Genera una risposta. system_prompt viene sostituito a ogni chiamata e il
## contesto azzerato: il motore e' senza stato per richiesta, esattamente
## come lo era inference.py, che ricostruiva il prompt da zero ogni volta.
## sampling accetta le chiavi temperature/top_p/top_k, per i parametri
## diversi che il Python usava sugli indovinelli. on_text, se valida, riceve
## il testo accumulato a ogni token: e' lo streaming, gratis, perche' il
## conteggio dei token per max_tokens ascolta gia' response_updated.
func generate(system_prompt: String, user_msg: String, timeout: float = 60.0,
		sampling: Dictionary = {}, on_text: Callable = Callable()) -> String:
	var testo: String = await _genera(system_prompt, user_msg, timeout, sampling, on_text)
	# Chiuso mentre generava: e' adesso che il modello si puo' liberare.
	if _chiuso and not _busy:
		_libera()
	return testo


func _genera(system_prompt: String, user_msg: String, timeout: float,
		sampling: Dictionary, on_text: Callable) -> String:
	if not _available:
		return ""

	# NobodyWho ha un solo worker: se due NPC parlano insieme la seconda
	# richiesta aspetta il suo turno invece di essere buttata via.
	var queued := 0.0
	while _busy and queued < timeout:
		await get_tree().process_frame
		queued += get_process_delta_time()
	if _busy:
		last_error = "timeout in coda sul worker locale"
		return ""
	_busy = true

	# Seed nuovo a ogni richiesta: e' cio' che rende diverse due risposte alla
	# stessa domanda, e cio' che da' un senso a un secondo tentativo quando il
	# primo esce nel formato sbagliato.
	_apply_sampler(
		float(sampling.get("temperature", OraculusData.TEMPERATURE)),
		float(sampling.get("top_p", OraculusData.TOP_P)),
		int(sampling.get("top_k", OraculusData.TOP_K)),
		int(sampling.get("seed", _new_seed())))

	# Prima il system prompt, poi il reset: reset_context() ricostruisce il
	# contesto a partire dal system prompt corrente, quindi l'ordine inverso
	# lascerebbe in memoria la persona dell'NPC precedente.
	_set_first(_chat, ["system_prompt"], system_prompt)
	_call_first(_chat, ["reset_context", "reset_chat", "reset"])

	# Tetto ai token generati. inference.py passava max_tokens a llama_cpp;
	# NobodyWho non ha un'opzione equivalente, quindi il limite si applica in
	# streaming: response_updated emette un token per evento, li contiamo e
	# fermiamo il worker al budget. Senza, il modello tira dritto fino all'EOS
	# — misurato: 4702 caratteri in 11,7 s, di cui pulisci() ne tiene 240.
	# Con il tetto la stessa richiesta chiude in 1,5 s.
	var budget: int = int(sampling.get("max_tokens", OraculusData.MAX_TOKENS))
	var box := {"done": false, "text": "", "token": 0, "troncata": false}

	var on_updated := func(frammento: String) -> void:
		box["token"] = int(box["token"]) + 1
		box["text"] = String(box["text"]) + frammento
		if on_text.is_valid():
			on_text.call(String(box["text"]))
		if budget > 0 and int(box["token"]) >= budget and not bool(box["troncata"]):
			box["troncata"] = true
			_call_first(_chat, ["stop_generation", "stop"])

	var on_finished := func(response: String) -> void:
		# Quando fermiamo noi, il testo buono e' quello accumulato: la
		# risposta finale dell'addon a generazione interrotta puo' essere
		# vuota o parziale.
		if not bool(box["troncata"]):
			box["text"] = response
		box["done"] = true

	var streaming := _chat.has_signal("response_updated")
	if streaming:
		_chat.connect("response_updated", on_updated)
	_chat.connect("response_finished", on_finished, CONNECT_ONE_SHOT)

	# v11 ha rinominato say() in ask(); say() esiste ancora ma avvisa che
	# sparira'. Proviamo il nome nuovo per primo.
	var ask_method := ""
	for candidate in ["ask", "say"]:
		if _chat.has_method(candidate):
			ask_method = candidate
			break
	if ask_method.is_empty():
		if streaming and _chat.is_connected("response_updated", on_updated):
			_chat.disconnect("response_updated", on_updated)
		_chat.disconnect("response_finished", on_finished)
		_busy = false
		last_error = "nessun metodo di richiesta (ask/say) su " + CLASS_CHAT
		return ""
	_chat.call(ask_method, user_msg)

	# Si aspetta response_finished anche quando siamo stati noi a fermare il
	# worker: e' il modo di "drenare" il segnale. Se lo lasciassimo pendente,
	# arriverebbe durante la richiesta successiva e la chiuderebbe all'istante
	# con il testo sbagliato (misurato: 14 ms e la risposta di prima).
	var elapsed := 0.0
	var scadenza := timeout
	while not bool(box["done"]) and elapsed < scadenza:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if bool(box["troncata"]) and scadenza == timeout:
			# Da qui in poi aspettiamo solo che il worker si fermi, non che
			# finisca di scrivere: bastano pochi decimi.
			scadenza = minf(timeout, elapsed + STOP_GRACE)

	if streaming and _chat.is_connected("response_updated", on_updated):
		_chat.disconnect("response_updated", on_updated)

	if not bool(box["done"]):
		if _chat.is_connected("response_finished", on_finished):
			_chat.disconnect("response_finished", on_finished)
		_call_first(_chat, ["stop_generation", "stop"])
		_busy = false
		# Se il taglio era nostro il testo raccolto e' valido: l'attesa scaduta
		# riguarda solo la conferma dell'addon, non la risposta.
		if bool(box["troncata"]):
			return String(box["text"]).strip_edges()
		last_error = "timeout generazione locale (%.0fs)" % timeout
		push_warning("[Oraculus/locale] " + last_error)
		return ""

	_busy = false
	return String(box["text"]).strip_edges()


## Seed positivo a 31 bit: randi() copre tutto l'intervallo con segno e un
## valore negativo l'addon lo rifiuterebbe.
func _new_seed() -> int:
	return randi() & 0x7fffffff


# --- percorso del modello -------------------------------------------------

func _resolve_model_path() -> String:
	var env_path := OS.get_environment(ENV_MODEL_PATH)
	if not env_path.is_empty() and FileAccess.file_exists(env_path):
		return env_path

	var file_name := OraculusData.MODEL_PATH.get_file()

	# 1. copia gia' estratta in user://
	var user_path := ProjectSettings.globalize_path("user://models/" + file_name)
	if FileAccess.file_exists(user_path):
		return user_path

	# 2. file vero accanto all'eseguibile o nella cartella di progetto
	for candidate in [
		OS.get_executable_path().get_base_dir().path_join(OraculusData.MODEL_PATH),
		ProjectSettings.globalize_path("res://").path_join(OraculusData.MODEL_PATH),
	]:
		if FileAccess.file_exists(candidate):
			return candidate

	# 3. dentro il .pck: va estratto, llama.cpp non legge dal pacchetto
	var packed := "res://" + OraculusData.MODEL_PATH
	if FileAccess.file_exists(packed):
		if _extract_to_user(packed, user_path):
			return user_path

	return ""


func _extract_to_user(from: String, to_abs: String) -> bool:
	print("[Oraculus/locale] estraggo il modello in user:// (una volta sola)...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://models"))
	var src := FileAccess.open(from, FileAccess.READ)
	if src == null:
		last_error = "impossibile leggere " + from
		return false
	# .part evita di lasciare un file troncato se il gioco viene chiuso a meta'.
	var tmp := to_abs + ".part"
	var dst := FileAccess.open(tmp, FileAccess.WRITE)
	if dst == null:
		last_error = "impossibile scrivere " + tmp
		return false
	while not src.eof_reached():
		dst.store_buffer(src.get_buffer(COPY_CHUNK))
	dst.close()
	src.close()
	if DirAccess.rename_absolute(tmp, to_abs) != OK:
		last_error = "impossibile rinominare " + tmp
		return false
	print("[Oraculus/locale] modello estratto: ", to_abs)
	return true


# --- riflessione ----------------------------------------------------------

func _set_first(obj: Object, names: Array, value: Variant) -> bool:
	if obj == null:
		return false
	var owned := {}
	for p in obj.get_property_list():
		owned[p["name"]] = true
	for n in names:
		if owned.has(n):
			obj.set(n, value)
			return true
	return false


func _call_first(obj: Object, names: Array) -> bool:
	if obj == null:
		return false
	for n in names:
		if obj.has_method(n):
			obj.call(n)
			return true
	return false
