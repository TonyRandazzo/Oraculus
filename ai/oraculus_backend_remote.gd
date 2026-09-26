# ============================================================================
# Ramo di inferenza remota: sostituisce InferenceClient.chat_completion().
#
# InferenceClient e' solo un wrapper REST, quindi un HTTPRequest verso un
# endpoint chat/completions fa esattamente la stessa cosa. Puntiamo al proxy
# su Render invece che direttamente a Hugging Face: il token HF resta sul
# server e non finisce nel .pck, da cui sarebbe estraibile.
#
# Su Web le GDExtension native non esistono e HTTPRequest e' soggetto a CORS,
# quindi la richiesta passa da fetch() via JavaScriptBridge, come faceva il
# vecchio AIServerManager.
#
# chat_completion_stream() chiede la risposta in Server-Sent Events e la
# consegna a pezzi mentre arriva: HTTPRequest restituisce il corpo solo a
# richiesta finita, quindi su desktop si usa HTTPClient, su Web fetch() con
# un ReadableStream.
# ============================================================================
class_name OraculusRemoteBackend
extends Node

const DEFAULT_BASE_URL := "https://oraculus-ai-api.onrender.com"
const CHAT_PATH := "/v1/chat/completions"
const HEALTH_PATH := "/health"
const ENV_OVERRIDE := "ORACULUS_API_URL"

var base_url: String = DEFAULT_BASE_URL
var request_timeout: float = 90.0
var last_error: String = ""

var _available := false
var _web_seq := 0
## Chiuso da OraculusEngine quando il locale ha vinto la gara di setup(): da
## li' in poi nessuna richiesta parte piu' verso il proxy.
var _chiuso := false


func _ready() -> void:
	var override := OS.get_environment(ENV_OVERRIDE)
	if not override.is_empty():
		base_url = override.rstrip("/")


func is_available() -> bool:
	return _available


## Verifica che il proxy risponda E che abbia un backend di inferenza. Non
## basta "status": "ok" (che dice solo che il processo HTTP e' vivo): se il
## proxy non e' riuscito a caricare il modello, ogni POST su chat/completions
## torna 503 e il gioco vede solo risposte di fallback, senza sapere perche'.
## Il motivo vero arriva in "last_error" del proxy e lo ripetiamo qui.
func probe() -> bool:
	var res: Variant = await _get_json(base_url + HEALTH_PATH, 6.0)
	_available = false
	if typeof(res) != TYPE_DICTIONARY:
		last_error = "healthcheck remoto fallito"
		return false

	var body: Dictionary = res
	if String(body.get("status", "")) != "ok":
		last_error = "healthcheck remoto fallito"
		return false

	if not bool(body.get("llama", false)):
		last_error = "il proxy risponde ma non ha inferenza: " + String(body.get("last_error", "motivo non riportato"))
		push_warning("[Oraculus/remoto] " + last_error)
		return false

	_available = true
	return true


## Marca il backend come utilizzabile senza aspettare il probe (usato quando
## non c'e' alternativa locale: tanto vale provare la richiesta vera).
func assume_available() -> void:
	_available = true


## La prova della gara di OraculusEngine.setup(): una generazione vera e
## minima, non /health. /health dice solo che il processo e' vivo, e con il
## credito HF finito risponde "ok" lo stesso mentre ogni generazione torna
## 500 (402 dal provider). Un errore qualsiasi (402, 404, 500, rete, timeout)
## vuol dire "non ha risposto".
func verifica(timeout: float) -> bool:
	if _chiuso:
		return false
	var payload := {
		"model": OraculusData.HF_MODEL,
		"messages": [{"role": "user", "content": "Hi"}],
		"max_tokens": 4,
	}
	var res: Variant = await _post_json(base_url + CHAT_PATH, JSON.stringify(payload), timeout)
	if _chiuso:
		return false
	if typeof(res) != TYPE_DICTIONARY:
		last_error = "risposta remota non interpretabile"
		return false
	var data: Dictionary = res
	if data.has("error"):
		last_error = String(data["error"])
		return false
	if (data.get("choices", []) as Array).is_empty():
		last_error = "nessuna choice nella risposta remota"
		return false
	_available = true
	return true


## Chiude il ramo remoto: il locale ha risposto prima nella gara. Le
## richieste dopo questa tornano "" subito, senza toccare la rete.
func chiudi() -> void:
	_chiuso = true
	_available = false


## Ritorna il contenuto testuale della risposta, o "" in caso di errore.
func chat_completion(messages: Array, max_tokens: int, temperature: float, top_p: float) -> String:
	if _chiuso:
		return ""
	var payload := {
		"model": OraculusData.HF_MODEL,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"top_p": top_p,
	}
	var res: Variant = await _post_json(base_url + CHAT_PATH, JSON.stringify(payload), request_timeout)
	return _contenuto(res)


## Come chat_completion(), ma chiede la risposta in streaming e chiama
## on_text(testo_accumulato) a ogni frammento che arriva: il giocatore legge
## le prime parole dopo il primo token invece che dopo l'ultimo. Ritorna il
## testo completo, o "" in caso di errore.
##
## Un proxy che non conosce ancora "stream" (deploy precedente) risponde con
## il JSON di sempre: lo leggiamo come prima, e on_text non viene chiamata.
func chat_completion_stream(messages: Array, max_tokens: int, temperature: float,
		top_p: float, on_text: Callable) -> String:
	if _chiuso:
		return ""
	var payload := {
		"model": OraculusData.HF_MODEL,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"top_p": top_p,
		"stream": true,
	}
	var flusso := FlussoSSE.new()
	var box := {"sse": false, "corpo": PackedByteArray()}
	var on_chunk := func(code: int, content_type: String, dati: PackedByteArray) -> void:
		if code == 200 and content_type.contains("text/event-stream"):
			box["sse"] = true
			if flusso.aggiungi(dati) and on_text.is_valid():
				on_text.call(flusso.testo)
		else:
			box["corpo"] = box["corpo"] + dati

	var esito: Dictionary = await _post_stream(base_url + CHAT_PATH, JSON.stringify(payload),
		request_timeout, on_chunk)

	if bool(box["sse"]):
		# Errore o timeout a meta' flusso: il testo arrivato fin li' e' buono,
		# e l'NPC lo sta gia' mostrando. pulisci() lo chiudera' a una frase.
		var problema := flusso.errore if not flusso.errore.is_empty() else String(esito.get("error", ""))
		if not problema.is_empty():
			last_error = problema
			push_warning("[Oraculus/remoto] flusso interrotto: " + problema)
		return flusso.testo.strip_edges()

	var corpo: PackedByteArray = box["corpo"]
	if int(esito.get("code", 0)) == 0 and corpo.is_empty():
		last_error = String(esito.get("error", "timeout o connessione persa"))
		push_warning("[Oraculus/remoto] " + last_error)
		return ""
	return _contenuto(_decode([OK, int(esito.get("code", 0)), PackedStringArray(), corpo]))


func _contenuto(res: Variant) -> String:
	if typeof(res) != TYPE_DICTIONARY:
		last_error = "risposta remota non interpretabile"
		return ""
	var data: Dictionary = res
	if data.has("error"):
		last_error = String(data["error"])
		push_warning("[Oraculus/remoto] " + last_error)
		return ""
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		last_error = "nessuna choice nella risposta remota"
		return ""
	var first: Dictionary = choices[0]
	var msg: Dictionary = first.get("message", {})
	return String(msg.get("content", "")).strip_edges()


# --- trasporto ------------------------------------------------------------

func _get_json(url: String, timeout: float) -> Variant:
	if OS.get_name() == "Web":
		return await _fetch_web(url, "", timeout, "GET")
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return {"error": "richiesta non avviata"}
	var result: Array = await http.request_completed
	http.queue_free()
	return _decode(result)


func _post_json(url: String, body: String, timeout: float) -> Variant:
	if OS.get_name() == "Web":
		return await _fetch_web(url, body, timeout, "POST")
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var headers := ["Content-Type: application/json"]
	if http.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		return {"error": "richiesta non avviata"}
	var result: Array = await http.request_completed
	http.queue_free()
	return _decode(result)


func _decode(result: Array) -> Variant:
	var response_code: int = result[1]
	var raw: PackedByteArray = result[3]
	if response_code == 0:
		return {"error": "timeout o connessione persa"}
	var text := raw.get_string_from_utf8()
	if response_code != 200:
		return {"error": "HTTP %d: %s" % [response_code, text.substr(0, 600)]}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"error": "JSON non valido: " + text.substr(0, 200)}
	return json.get_data()


func _fetch_web(url: String, body: String, timeout: float, method: String) -> Variant:
	var safe_body := body.replace("\\", "\\\\").replace("`", "\\`").replace("$", "\\$")
	JavaScriptBridge.eval("window._oraculus_done = false; window._oraculus_result = null;")

	var init := "{method: 'GET'}"
	if method == "POST":
		init = "{method: 'POST', headers: {'Content-Type': 'application/json'}, body: `%s`}" % safe_body

	JavaScriptBridge.eval("""
		(async () => {
			try {
				const r = await fetch('%s', %s);
				const t = await r.text();
				window._oraculus_result = JSON.stringify({ok: r.ok, status: r.status, body: t});
			} catch(e) {
				window._oraculus_result = JSON.stringify({ok: false, status: 0, body: String(e)});
			}
			window._oraculus_done = true;
		})();
	""" % [url, init])

	var elapsed := 0.0
	while elapsed < timeout:
		await get_tree().process_frame
		if JavaScriptBridge.eval("window._oraculus_done ? 1 : 0") == 1:
			break
		elapsed += get_process_delta_time()
	if elapsed >= timeout:
		return {"error": "timeout fetch Web (%.0fs)" % timeout}

	var outer := JSON.new()
	var raw := str(JavaScriptBridge.eval("window._oraculus_result"))
	if outer.parse(raw) != OK:
		return {"error": "involucro JSON non valido: " + raw.substr(0, 200)}
	var obj: Dictionary = outer.get_data()
	if not bool(obj.get("ok", false)):
		return {"error": "HTTP %s: %s" % [str(obj.get("status", 0)), str(obj.get("body", ""))]}
	var inner := JSON.new()
	if inner.parse(String(obj.get("body", ""))) != OK:
		return {"error": "JSON risposta non valido"}
	return inner.get_data()


# --- trasporto in streaming -----------------------------------------------

## POST che consegna il corpo a pezzi, man mano che arriva:
## on_chunk(codice_http, content_type, byte). Ritorna {code, error} a
## richiesta chiusa; error e' vuoto se il corpo e' arrivato tutto.
func _post_stream(url: String, body: String, timeout: float, on_chunk: Callable) -> Dictionary:
	if OS.get_name() == "Web":
		return await _post_stream_web(url, body, timeout, on_chunk)
	return await _post_stream_native(url, body, timeout, on_chunk)


## HTTPRequest consegna il corpo solo a richiesta finita, quindi qui si
## scende a HTTPClient e lo si interroga a ogni frame.
func _post_stream_native(url: String, body: String, timeout: float, on_chunk: Callable) -> Dictionary:
	var parti := _dividi_url(url)
	if parti.is_empty():
		return {"code": 0, "error": "URL non valido: " + url}

	var client := HTTPClient.new()
	var tls: TLSOptions = TLSOptions.client() if bool(parti["tls"]) else null
	if client.connect_to_host(String(parti["host"]), int(parti["port"]), tls) != OK:
		return {"code": 0, "error": "connessione non avviata"}
	var scadenza := Time.get_ticks_msec() + int(timeout * 1000.0)

	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		client.poll()
		if Time.get_ticks_msec() > scadenza:
			client.close()
			return {"code": 0, "error": "timeout o connessione persa"}
		await get_tree().process_frame
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		var stato := client.get_status()
		client.close()
		return {"code": 0, "error": "connessione fallita (stato %d)" % stato}

	var headers := PackedStringArray(["Content-Type: application/json", "Accept: text/event-stream"])
	if client.request(HTTPClient.METHOD_POST, String(parti["path"]), headers, body) != OK:
		client.close()
		return {"code": 0, "error": "richiesta non avviata"}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() > scadenza:
			client.close()
			return {"code": 0, "error": "timeout o connessione persa"}
		await get_tree().process_frame

	var code := client.get_response_code()
	if not client.has_response():
		client.close()
		return {"code": 0, "error": "nessuna risposta (stato %d)" % client.get_status()}

	var content_type := ""
	var intestazioni := client.get_response_headers_as_dictionary()
	for k in intestazioni:
		if String(k).to_lower() == "content-type":
			content_type = String(intestazioni[k]).to_lower()

	var errore := ""
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var pezzo := client.read_response_body_chunk()
		if not pezzo.is_empty():
			on_chunk.call(code, content_type, pezzo)
			continue
		if Time.get_ticks_msec() > scadenza:
			errore = "timeout a meta' risposta (%.0fs)" % timeout
			break
		await get_tree().process_frame
	client.close()
	return {"code": code, "error": errore}


## fetch() con ReadableStream: il JS accumula il testo decodificato in uno
## stato per richiesta, e a ogni frame GDScript si prende la parte nuova.
## Lo stato e' per richiesta (non le globali di _fetch_web) perche' due NPC
## possono parlare insieme.
func _post_stream_web(url: String, body: String, timeout: float, on_chunk: Callable) -> Dictionary:
	_web_seq += 1
	var id := _web_seq
	# JSON.stringify di una String produce un literal JS valido: niente
	# escape a mano del corpo.
	JavaScriptBridge.eval("""
		(() => {
			const reqs = window._oraculus_stream = window._oraculus_stream || {};
			const s = reqs[%d] = {status: 0, ct: '', buf: '', done: false, err: '', ctrl: new AbortController()};
			(async () => {
				try {
					const r = await fetch(%s, {
						method: 'POST',
						headers: {'Content-Type': 'application/json', 'Accept': 'text/event-stream'},
						body: %s,
						signal: s.ctrl.signal,
					});
					s.status = r.status;
					s.ct = (r.headers.get('content-type') || '').toLowerCase();
					if (r.body && r.body.getReader) {
						const reader = r.body.getReader();
						const dec = new TextDecoder();
						for (;;) {
							const {done, value} = await reader.read();
							if (done) break;
							s.buf += dec.decode(value, {stream: true});
						}
						s.buf += dec.decode();
					} else {
						s.buf += await r.text();
					}
				} catch (e) {
					s.err = String(e);
				}
				s.done = true;
			})();
		})();
	""" % [id, JSON.stringify(url), JSON.stringify(body)])

	var prendi := """
		(() => {
			const s = window._oraculus_stream[%d];
			const out = JSON.stringify({status: s.status, ct: s.ct, buf: s.buf, done: s.done, err: s.err});
			s.buf = '';
			return out;
		})()
	""" % id

	var scadenza := Time.get_ticks_msec() + int(timeout * 1000.0)
	var esito := {"code": 0, "error": ""}
	while true:
		await get_tree().process_frame
		var json := JSON.new()
		if json.parse(str(JavaScriptBridge.eval(prendi))) != OK:
			esito["error"] = "stato fetch non leggibile"
			break
		var s: Dictionary = json.get_data()
		esito["code"] = int(s.get("status", 0))
		var testo := String(s.get("buf", ""))
		if not testo.is_empty():
			on_chunk.call(int(esito["code"]), String(s.get("ct", "")), testo.to_utf8_buffer())
		if bool(s.get("done", false)):
			esito["error"] = String(s.get("err", ""))
			break
		if Time.get_ticks_msec() > scadenza:
			JavaScriptBridge.eval("window._oraculus_stream[%d].ctrl.abort();" % id)
			esito["error"] = "timeout fetch Web (%.0fs)" % timeout
			break
	JavaScriptBridge.eval("delete window._oraculus_stream[%d];" % id)
	return esito


static func _dividi_url(url: String) -> Dictionary:
	var tls := url.begins_with("https://")
	if not tls and not url.begins_with("http://"):
		return {}
	var resto := url.substr(8 if tls else 7)
	var slash := resto.find("/")
	var host := resto if slash < 0 else resto.substr(0, slash)
	var path := "/" if slash < 0 else resto.substr(slash)
	var port := 443 if tls else 80
	var due_punti := host.rfind(":")
	if due_punti > 0 and host.substr(due_punti + 1).is_valid_int():
		port = int(host.substr(due_punti + 1))
		host = host.substr(0, due_punti)
	return {"host": host, "port": port, "path": path, "tls": tls}


## Legge un flusso Server-Sent Events consegnato a pezzi arbitrari, nel
## formato di OpenAI: `data: {chunk}` con il testo in
## choices[0].delta.content, e `data: [DONE]` in fondo. I byte si tagliano
## solo sugli a capo, cosi' una lettera accentata (due byte in UTF-8) a
## cavallo di due pacchetti si decodifica intera.
class FlussoSSE:
	extends RefCounted

	var testo := ""
	var errore := ""
	var finito := false
	var _resto := PackedByteArray()

	## true se il testo e' cresciuto.
	func aggiungi(dati: PackedByteArray) -> bool:
		_resto.append_array(dati)
		var cresciuto := false
		while not finito:
			var a_capo := _resto.find(10)
			if a_capo < 0:
				break
			var riga := _resto.slice(0, a_capo).get_string_from_utf8().strip_edges()
			_resto = _resto.slice(a_capo + 1)
			if riga.begins_with("data:"):
				cresciuto = _evento(riga.substr(5).strip_edges()) or cresciuto
		return cresciuto

	func _evento(dati: String) -> bool:
		if dati == "[DONE]":
			finito = true
			return false
		var json := JSON.new()
		if json.parse(dati) != OK or typeof(json.get_data()) != TYPE_DICTIONARY:
			return false
		var ev: Dictionary = json.get_data()
		if ev.has("error"):
			errore = str(ev["error"])
			finito = true
			return false
		var choices: Array = ev.get("choices", [])
		if choices.is_empty() or typeof(choices[0]) != TYPE_DICTIONARY:
			return false
		var delta: Variant = (choices[0] as Dictionary).get("delta", {})
		if typeof(delta) != TYPE_DICTIONARY:
			return false
		var pezzo: Variant = (delta as Dictionary).get("content")
		if typeof(pezzo) != TYPE_STRING or String(pezzo).is_empty():
			return false
		testo += String(pezzo)
		return true
