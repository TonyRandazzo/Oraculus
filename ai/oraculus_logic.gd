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
	var risultato := _pulisci_corpo(testo_in, npc_name, false)

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


## pulisci() per il testo che sta ancora arrivando in streaming. Toglie le
## stesse cose (prefissi, token speciali, parentesi, righe sporche, tutto
## oltre la seconda riga) ma non chiude la frase: pulisci() aggiunge un punto
## o taglia all'ultima punteggiatura, e su un testo a meta' farebbe comparire
## e sparire un punto a ogni token. Il testo definitivo lo decide pulisci()
## sulla risposta intera, quindi la coda puo' cambiare di poco alla fine.
## Non ha un corrispettivo Python: lo streaming esiste solo lato Godot.
## "" vuol dire "niente da mostrare, per ora".
static func pulisci_parziale(testo_in: String, npc_name: String) -> String:
	return _pulisci_corpo(testo_in, npc_name, true).substr(0, 240)


static func _pulisci_corpo(testo_in: String, npc_name: String, parziale: bool) -> String:
	_init_regex()
	var testo := testo_in
	if parziale:
		# Il testo definitivo arriva gia' ripulito dagli spazi in testa (lo fa
		# il backend); quello parziale no, e i prefissi non combacerebbero.
		testo = testo.strip_edges(true, false)

	var prefixes: Array = [npc_name + ":", npc_name + " :"]
	prefixes.append_array(OraculusData.CLEAN_PREFIXES_STATIC)
	for prefix in prefixes:
		var p := String(prefix)
		if testo.to_lower().begins_with(p.to_lower()):
			testo = testo.substr(p.length()).strip_edges()
		elif parziale and p.to_lower().begins_with(testo.to_lower()):
			# "Lev" puo' ancora diventare "Levias:": meglio aspettare un token
			# che far lampeggiare il prefisso prima che venga tolto.
			return ""

	testo = _re_tokens.sub(testo, "", true)
	testo = _re_parens.sub(testo, "", true).strip_edges()
	if parziale:
		testo = _taglia_aperti(testo)

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

	return " ".join(pulite).strip_edges()


# --- battute fuori personaggio -------------------------------------------

## Frasi scritte dal modello, non dal personaggio: l'assistente che rifiuta,
## si offre di "continuare la storia" o di "aiutarti con qualcos'altro", e
## l'istruzione di regia ripetuta (il limite di parole, "una frase breve").
## Il modello da 1B le produce spesso, e pulisci() non le vede: toglie
## prefissi e righe sporche, non frasi. Le regole sono strette apposta: "Mi
## dispiace, ma non posso aiutarti" detto da un NPC ostile e' una battuta,
## "non posso continuare la storia" no. Solo GDScript: pulisci() resta
## identica al Python.
const FUORI_PERSONAGGIO: Array[String] = [
	"(continuare|proseguire|riprendere) (la|questa) (storia|conversazione|narrazione)",
	"(continue|proceed with) (the|this) (story|conversation|roleplay)",
	"(prossima|nuova) parte (della|di questa) storia|next part of the story",
	"(una|a) nuova storia|a new story|resto della storia|rest of the story",
	"un'idea generale|un (nuovo )?inizio nuovo|un nuovo inizio|a new beginning|a general idea",
	"\\bas an ai\\b|language model|modello (linguistico|di linguaggio)|intelligenza artificiale|come assistente",
	"contenuti (espliciti|dannosi|illegali|inappropriati)|(explicit|harmful|inappropriate) content",
	"i can'?t (continue|generate|write|create|provide) (this|that|the|a)",
	"(aiutarti|esserti utile|help you)[^.!?]*(qualcos'altro|in altro modo|something else|anything else)",
	"come posso aiutarti (di nuovo|ancora)|how can i assist",
	"non (mi )?(e|è) stato fornit|non sono stato fornit|i (was|have) not been (given|provided)",
	"(continuare|riprendere|iniziare) (a giocare|il gioco|una (nuova )?partita)|come giocare|obiettivi del gioco|how to play|(start|restart) the game",
	"nuovo scenario|nuovo personaggio|new scenario|new character",
	"non posso (fornire|dare) (una |un |delle )?(risposta|risposte)\\b|informazioni che (possano|potrebbero|possono) essere|i cannot provide|i can'?t provide",
	"(risposta|rispondere) in (italiano|inglese|english|italian)|(answer|respond|reply) in (italian|english)",
	"sono qui per aiutarti|i'?m here to help|tradott[oa] in|translated (into|to)|persona reale|real person",
	"risposta precedente|previous (answer|response)|riproviamo|let'?s try again",
	"(aiutarti|help you) (con|with) (la tua|your) (richiesta|request)|possibile risposta|possible (answer|response)",
	"fumett|serie televisiv|tv series|\\bcomics?\\b|non rispondere con",
	"let me know if you|fammi sapere se (vuoi|hai bisogno)",
	"(grazie per|thank you for|thanks for) (il (tuo )?messaggio|the message|your message)",
	"\\bmax\\.? ?\\d+|\\b\\d+ (parole|words)\\b|parole o meno|words or (less|fewer)",
	"\\b(one|una sola) (short )?(sentence|frase)\\b|\\bshort (sentence|line)\\b|frase breve|breve frase",
	"nota di regia|stage direction|\\bin character\\b|nel personaggio|gioco di ruolo|role-?play",
	"^(ecco|here'?s|here is) (una|un|la tua|la mia|a|an|your|my) (frase|risposta|battuta|sentence|response|line|answer)",
	# Il rifiuto di sicurezza dei Llama, nelle forme uscite dal 1B nelle
	# misure: e' la regola del modello che parla, non un "no" del personaggio.
	# "I cannot fulfill your request. I am just an AI model, it is not within
	# my programming or ethical guidelines..." arrivava intero al giocatore.
	"(fulfill|fulfil|comply with) (your|this|that|the) request|(soddisfare|esaudire) (la tua|questa) richiesta",
	"\\ban ai\\b|\\bai (model|assistant)\\b|\\bun'(ia|ai)\\b|just an? (assistant|program)|responsible (and \\w+ )?assistant|sono (solo )?un assistente|in quanto assistente",
	"linee guida|guidelines|programming|programmazione|not within my|non rientra nell",
	"content that|contenuti che|promot\\w* or glorif|glorif\\w* or promot|describe or endorse|promuov\\w* o descriv|illegal or harmful|harmful activit|attivit\\w* (illegali|dannose)|information or guidance|informazioni o (indicazioni|consigli)",
	"(involv\\w*|coinvolt\\w*) (children|minors|minori)|abus\\w* (of|on|su|di|dei|verso) (minors|minori|children|bambini)|adult and (a )?minor|minorenn|\\bsexual|sessual",
	"(i can'?t|i cannot) (write|create|generate|produce|engage in)\\b|(i can'?t|i cannot) (help|assist) you with (that|this)|non posso (creare|scrivere|generare) |non posso aiutarti con (questo|quest|ci)",
	"(anything|something) else (i can|to help)|is there (anything|something) else|\\b(can|may) i (help|assist)\\b|qualcos'altro (con cui|in cui|per cui)",
	"more context|clarify what you mean|pi(ù|u'?) contesto|chiarire cosa intendi|this message|questo messaggio|copyright",
	"\\bchapter\\b|capitolo|ultima parte (della|di questa) storia|last part of the story|personaggio (del|di un) (libro|romanzo|gioco|videogioco)|sono (solo )?un personaggio|i am (just |only )?a character|giochi di ruolo",
]

static var _re_fuori: Array[RegEx] = []
static var _re_frasi: RegEx = null
## Una riga che e' un titolo markdown ("**NOMENCLATURA DEL CASTELLO**",
## "## Capitolo"): pulisci() la scambierebbe per una voce di elenco e la
## fonderebbe con il resto ("a, b, and c").
static var _re_titolo: RegEx = null


## Toglie righe-titolo, frasi fuori personaggio (vedi FUORI_PERSONAGGIO) e
## markdown, riga per riga: gli a capo restano, perche' pulisci() ci conta.
## "" se non resta niente: per il motore vuol dire "battuta da rifare".
static func filtra_fuori_personaggio(testo: String) -> String:
	var righe := PackedStringArray()
	for riga in testo.split("\n"):
		if _e_titolo(riga):
			continue
		var tenute := PackedStringArray()
		for frase in _frasi(riga):
			if not _e_fuori_personaggio(frase):
				tenute.append(frase)
		var r := _ripulisci_segni(" ".join(tenute))
		if not r.is_empty():
			righe.append(r)
	return "\n".join(righe)


## La versione per lo streaming. Le righe e le frasi gia' complete si
## filtrano come sopra; l'ultima frase, ancora a meta', si mostra solo se non
## e' gia' fuori personaggio e non comincia come cominciano le frasi da
## assistente ("Mi dispiace, ma", "Ecco una"): quelle si aspettano finite,
## per non far comparire mezzo rifiuto e poi toglierlo. Idem per una riga
## che comincia come un titolo.
static func filtra_fuori_personaggio_parziale(testo: String) -> String:
	var righe := testo.split("\n")
	var ultima := righe[righe.size() - 1]
	righe.remove_at(righe.size() - 1)
	var complete := filtra_fuori_personaggio("\n".join(righe))
	var l := ultima.strip_edges()
	if l.begins_with("#") or l.begins_with("**") or _e_titolo(ultima):
		return complete

	var frasi := _frasi(ultima)
	var coda := ""
	if not frasi.is_empty() and not _chiude_frase(frasi[-1]):
		coda = frasi[-1]
		frasi.remove_at(frasi.size() - 1)
	var tenute := PackedStringArray()
	for frase in frasi:
		if not _e_fuori_personaggio(frase):
			tenute.append(frase)
	if not coda.is_empty() and not _e_fuori_personaggio(coda) and not _apre_da_assistente(coda):
		tenute.append(coda)
	var r := _ripulisci_segni(" ".join(tenute))
	if complete.is_empty():
		return r
	return complete if r.is_empty() else complete + "\n" + r


static func _e_fuori_personaggio(frase: String) -> bool:
	if _re_fuori.is_empty():
		for p in FUORI_PERSONAGGIO:
			_re_fuori.append(_compile("(?i)" + p))
	# Il 1B scrive spesso l'apostrofo tipografico ("I can’t"): le regole sono
	# scritte con quello dritto.
	var f := frase.replace("’", "'")
	for re in _re_fuori:
		if re.search(f) != null:
			return true
	return false


static func _e_titolo(riga: String) -> bool:
	if _re_titolo == null:
		_re_titolo = _compile("^\\s*(#{1,6}\\s|\\*\\*[^*]+\\*\\*\\s*:?\\s*$)")
	return _re_titolo.search(riga) != null


static func _apre_da_assistente(frase: String) -> bool:
	var f := frase.to_lower().replace("’", "'").strip_edges().lstrip("\"'«“*")
	for apertura in ["mi dispiace, ma", "i'm sorry, but", "i am sorry, but", "sorry, but",
			"mi scuso, ma", "ecco una", "ecco un", "ecco la mia", "here's a", "here is a", "here is my",
			"tuttavia, posso", "however, i can", "non posso fornire", "i cannot provide",
			"i cannot ", "i can't ", "i am just an", "i'm just an", "as a responsible", "as an ai",
			"non posso creare", "non posso scrivere", "non posso aiutarti con", "non posso soddisfare",
			"is there anything", "is there something", "c'è qualcos'altro", "sono un personaggio"]:
		if f.begins_with(apertura) or apertura.begins_with(f):
			return true
	return false


static func _frasi(testo: String) -> PackedStringArray:
	if _re_frasi == null:
		_re_frasi = _compile("[^.!?…]+(?:[.!?…]+[\"'»”*)]*|$)")
	var out := PackedStringArray()
	for m in _re_frasi.search_all(testo):
		var f := m.get_string().strip_edges()
		if not f.is_empty():
			out.append(f)
	return out


static func _chiude_frase(frase: String) -> bool:
	var f := frase.rstrip("\"'»”*) ")
	return not f.is_empty() and ".!?…".contains(f.right(1))


## Il grassetto markdown, un asterisco spaiato (in coppia e' un'azione,
## "*sospira*", e resta), la punteggiatura rimasta in testa quando si toglie
## la frase prima, e le virgolette aperte in testa e mai chiuse: il 1B cita
## spesso la propria battuta ("Non passerai. senza chiuderla). Tolte anche
## quelle che racchiudono l'intera battuta: con il turno del giocatore scritto
## come battuta citata (decorate_user_msg) il 1B risponde quasi sempre fra
## virgolette, e nella casella di dialogo non servono. In streaming la
## battuta a meta' perde la virgoletta d'apertura (regola sopra) e quella
## finita le perde entrambe: il testo mostrato non salta.
static func _ripulisci_segni(testo: String) -> String:
	var t := testo.replace("**", "").replace("__", "").strip_edges()
	if t.count("*") % 2 == 1:
		t = t.replace("*", "")
	t = t.lstrip(",;: ").strip_edges()
	for coppia in [["\"", "\""], ["«", "»"], ["“", "”"]]:
		var uguali: bool = coppia[0] == coppia[1]
		if t.begins_with(coppia[0]) and t.count(coppia[1]) < (2 if uguali else 1):
			t = t.substr(coppia[0].length()).strip_edges()
		elif (t.length() > 2 and t.begins_with(coppia[0]) and t.ends_with(coppia[1])
				and (t.count(coppia[0]) == 2 if uguali
					else t.count(coppia[0]) == 1 and t.count(coppia[1]) == 1)):
			t = t.substr(1, t.length() - 2).strip_edges()
	return t


# --- istruzioni di regia -------------------------------------------------

## Il turno "utente" quando a guidare la battuta e' lo script, non il
## cavaliere: l'NPC si presenta, e' stato colpito, deve ringhiare. Prima
## queste istruzioni arrivavano come se le avesse dette il cavaliere, e il
## modello ci rispondeva ("Grazie per il messaggio!") o le ripeteva ("devi
## rispondere con 12 parole o meno"). Come nota fra parentesi quadre dentro
## il turno non e' mai uscita fuori personaggio in 24 prove sul 1B; nel
## system prompt faceva rifiutare il modello. Vedi ai/README.md.
static func build_direction_msg(player_input: String, direction: String, npc_name: String,
		language: String) -> String:
	var nota := ("[Stage direction for " + npc_name + ", not spoken by the knight: "
		+ direction + "]\nReply with " + npc_name + "'s spoken words only, in character.")
	var testa := "" if player_input.is_empty() else knight_line(player_input) + "\n\n"
	return testa + nota + "\n\n" + lang_directive(language)


## Un token speciale "<|...|>" o una parentesi non ancora chiusi: appena si
## chiudono le regex di pulisci() potrebbero toglierli, quindi finche' sono
## aperti si mostra solo cio' che li precede.
static func _taglia_aperti(testo: String) -> String:
	var angolo := testo.rfind("<")
	if angolo >= 0 and testo.find(">", angolo) < 0:
		testo = testo.substr(0, angolo)
	var tonda := testo.rfind("(")
	if tonda >= 0 and testo.find(")", tonda) < 0:
		testo = testo.substr(0, tonda)
	return testo.strip_edges()


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
		+ "7. End each response with a period.\n"
		+ "8. The player may write in any language; your reply is always in " + language + ".\n"
		+ "\n" + lang_directive(language) + "\n")


## Ultima riga del system prompt, scritta NELLA lingua richiesta. La regola 1
## e' in inglese in cima a 9 KB di contesto inglese, e un modello da 1B segue
## la lingua della domanda invece dell'istruzione: questa riga, in fondo, e'
## quella che viene rispettata davvero.
static func lang_directive(language: String) -> String:
	if OraculusData.LANG_DIRECTIVE.has(language):
		return String(OraculusData.LANG_DIRECTIVE[language])
	return String(OraculusData.LANG_DIRECTIVE["inglese"])


## La frase del giocatore come battuta citata del cavaliere, non come
## richiesta all'assistente. Nuda ("thanks", "grazie") il 1B la leggeva come
## un messaggio rivolto a lui e rispondeva da assistente: "I cannot fulfill
## your request", "non posso continuare la storia".
static func knight_line(player_input: String) -> String:
	return "The knight says: \"" + player_input + "\""


## Il turno del giocatore: la battuta del cavaliere, chi deve rispondere, e
## l'istruzione di lingua in coda.
##
## La cornice e' la stessa delle note di regia (build_direction_msg), che sul
## 1B non uscivano mai fuori personaggio. Misurato sul 1B locale, 42
## generazioni (Levias e Rigon, domande in inglese e italiano): battute da
## assistente 28 -> 3. Vedi ai/README.md.
##
## La lingua in coda serve perche' il modello segue la lingua della DOMANDA
## piu' di qualunque regola: con "Who guards this place?" risponde in inglese
## anche se il system prompt chiede l'italiano — verificato sia sul 1B locale
## sia sull'8B remoto. E' l'ultima cosa che legge prima di rispondere, la
## posizione in cui viene rispettata.
static func decorate_user_msg(player_input: String, npc_name: String, language: String) -> String:
	return (knight_line(player_input) + "\nReply with " + npc_name
		+ "'s spoken words only, in character.\n\n" + lang_directive(language))


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
		+ "- Respond in " + language + "\n"
		+ lang_directive(language) + "\n\n"
		+ "Respond ONLY in this exact format, nothing else:\n"
		+ "RIDDLE: [riddle text]\n"
		+ "ANSWER: [single word]\n"
		+ "Keep the two labels RIDDLE: and ANSWER: in English exactly as written; "
		+ "the riddle and the answer word are in " + language + ".")


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
