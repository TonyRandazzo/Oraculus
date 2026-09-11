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


## Ritorna il contenuto testuale della risposta, o "" in caso di errore.
func chat_completion(messages: Array, max_tokens: int, temperature: float, top_p: float) -> String:
	var payload := {
		"model": OraculusData.HF_MODEL,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"top_p": top_p,
	}
	var res: Variant = await _post_json(base_url + CHAT_PATH, JSON.stringify(payload), request_timeout)
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
