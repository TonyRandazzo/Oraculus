# ============================================================================
# Porting 1:1 delle funzioni pure di ai/inference.py.
#
# Ogni funzione qui e' senza stato e senza dipendenze: dato lo stesso input
# restituisce la stessa stringa del corrispettivo Python, byte per byte.
# La parita' e' verificabile con res://ai/tests/parity_check.tscn (vedi
# tools/parity_dump.py).
#
# Note di traduzione, dove Python e GDScript non coincidono da soli:
#  - le regex usano PCRE2: i flag inline sostituiscono quelli di Python
#    (re.DOTALL|re.IGNORECASE -> "(?si)", re.MULTILINE -> "(?m)") e il verbo
#    (*UCP) riporta \d \w \s a essere unicode-aware come in Python;
#  - RegEx.sub() sostituisce solo la prima occorrenza se non si passa
#    all = true, mentre re.sub() sostituisce tutto: qui passiamo sempre true;
#  - la divisione intera di Python arrotonda verso il basso, quella di
#    GDScript verso lo zero: usiamo floori() sul float.
# ============================================================================
class_name OraculusLogic
extends RefCounted

# --- regex compilate una volta sola --------------------------------------

static var _re_tokens: RegEx = null
static var _re_parens: RegEx = null
static var _re_num_ml: RegEx = null
static var _re_bullet_ml: RegEx = null
static var _re_num_prefix: RegEx = null
static var _re_bullet_prefix: RegEx = null
static var _re_riddle: RegEx = null
static var _re_answer: RegEx = null


static func _compile(pattern: String) -> RegEx:
	# (*UCP) rende \d \w \s unicode-aware come in Python. Se la build di
	# PCRE2 dentro Godot non lo supporta, ripieghiamo sul pattern nudo:
	# cambia solo il comportamento su caratteri non ASCII.
	var re := RegEx.new()
	if re.compile("(*UCP)" + pattern) == OK:
		return re
	re = RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[OraculusLogic] regex non compilabile: " + pattern)
	return re


static func _init_regex() -> void:
	if _re_tokens != null:
		return
	_re_tokens = _compile("<\\|[^>]+\\|>")
	_re_parens = _compile("\\([^)]{8,}\\)")
	_re_num_ml = _compile("(?m)^\\d+\\.")
	_re_bullet_ml = _compile("(?m)^[•\\-*]")
	_re_num_prefix = _compile("^\\d+\\.\\s*")
	_re_bullet_prefix = _compile("^[•\\-*]\\s*")
	_re_riddle = _compile("(?si)RIDDLE:\\s*(.+?)(?=ANSWER:|$)")
	_re_answer = _compile("(?i)ANSWER:\\s*(\\w+)")


# --- rilevamento lingua --------------------------------------------------

## Equivalente di detect_language(). Python usa max(scores, key=scores.get),
## che restituisce il PRIMO massimo trovato: il confronto qui e' quindi
## strettamente > (con >= cambierebbe il tie-break tra italiano e inglese).
static func detect_language(text: String) -> String:
	var tl := text.to_lower()
	var best := ""
	var best_score := -1
	for lang in OraculusData.LANG_SIGNATURES:
		var score := 0
		for w in OraculusData.LANG_SIGNATURES[lang]:
			if tl.contains(w):
				score += 1
		if score > best_score:
			best_score = score
			best = lang
	return best if best_score > 0 else "inglese"


# --- ostilita' -----------------------------------------------------------

static func hostility_tier(hostility: int, friendship: int) -> String:
	var eff: int = maxi(0, hostility - floori(friendship / 2.0))
	if eff >= 70:
		return "high"
	if eff >= 40:
		return "mid"
	return "low"


static func adjust_hostility(intent: String, hostility: int, friendship: int) -> int:
	if intent == "violenza":
		return mini(100, hostility + 15)
	elif intent == "minaccia":
		return mini(100, hostility + 10)
	elif intent == "vendetta":
		return mini(100, hostility + 8)
	elif intent == "bugia":
		return mini(100, hostility + 5)
	elif intent == "cultura" and hostility > 30:
		return maxi(0, hostility - 8)
	elif intent == "cultura" and hostility <= 30:
		return maxi(0, hostility - 12)
	elif intent == "scusa":
		return maxi(0, hostility - 6)
	elif intent == "aiuto":
		return maxi(0, hostility - 4)
	elif intent == "umorismo" and friendship > 10:
		return maxi(0, hostility - 5)
	elif intent == "saluto" and hostility > 50:
		return mini(100, hostility + 2)
	elif intent == "noble" and hostility > 60:
		return mini(100, hostility + 5)
	elif intent == "noble" and hostility <= 60:
		return maxi(0, hostility - 3)
	elif intent == "esplorazione":
		return maxi(0, hostility - 2)
	elif intent == "rigon" and hostility > 30:
		return maxi(0, hostility - 10)
	elif intent == "kalessi" and hostility > 30:
		return maxi(0, hostility - 8)
	elif intent == "malakai" and hostility > 50:
		return maxi(0, hostility - 5)
	else:
		return hostility


# --- intent --------------------------------------------------------------

## Restituisce il PRIMO intent con almeno una keyword presente: dipende
## dall'ordine di inserimento di INTENT_KW, che oraculus_data.gd preserva.
static func classify_intent(text: String) -> String:
	var tl := text.to_lower()
	for intent in OraculusData.INTENT_KW:
		for kw in OraculusData.INTENT_KW[intent]:
			if tl.contains(kw):
				return intent
	return "generico"


static func check_malakai_unlock(text: String) -> bool:
	var tl := text.to_lower()
	for t in OraculusData.MALAKAI_TRIGGERS:
		if tl.contains(t):
			return true
	return false


# --- nome dell'esercito --------------------------------------------------

## re.sub(re.escape(wrong), army, text, IGNORECASE) equivale a replacen(),
## che sostituisce tutte le occorrenze ignorando le maiuscole.
static func enforce_army_name(text: String, language: String) -> String:
	var army_correct := OraculusData.ARMY_NAME if language == "italiano" else OraculusData.ARMY_NAME_EN
	var result := text
	for wrong in OraculusData.WRONG_ARMY_NAMES:
		result = result.replacen(wrong, army_correct)
	return result


# --- pulizia dell'output del modello ------------------------------------

static func pulisci(testo_in: String, npc_name: String) -> String:
	_init_regex()
	var testo := testo_in

	var prefixes: Array = [npc_name + ":", npc_name + " :"]
	prefixes.append_array(OraculusData.CLEAN_PREFIXES_STATIC)
	for prefix in prefixes:
		var p := String(prefix)
		if testo.to_lower().begins_with(p.to_lower()):
			testo = testo.substr(p.length()).strip_edges()

	testo = _re_tokens.sub(testo, "", true)
	testo = _re_parens.sub(testo, "", true).strip_edges()

	if _re_num_ml.search(testo) != null or _re_bullet_ml.search(testo) != null:
		var clean_lines: Array[String] = []
		for line in testo.split("\n"):
			var l := _re_num_prefix.sub(line.strip_edges(), "", true)
			l = _re_bullet_prefix.sub(l.strip_edges(), "", true)
			if l != "":
				clean_lines.append(l)

		if clean_lines.size() > 1:
			var items := clean_lines.slice(0, 3)
			if items.size() == 1:
				testo = items[0]
			elif items.size() == 2:
				testo = "%s and %s" % [items[0], items[1]]
			else:
				testo = "%s, %s, and %s" % [items[0], items[1], items[2]]
		else:
			testo = clean_lines[0] if not clean_lines.is_empty() else testo

	var pulite := PackedStringArray()
	for riga in testo.split("\n"):
		var r := riga.strip_edges()
		if r.is_empty():
			continue
		var rl := r.to_lower()
		var scarta := false
		for b in OraculusData.BAD_MARKERS:
			if rl.contains(String(b).to_lower()):
				scarta = true
				break
		if scarta:
			continue
		pulite.append(r)
		if pulite.size() >= 2:
			break

	var risultato := " ".join(pulite).strip_edges()

	if risultato.length() > 240:
		var last_period := risultato.substr(0, 240).rfind(".")
		if last_period > 80:
			risultato = risultato.substr(0, last_period + 1)

	if not risultato.is_empty() and not [".", "!", "?"].has(risultato.right(1)):
		var last_punct: int = maxi(maxi(risultato.rfind("."), risultato.rfind("!")), risultato.rfind("?"))
		if last_punct > floori(risultato.length() / 2.0):
			risultato = risultato.substr(0, last_punct + 1)
		else:
			risultato += "."

	return risultato if not risultato.is_empty() else "..."


# --- politiche di divulgazione ------------------------------------------

## Regola di divulgazione dei segreti: rivela / accenna / nega.
static func format_secret_policy(npc_data: Dictionary, hostility: int, friendship: int) -> String:
	var secrets := String(npc_data.get("info_segrete", "")).strip_edges()
	if secrets.is_empty():
		return ""
	var stance := ""
	if friendship > 60 or hostility < 20:
		stance = ("The player has earned it. You MAY reveal what you know, in character, "
			+ "as a secret shared with someone you trust, never as a game hint.")
	elif hostility < 40:
		stance = ("The player has not earned it yet. You may HINT at what you know, obliquely, "
			+ "but you must NOT reveal it fully.")
	else:
		stance = ("The player has not earned it. You REFUSE to share what you know. "
			+ "Deflect, change the subject, or tell him to prove himself first.")
	return "\n\nWHAT YOU SECRETLY KNOW:\n" + secrets + "\nDISCLOSURE: " + stance


## Inietta segreti dinamici nel prompt in base al contesto e all'amicizia.
static func format_dynamic_secrets(npc_name: String, friendship: int, context_vars: Variant) -> String:
	if context_vars == null or typeof(context_vars) != TYPE_DICTIONARY:
		return ""
	var cv: Dictionary = context_vars
	if cv.is_empty():
		return ""
	var lines := PackedStringArray()
	var answer := String(cv.get("entrance_riddle_answer", ""))
	var threshold := float(cv.get("entrance_riddle_reveal_threshold", 60))
	if not answer.is_empty() and npc_name == "Levias":
		if float(friendship) >= threshold:
			lines.append("PERSONAL KNOWLEDGE: You know the answer to the riddle guarding the entrance door "
				+ "is '" + answer + "'. The player has earned enough of your trust. "
				+ "If they ask you directly about the door or the riddle, you may reveal it — "
				+ "but remain in character: speak as a guardian sharing a precious secret, not as a game hint.")
		else:
			lines.append("PERSONAL KNOWLEDGE: You know the answer to the riddle guarding the entrance door, "
				+ "but you will NOT reveal it yet. The player has not earned your trust. "
				+ "If they ask, deflect or hint that they must prove themselves first.")
	if lines.is_empty():
		return ""
	return "\n\nDYNAMIC SECRETS:\n" + "\n".join(lines)


# --- costruzione dei prompt ---------------------------------------------

static func _mood_line(hostility: int, tier: String, verbose: bool) -> String:
	if tier == "high":
		if verbose:
			return "Attitude: HOSTILE (hostility %d/100). Respond coldly. Do not share secrets." % hostility
		return "Attitude: HOSTILE (hostility %d/100). Respond coldly." % hostility
	elif tier == "mid":
		if verbose:
			return "Attitude: GUARDED (hostility %d/100). Watchful. Secret info locked." % hostility
		return "Attitude: GUARDED (hostility %d/100). Watchful." % hostility
	else:
		if verbose:
			return "Attitude: OPEN (hostility %d/100). Willing to help." % hostility
		return "Attitude: OPEN (hostility %d/100). Willing to help." % hostility


static func _recent(history: Array) -> Array:
	return history.slice(maxi(0, history.size() - 3))


## Blocco di storico come lo formatta build_prompt(). Estratto in una
## funzione perche' serve anche al ramo locale: NobodyWho applica da se' il
## template della chat e non permette di iniettare turni dell'assistente,
## quindi lo storico viaggia dentro il system prompt.
static func build_history_block(history: Array) -> String:
	if history.is_empty():
		return ""
	var righe := PackedStringArray()
	for h in _recent(history):
		righe.append("Player: " + String(h["player"]))
		righe.append("You: " + String(h["npc"]))
	return "\n" + "\n".join(righe) + "\n"


## Prompt grezzo, gia' formattato secondo il template del modello: usato dal
## ramo di inferenza locale a completamento.
static func build_prompt(player_input: String, npc_name: String, hostility: int, friendship: int,
		language: String, history: Array, npc_data: Dictionary, context_vars: Variant = null) -> String:
	var personality := String(npc_data.get("personalita", "You are %s." % npc_name))
	var tier := hostility_tier(hostility, friendship)
	var army_name_local := OraculusData.ARMY_NAME if language == "italiano" else OraculusData.ARMY_NAME_EN
	var mood := _mood_line(hostility, tier, true)

	var hist := build_history_block(history)

	var location := String(npc_data.get("location", ""))
	var location_info := ""
	if not location.is_empty():
		location_info = ("CURRENT LOCATION: " + location + ". You (" + npc_name + ") are here, and so is the player. "
			+ "Speak of this place as the one around you, and of the other rooms as places elsewhere in the castle.")
	else:
		location_info = "CURRENT LOCATION: somewhere inside Oraculus Castle. You (" + npc_name + ") are here with the player."

	var dynamic := format_dynamic_secrets(npc_name, friendship, context_vars)
	var secret_policy := format_secret_policy(npc_data, hostility, friendship)

	var system := (OraculusData.STORY_CONTEXT + "\n\n"
		+ location_info + "\n\n"
		+ "CHARACTER:\n" + personality + "\n"
		+ secret_policy + "\n\n"
		+ mood + "\n"
		+ hist
		+ dynamic + "\n"
		+ "RULES:\n"
		+ "1. Always speak in " + language + ", in first person, in character.\n"
		+ "2. Keep your response to 1-3 short, complete sentences.\n"
		+ "3. NEVER use bullet points, numbered lists, or dashes. Write in prose only.\n"
		+ "4. Do NOT write meta-comments, notes, or parenthetical instructions.\n"
		+ "5. Do NOT start with your own name followed by ':'.\n"
		+ "6. Do NOT repeat the player's words.\n"
		+ "7. Stay in character. Never break the fourth wall.\n"
		+ "8. ALWAYS use the exact army name \"" + army_name_local + "\" when referring to the army that attacked.\n"
		+ "9. End each response with a period.\n"
		+ "10. Never use lists. Write as a flowing sentence.\n"
		+ "\nEXAMPLE GOOD RESPONSE: 'The first floor holds the Claristorium as its central hub, with the Painting Hall and Promontory to the east.'\n"
		+ "EXAMPLE BAD RESPONSE: '1. Claristorium 2. Painting Hall 3. Promontory'\n")

	var prompt := ""
	if OraculusData.MODEL_FORMAT == "llama3":
		prompt = "<|start_header_id|>system<|end_header_id|>\n\n" + system + "<|eot_id|>"
		if not history.is_empty():
			for h in _recent(history):
				prompt += "<|start_header_id|>user<|end_header_id|>\n\n" + String(h["player"]) + "<|eot_id|>"
				prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n" + String(h["npc"]) + "<|eot_id|>"
		prompt += "<|start_header_id|>user<|end_header_id|>\n\n" + player_input + "<|eot_id|>"
		prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"
	else:
		prompt = "<|im_start|>system\n" + system + "<|im_end|>\n"
		prompt += "<|im_start|>user\n" + player_input + "<|im_end|>\n"
		prompt += "<|im_start|>assistant\n"

	return prompt


## System message per le API chat: usato dal ramo remoto e da NobodyWho,
## che applicano da soli il template del modello.
static func build_system_msg(npc_name: String, hostility: int, friendship: int, language: String,
		npc_data: Dictionary, context_vars: Variant = null) -> String:
	var personality := String(npc_data.get("personalita", "You are %s, an ancient spirit." % npc_name))
	var tier := hostility_tier(hostility, friendship)
	var army_name_local := OraculusData.ARMY_NAME if language == "italiano" else OraculusData.ARMY_NAME_EN
	var mood := _mood_line(hostility, tier, false)

	var dynamic := format_dynamic_secrets(npc_name, friendship, context_vars)
	var secret_policy := format_secret_policy(npc_data, hostility, friendship)
	var location := String(npc_data.get("location", ""))
	var location_info := ""
	if not location.is_empty():
		location_info = "CURRENT LOCATION: " + location + ". You (" + npc_name + ") are here, and so is the player.\n\n"

	return (OraculusData.STORY_CONTEXT + "\n\n"
		+ location_info
		+ "CHARACTER:\n" + personality + "\n"
		+ secret_policy + "\n\n"
		+ mood
		+ dynamic + "\n\n"
		+ "RULES:\n"
		+ "1. Always speak in " + language + ", in first person, in character.\n"
		+ "2. Keep your response to 1-3 short, complete sentences.\n"
		+ "3. NEVER use bullet points, numbered lists, or dashes. Write in prose only.\n"
		+ "4. Do NOT write meta-comments. Stay in character.\n"
		+ "5. Do NOT start with your own name followed by ':'.\n"
		+ "6. ALWAYS use the exact army name \"" + army_name_local + "\" when referring to the army.\n"
		+ "7. End each response with a period.\n")


# --- indovinelli --------------------------------------------------------

static func build_riddle_system(theme: String, language: String) -> String:
	return ("You are an ancient spirit guardian of Oraculus Castle, year 1300.\n"
		+ OraculusData.STORY_CONTEXT + "\n\n"
		+ "You guard a door with a riddle. Create ONE riddle following these rules:\n"
		+ "- Theme: " + theme + "\n"
		+ "- Tone: dark, mysterious, medieval fantasy — but the riddle itself must be SIMPLE and EASY to understand\n"
		+ "- The answer must be a single common, everyday word (an object, animal, or simple concept a child would know)\n"
		+ "- Describe the answer using clear, concrete, literal clues (what it looks like, what it does, where you find it)\n"
		+ "- Do NOT use abstract philosophy, obscure metaphors, or wordplay — a player should be able to guess it after reading it once\n"
		+ "- Length: 2-3 short, simple sentences\n"
		+ "- NEVER directly mention the answer in the riddle\n"
		+ "- Every riddle must be unique and different from any you have created before\n"
		+ "- Respond in " + language + "\n\n"
		+ "Respond ONLY in this exact format, nothing else:\n"
		+ "RIDDLE: [riddle text]\n"
		+ "ANSWER: [single word]")


static func build_riddle_user(language: String, theme: String, session_id: String) -> String:
	var variation_hint := (" (session: " + session_id + ")") if not session_id.is_empty() else ""
	return "Generate a new, unique riddle in " + language + " about: " + theme + variation_hint


static func build_riddle_prompt(system: String, user_msg: String) -> String:
	if OraculusData.MODEL_FORMAT == "llama3":
		return ("<|start_header_id|>system<|end_header_id|>\n\n" + system + "<|eot_id|>"
			+ "<|start_header_id|>user<|end_header_id|>\n\n" + user_msg + "<|eot_id|>"
			+ "<|start_header_id|>assistant<|end_header_id|>\n\n")
	return ("<|im_start|>system\n" + system + "<|im_end|>\n"
		+ "<|im_start|>user\n" + user_msg + "<|im_end|>\n"
		+ "<|im_start|>assistant\n")


## Restituisce {"riddle": ..., "answer": ...} oppure null se il formato
## RIDDLE:/ANSWER: non e' rispettato o il contenuto e' troppo corto.
static func parse_riddle_response(raw: String) -> Variant:
	_init_regex()
	var riddle_match := _re_riddle.search(raw)
	var answer_match := _re_answer.search(raw)
	if riddle_match == null or answer_match == null:
		return null
	var riddle := riddle_match.get_string(1).strip_edges()
	var answer := answer_match.get_string(1).strip_edges().to_lower()
	if riddle.length() < 10 or answer.length() < 2:
		return null
	return {"riddle": riddle, "answer": answer}
