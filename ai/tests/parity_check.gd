# ============================================================================
# Verifica di parita' tra ai/inference.py e ai/oraculus_logic.gd.
#
# Rilegge ai/tests/parity_cases.json (generato da tools/parity_dump.py) e
# confronta ogni risultato stringa per stringa. Per i prompt completi, che
# contengono STORY_CONTEXT, il confronto e' su lunghezza + sha256: se
# build_prompt combacia, il modello riceve lo stesso input di prima.
#
# Da riga di comando:
#   godot --headless --path . res://ai/tests/parity_check.tscn
# Esce con codice 0 se tutto combacia, 1 altrimenti.
# ============================================================================
extends Node

const CASES_PATH := "res://ai/tests/parity_cases.json"
const MAX_FAILURES_SHOWN := 12

var _passed := 0
var _failed := 0
var _failures: Array[String] = []
var _per_fn: Dictionary = {}


func _ready() -> void:
	var esito := run_all()
	# OS.has_feature("editor") e' vero anche quando si esegue il progetto con
	# un binario editor, quindi non distingue i due casi: is_editor_hint()
	# invece e' vero solo dentro l'editor.
	if not Engine.is_editor_hint():
		get_tree().quit(0 if esito else 1)


func run_all() -> bool:
	var file := FileAccess.open(CASES_PATH, FileAccess.READ)
	if file == null:
		push_error("[Parita'] file dei casi assente: " + CASES_PATH
			+ " — generalo con: python3 tools/parity_dump.py")
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[Parita'] JSON non valido: " + json.get_error_message())
		return false
	var payload: Dictionary = json.get_data()

	print("=".repeat(70))
	print("  VERIFICA DI PARITA'  inference.py  ->  oraculus_logic.gd")
	print("=".repeat(70))

	_check_constants(payload.get("constants", {}))

	for caso in payload.get("cases", []):
		_check_case(caso)

	print("")
	for fn in _per_fn:
		var r: Dictionary = _per_fn[fn]
		var marca := "ok  " if int(r["ko"]) == 0 else "FAIL"
		print("  [%s] %-26s %4d/%4d" % [marca, fn, int(r["ok"]), int(r["ok"]) + int(r["ko"])])

	print("")
	if _failed == 0:
		print("  TUTTO COMBACIA: %d confronti superati." % _passed)
	else:
		print("  %d confronti falliti su %d." % [_failed, _passed + _failed])
		print("")
		for i in mini(_failures.size(), MAX_FAILURES_SHOWN):
			print(_failures[i])
		if _failures.size() > MAX_FAILURES_SHOWN:
			print("  ... e altri %d." % (_failures.size() - MAX_FAILURES_SHOWN))
	print("=".repeat(70))
	return _failed == 0


# --- costanti -------------------------------------------------------------

func _check_constants(c: Dictionary) -> void:
	if c.is_empty():
		return
	var story: Dictionary = c.get("STORY_CONTEXT", {})
	_expect("STORY_CONTEXT.len", str(int(story.get("len", -1))), str(OraculusData.STORY_CONTEXT.length()))
	_expect("STORY_CONTEXT.sha256", String(story.get("sha256", "")), OraculusData.STORY_CONTEXT.sha256_text())

	_expect("ARMY_NAME", String(c.get("ARMY_NAME", "")), OraculusData.ARMY_NAME)
	_expect("ARMY_NAME_EN", String(c.get("ARMY_NAME_EN", "")), OraculusData.ARMY_NAME_EN)
	_expect("MODEL_FORMAT", String(c.get("MODEL_FORMAT", "")), OraculusData.MODEL_FORMAT)
	_expect("MAX_TOKENS", str(int(c.get("MAX_TOKENS", -1))), str(OraculusData.MAX_TOKENS))

	# L'ordine delle chiavi decide chi vince in classify_intent e nel
	# tie-break di detect_language: va confrontato, non solo il contenuto.
	_expect("ordine INTENT_KW", ",".join(_as_strings(c.get("intent_order", []))),
		",".join(_as_strings(OraculusData.INTENT_KW.keys())))
	_expect("ordine LANG_SIGNATURES", ",".join(_as_strings(c.get("lang_order", []))),
		",".join(_as_strings(OraculusData.LANG_SIGNATURES.keys())))
	_expect("ordine NPC_DATA", ",".join(_as_strings(c.get("npc_order", []))),
		",".join(_as_strings(OraculusData.NPC_DATA.keys())))

	var pers: Dictionary = c.get("npc_personalita_sha", {})
	for npc in pers:
		var atteso := String(pers[npc])
		var dato := String(OraculusData.NPC_DATA.get(npc, {}).get("personalita", "")).sha256_text()
		_expect("personalita[%s]" % npc, atteso, dato)

	var seg: Dictionary = c.get("npc_info_segrete_sha", {})
	for npc in seg:
		var atteso := String(seg[npc])
		var dato := String(OraculusData.NPC_DATA.get(npc, {}).get("info_segrete", "")).sha256_text()
		_expect("info_segrete[%s]" % npc, atteso, dato)

	var fb: Dictionary = c.get("fallback", {})
	for tier in fb:
		_expect("FALLBACK[%s]" % tier, "|".join(_as_strings(fb[tier])),
			"|".join(_as_strings(OraculusData.FALLBACK.get(tier, []))))

	var rf: Dictionary = c.get("riddle_fallbacks", {})
	for lang in rf:
		var attesi := PackedStringArray()
		for r in rf[lang]:
			attesi.append(String(r["answer"]) + "\u0001" + String(r["riddle"]))
		var dati := PackedStringArray()
		for r in OraculusData.RIDDLE_FALLBACKS.get(lang, []):
			dati.append(String(r["answer"]) + "\u0001" + String(r["riddle"]))
		_expect("RIDDLE_FALLBACKS[%s]" % lang, "|".join(attesi), "|".join(dati))

	_expect("DEFAULT_RIDDLE_THEMES", "|".join(_as_strings(c.get("default_riddle_themes", []))),
		"|".join(_as_strings(OraculusData.DEFAULT_RIDDLE_THEMES)))
	_expect("MALAKAI_TRIGGERS", "|".join(_as_strings(c.get("malakai_triggers", []))),
		"|".join(_as_strings(OraculusData.MALAKAI_TRIGGERS)))


# --- casi -----------------------------------------------------------------

func _check_case(caso: Dictionary) -> void:
	var fn := String(caso["fn"])
	var a: Dictionary = caso["args"]
	var ottenuto: Variant = null

	match fn:
		"detect_language":
			ottenuto = OraculusLogic.detect_language(String(a["text"]))
		"classify_intent":
			ottenuto = OraculusLogic.classify_intent(String(a["text"]))
		"check_malakai_unlock":
			ottenuto = OraculusLogic.check_malakai_unlock(String(a["text"]))
		"hostility_tier":
			ottenuto = OraculusLogic.hostility_tier(int(a["hostility"]), int(a["friendship"]))
		"adjust_hostility":
			ottenuto = OraculusLogic.adjust_hostility(String(a["intent"]), int(a["hostility"]), int(a["friendship"]))
		"pulisci":
			ottenuto = OraculusLogic.pulisci(String(a["testo"]), String(a["npc_name"]))
		"enforce_army_name":
			ottenuto = OraculusLogic.enforce_army_name(String(a["text"]), String(a["language"]))
		"format_secret_policy":
			ottenuto = OraculusLogic.format_secret_policy(
				OraculusData.NPC_DATA[String(a["npc_name"])], int(a["hostility"]), int(a["friendship"]))
		"format_dynamic_secrets":
			ottenuto = OraculusLogic.format_dynamic_secrets(
				String(a["npc_name"]), int(a["friendship"]), a["context_vars"])
		"build_prompt":
			ottenuto = OraculusLogic.build_prompt(String(a["player_input"]), String(a["npc_name"]),
				int(a["hostility"]), int(a["friendship"]), String(a["language"]),
				a["history"], OraculusData.NPC_DATA[String(a["npc_name"])], a["context_vars"])
		"build_system_msg":
			ottenuto = OraculusLogic.build_system_msg(String(a["npc_name"]), int(a["hostility"]),
				int(a["friendship"]), String(a["language"]),
				OraculusData.NPC_DATA[String(a["npc_name"])], a["context_vars"])
		"build_prompt_unknown":
			ottenuto = OraculusLogic.build_prompt(String(a["player_input"]), String(a["npc_name"]),
				int(a["hostility"]), int(a["friendship"]), String(a["language"]),
				a["history"], _npc_data_fallback(String(a["npc_name"])), a["context_vars"])
		"build_system_msg_unknown":
			ottenuto = OraculusLogic.build_system_msg(String(a["npc_name"]), int(a["hostility"]),
				int(a["friendship"]), String(a["language"]),
				_npc_data_fallback(String(a["npc_name"])), a["context_vars"])
		"build_riddle_system":
			ottenuto = OraculusLogic.build_riddle_system(String(a["theme"]), String(a["language"]))
		"build_riddle_user":
			ottenuto = OraculusLogic.build_riddle_user(String(a["language"]), String(a["theme"]),
				String(a["session_id"]))
		"parse_riddle_response":
			var res: Variant = OraculusLogic.parse_riddle_response(String(a["raw"]))
			ottenuto = "" if res == null else String(res["answer"]) + "\u0001" + String(res["riddle"])
		_:
			_fail(fn, "funzione non gestita dal test", "", "")
			return

	var etichetta := "%s%s" % [fn, JSON.stringify(a).substr(0, 90)]

	if caso.has("expected_sha256"):
		var testo := String(ottenuto)
		var atteso_len := int(caso["expected_len"])
		if testo.length() != atteso_len:
			_fail(fn, etichetta, "lunghezza %d" % atteso_len, "lunghezza %d" % testo.length())
			return
		var atteso_sha := String(caso["expected_sha256"])
		var sha := testo.sha256_text()
		if sha != atteso_sha:
			var dettaglio := ""
			if caso.has("expected"):
				dettaglio = _primo_scostamento(String(caso["expected"]), testo)
			_fail(fn, etichetta, atteso_sha + dettaglio, sha)
			return
		_ok(fn)
		return

	var atteso: Variant = caso["expected"]
	if atteso is bool or ottenuto is bool:
		if bool(atteso) != bool(ottenuto):
			_fail(fn, etichetta, str(atteso), str(ottenuto))
			return
		_ok(fn)
		return
	if atteso is float or atteso is int:
		if int(atteso) != int(ottenuto):
			_fail(fn, etichetta, str(int(atteso)), str(ottenuto))
			return
		_ok(fn)
		return

	if String(atteso) != String(ottenuto):
		_fail(fn, etichetta, String(atteso), String(ottenuto))
		return
	_ok(fn)


## Per un NPC fuori da NPC_DATA, LlamaCppWrapper passava questo dizionario:
## e' lo stesso che costruisce OraculusEngine._npc_data().
func _npc_data_fallback(npc_name: String) -> Dictionary:
	return {"personalita": "You are %s, an ancient spirit." % npc_name}


# --- resoconto ------------------------------------------------------------

func _ok(fn: String) -> void:
	_passed += 1
	var r: Dictionary = _per_fn.get(fn, {"ok": 0, "ko": 0})
	r["ok"] = int(r["ok"]) + 1
	_per_fn[fn] = r


func _fail(fn: String, etichetta: String, atteso: String, ottenuto: String) -> void:
	_failed += 1
	var r: Dictionary = _per_fn.get(fn, {"ok": 0, "ko": 0})
	r["ko"] = int(r["ko"]) + 1
	_per_fn[fn] = r
	_failures.append("  --- %s\n      atteso  : %s\n      ottenuto: %s"
		% [etichetta, _abbrevia(atteso), _abbrevia(ottenuto)])


func _expect(nome: String, atteso: String, ottenuto: String) -> void:
	if atteso == ottenuto:
		_ok("costanti")
	else:
		_fail("costanti", nome, atteso, ottenuto)


func _abbrevia(s: String) -> String:
	var one_line := s.replace("\n", "\\n").replace("\t", "\\t")
	if one_line.length() <= 220:
		return one_line
	return one_line.substr(0, 220) + " …(%d caratteri)" % s.length()


## Indica dove le due stringhe divergono: e' quello che serve davvero per
## capire quale pezzo di prompt e' stato tradotto male.
func _primo_scostamento(atteso: String, ottenuto: String) -> String:
	var n: int = mini(atteso.length(), ottenuto.length())
	for i in n:
		if atteso[i] != ottenuto[i]:
			var da: int = maxi(0, i - 40)
			return ("\n      prima differenza all'indice %d\n"
				+ "        atteso  : …%s\n"
				+ "        ottenuto: …%s") % [i,
					atteso.substr(da, 80).replace("\n", "\\n"),
					ottenuto.substr(da, 80).replace("\n", "\\n")]
	return "\n      differenza solo in lunghezza (%d vs %d)" % [atteso.length(), ottenuto.length()]


func _as_strings(a: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	for x in a:
		out.append(String(x))
	return out
