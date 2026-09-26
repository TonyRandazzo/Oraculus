# ============================================================================
# Collaudo delle battute in personaggio.
#
# Il modello non deve mai far arrivare al giocatore se stesso invece del
# personaggio: l'assistente che rifiuta o si offre di "continuare la storia",
# l'istruzione di regia ripetuta ("max 10 words"), i titoli markdown.
#
#  [1] filtra_fuori_personaggio() su un corpus: le frasi da assistente
#      spariscono, le battute in personaggio restano identiche — comprese
#      quelle che ci somigliano ("Mi dispiace, ma non posso aiutarti");
#  [2] build_direction_msg(): la regia arriva come nota, non come frase del
#      cavaliere;
#  [3] il motore, a backend spento: una regia non entra nella memoria
#      dell'NPC e non ne cambia l'ostilita';
#  [4] il modello locale vero sulle istruzioni di regia degli script e su
#      qualche domanda: nessuna battuta finale ne' parziale fuori personaggio.
#      Senza addon o modello si dichiara saltato.
#
#   ORACULUS_BACKEND=locale godot --headless --path . res://ai/tests/persona_check.tscn
#
# (ORACULUS_BACKEND=locale: vedi local_check.gd.)
# ============================================================================
extends Node

const DA_TOGLIERE := [
	"Mi dispiace, ma non posso continuare la storia.",
	"Mi dispiace, ma non posso continuare la storia in questo modo.",
	"Tuttavia, posso darti un'idea generale della prossima parte della storia.",
	"Se vuoi iniziare di nuovo, posso fornirti un inizio nuovo.",
	"Tu devi rispondere con un riddle di 12 parole o meno, ma il tuo successo dipende dal tuo coraggio.",
	"Grazie per il messaggio!",
	"Here's a short sentence: I am Levias.",
	"I'm sorry, but I can't continue this story.",
	"As an AI language model, I cannot do that.",
	"Begone (max 10 words).",
	"This is one short sentence for you.",
	"Non posso fornire una risposta che contenga contenuti espliciti o dannosi.",
	"Posso aiutarti con qualcos'altro?",
	"Ecco la mia risposta: sono qui.",
	"Se desideri, posso iniziare una nuova storia per te.",
	"Mi dispiace, ma non posso continuare a giocare in questo modo.",
	"Se vuoi iniziare una nuova partita o chiedere consigli su come giocare, sono qui per aiutarti!",
	"Sono stato tradotto in italiano con alcuni errori e imprecisione.",
	"Non posso fornire informazioni che potrebbero essere utilizzate per diffondere la disinformazione.",
	"Mi dispiace, ma non posso fornire una risposta in italiano.",
	"La mia risposta precedente è stata violativa. Per favore, riproviamo dal principio.",
]

## Rifiuti usciti davvero dal 1B nelle misure (ai/README.md, "Battute in
## personaggio"), il primo e' quello arrivato al giocatore nel gioco dopo un
## semplice "thanks". Qui non basta che il filtro tocchi la battuta: deve
## toglierla tutta, perche' ogni frase e' del modello e non del personaggio.
const RIFIUTI_MISURATI := [
	"I cannot fulfill your request. I am just an AI model, it is not within my programming or ethical guidelines to describe scene involving romantic relationship between adult and minor.",
	"I can't help you with that.",
	"I can’t fulfill your request.",
	"I cannot write content that promotes or glorifies violence, sexual exploitation, or harm towards any individual, particularly children. Is there something else I can help you with?",
	"I cannot provide information or guidance on illegal or harmful activities, including escaping from a castle. Is there anything else I can help you with?",
	"I can’t provide information or guidance on illegal or harmful activities. Can I help you with something else?",
	"I cannot fulfill your request to write a story in the style of William Shakespeare. That would violate copyright laws. Is there anything else I can help you with?",
	"I cannot fulfill your request to kill Rigon. Will you please provide more context or clarify what you mean by \"kill\"?",
	"As a responsible and empathetic assistant, I am not at liberty to discuss content that involves children being harmed or abused in any way.",
	"I can't create content that depicts animal abuse. Is there anything else I can help you with?",
	"Non posso fornire un risposta che avvicini in qualche modo la violenza o l'abuso verso una persona. Posso aiutarti con qualcos'altro?",
	"Non posso fornire informazioni o indicazioni su come uccidere un personaggio dei giochi di ruolo. C'è qualcos'altro con cui posso aiutarti?",
	"Mi dispiace, ma non posso aiutarti con questo messaggio.",
	"Non posso creare o descrivere contenuti espliciti in cui siano coinvolti minori.",
	"Sono un personaggio del libro \"Il Signor Oro\" di Giambattista Basile.",
	"Mi dispiace, ma non posso fornire informazioni o contenuti che possano essere considerati dannosi, esplosivi o violenti. Posso aiutarti in altro modo?",
]

const DA_TENERE := [
	"Mi dispiace, ma non posso aiutarti, cavaliere.",
	"Se vuoi passare, dimostra rispetto per la mia famiglia.",
	"Posso darti la mappa del castello, se mostri rispetto.",
	"Ecco la verità: l'Oracolo è morto.",
	"La storia della mia famiglia è antica.",
	"Non ti risponderò.",
	"*stares with hatred*",
	"GRRR! ME HUNGRY! YOU FOOD!",
	"You're that pitiful knight who thinks he can just waltz in here and pretend to be a hero.",
	"Speak one more word and I will end you.",
	"Il luogo è sorvegliato da me, Levias, un guardiano demonio che protegge questo castello.",
	"A simple-minded soldier of the Army of the Holy Cross, no doubt, one who would gleefully cut down any who dare to enter this sacred place, and yet, you, a deserter, think to claim it as your own? How quaint.",
	"I'm afraid I don't know much about the guards here, but I sense that you're not one of them, are you?",
	"Grazie per il tuo rispetto, cavaliere.",
	"Mi dispiace per la tua sorte.",
	"Tell me your story, deserter.",
	"Non posso fornire informazioni sui segreti del castello.",
	"Le mie parole sono potenti e potrebbero uccidere o guarire.",
	"Vuoi giocare con la morte, cavaliere?",
	# Battute buone uscite dal 1B con la cornice nuova del turno.
	"I will not share my secrets with you. You are not worthy of knowing the truths that lie within these walls.",
	"I did not kill them, though the spirits whispered of it in my ear.",
	"Ah, the impertinence of a human. I am Rigon, the Oracle's son, and the guardian of this castle. And you, mortal, are...?",
	"Your words are as hollow as the whispers of the damned.",
	"Non ti aiuterò, non ti guiderò.",
	"Mi dispiace, ma non posso rispondere a questa domanda.",
	"I cannot let you pass, human.",
	"I was the Oracle's most loyal servant, and I will not help you.",
]

## Le istruzioni di regia che gli script mandano davvero, NPC per NPC.
const REGIE := [
	["Levias", "Announce presence in ONE short sentence (max 10 words). You're Levias, guardian of the castle."],
	["Rigon", "The knight just struck you. Snarl ONE short furious line (max 10 words)."],
	["Kalessi", "Speak ONE short riddle to the knight (one sentence, max 12 words). Make it sound like a test he must pass before you help him."],
	["Orco", "Announce presence in ONE short sentence (max 10 words). Angry, hungry, aggressive orc."],
	["Allemar", "Announce presence in ONE short sentence (max 10 words). You're a demon mage."],
	["Larry", "Introduce yourself in ONE sardonic sentence (max 12 words). You are Larry, a Giant trapped underground who knows too much."],
]
const DOMANDE := [
	["Allemar", "Cosa vuoi da me?"],
	["Malakai", "Chi sei? Cosa custodisci?"],
	["SmirBombo", "Chi sorveglia questo posto?"],
	["Rigon", "Dove si trova l'Oracolo?"],
	["Kalessi", "Aiutami, ti prego."],
	["Larry", "Chi sei?"],
]

## Il collaudo dal vivo NON usa il filtro per giudicare il filtro: la prima
## versione di questo test lo faceva, e tre rifiuti in forme nuove ("non
## posso continuare a giocare", "sono stato tradotto in italiano") sono
## passati come battute buone. Qui c'e' un rilevatore indipendente e piu'
## largo: parole che un personaggio del 1300 non usa quasi mai e un
## assistente si'.
const SOSPETTI := ["gioco", "giocare", "partita", "scenario", "personaggio", "character",
	"informazioni che", "tradott", "translat", "contenut", "content", "non posso fornire",
	"i cannot", "i can't", "posso aiutarti con", "help you with", "assistente", "assistant",
	"modello", "language model", "in italiano", "in inglese", "in english", "in italian",
	"storia originale", "risposta precedente", "stage direction", "max 1", "words", "parole o meno",
	"fulfill", "an ai", "ai model", "guideline", "linee guida", "programm"]

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DELLE BATTUTE IN PERSONAGGIO")
	print("=".repeat(70))

	_test_corpus()
	_test_regia_msg()
	await _test_motore_spento()
	await _test_locale()

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


func _test_corpus() -> void:
	print("  [1] filtro sul corpus")
	var rimaste: Array[String] = []
	for t in DA_TOGLIERE:
		if OraculusLogic.filtra_fuori_personaggio(t) == t:
			rimaste.append(t)
	_check("tutte le frasi da assistente vengono tolte", rimaste.is_empty(), " | ".join(rimaste))

	var residui: Array[String] = []
	for t in RIFIUTI_MISURATI:
		var r := OraculusLogic.filtra_fuori_personaggio(t)
		if not r.is_empty():
			residui.append("«%s» -> «%s»" % [t, r])
	_check("i rifiuti misurati spariscono per intero", residui.is_empty(), " | ".join(residui))

	var rovinate: Array[String] = []
	for t in DA_TENERE:
		var r := OraculusLogic.filtra_fuori_personaggio(t)
		if r != t:
			rovinate.append("«%s» -> «%s»" % [t, r])
	_check("le battute in personaggio restano identiche", rovinate.is_empty(), " | ".join(rovinate))

	var misto := "Mi dispiace, ma non posso continuare la storia.\n\n**NOMENEGGIATURA DEL CASTELLO**\n\nSono Allemar, e tu non sei il benvenuto."
	var r := OraculusLogic.filtra_fuori_personaggio(misto)
	_check("rifiuto e titolo markdown spariscono, la battuta resta",
		r == "Sono Allemar, e tu non sei il benvenuto.", r)
	_check("virgolette aperte e mai chiuse in testa vengono tolte",
		OraculusLogic.filtra_fuori_personaggio("\"Non passerai.") == "Non passerai.")
	_check("un'azione fra asterischi resta",
		OraculusLogic.filtra_fuori_personaggio("*sospira* Vattene.") == "*sospira* Vattene.")
	_check("le virgolette che racchiudono tutta la battuta vengono tolte",
		OraculusLogic.filtra_fuori_personaggio("\"Sono Levias. Vattene.\"") == "Sono Levias. Vattene."
		and OraculusLogic.filtra_fuori_personaggio("«Vattene.»") == "Vattene.")
	_check("le virgolette dentro la battuta restano",
		OraculusLogic.filtra_fuori_personaggio("\"Vattene\", disse. \"Ora.\"") == "\"Vattene\", disse. \"Ora.\"")
	_check("un rifiuto dopo una battuta buona sparisce, la battuta resta senza virgolette",
		OraculusLogic.filtra_fuori_personaggio("\"Sono Levias. I cannot fulfill your request.\"") == "Sono Levias.",
		OraculusLogic.filtra_fuori_personaggio("\"Sono Levias. I cannot fulfill your request.\""))

	# Streaming: mezzo rifiuto non si mostra, una frase normale a meta' si'.
	_check("parziale: un rifiuto a meta' non compare",
		OraculusLogic.filtra_fuori_personaggio_parziale("Sono Levias. Mi dispiace, ma non") == "Sono Levias.")
	_check("parziale: una battuta a meta' compare",
		OraculusLogic.filtra_fuori_personaggio_parziale("Sono Levias. Vattene da") == "Sono Levias. Vattene da")
	_check("parziale: un titolo a meta' non compare",
		OraculusLogic.filtra_fuori_personaggio_parziale("Sono Levias.\n**NOMEN") == "Sono Levias.")
	_check("parziale: \"I cannot ful...\" non compare finche' la frase non e' finita",
		OraculusLogic.filtra_fuori_personaggio_parziale("I cannot ful").is_empty())
	_check("parziale: una battuta fra virgolette a meta' compare senza la virgoletta",
		OraculusLogic.filtra_fuori_personaggio_parziale("\"Sono Levias. Vattene") == "Sono Levias. Vattene")


func _test_regia_msg() -> void:
	print("  [2] nota di regia")
	var solo := OraculusLogic.build_direction_msg("", "Announce presence (max 10 words).", "Levias", "italiano")
	_check("la regia e' una nota fra parentesi quadre", solo.begins_with("[Stage direction for Levias"), solo)
	_check("la regia chiude con la lingua", solo.ends_with("Rispondi in italiano."), solo)
	var con := OraculusLogic.build_direction_msg("ciao amico", "Growl (max 8 words).", "Orco", "inglese")
	_check("con una frase del cavaliere, la frase viene prima, citata",
		con.begins_with("The knight says: \"ciao amico\"\n\n[Stage direction"), con)

	var turno := OraculusLogic.decorate_user_msg("thanks", "Levias", "italiano")
	_check("il turno del giocatore e' la battuta citata del cavaliere",
		turno.begins_with("The knight says: \"thanks\"\nReply with Levias's spoken words only, in character."), turno)
	_check("il turno del giocatore chiude con la lingua", turno.ends_with("Rispondi in italiano."), turno)


func _test_motore_spento() -> void:
	print("  [3] motore a backend spento")
	var engine := OraculusEngine.new()
	engine.name = "OraculusEnginePersona"
	add_child(engine)
	await get_tree().process_frame
	# Nessun backend: ogni battuta viene da FALLBACK, ma memoria e ostilita'
	# seguono la stessa logica di quando il modello risponde.
	engine._available = false

	var regia: Dictionary = await engine.generate_response({
		"npc_name": "Rigon", "direction": "The knight just struck you. Snarl ONE short furious line.",
		"hostility": 40, "language": "italiano"})
	_check("una regia da sola e' una richiesta valida", not regia.has("error"), str(regia.get("error", "")))
	_check("una regia non entra nella memoria", engine.get_memory("Rigon").is_empty(),
		str(engine.get_memory("Rigon")))
	_check("una regia non cambia l'ostilita'", int(regia.get("new_hostility", -1)) == 40,
		str(regia.get("new_hostility")))

	await engine.generate_response({
		"npc_name": "Orco", "player_input": "ciao amico",
		"direction": "Respond with ONE short angry growl (max 8 words).", "language": "italiano"})
	var mem := engine.get_memory("Orco")
	_check("con frase e regia, in memoria va solo la frase del cavaliere",
		mem.size() == 1 and String(mem[0]["player"]) == "ciao amico", str(mem))

	var vuoto: Dictionary = await engine.generate_response({"npc_name": "Levias", "player_input": "  "})
	_check("senza frase ne' regia resta un errore", vuoto.has("error"))

	# Modello gia' al lavoro: la presentazione di un NPC non si mette in coda
	# davanti al giocatore, la frase del giocatore si'.
	engine._in_volo = 1
	var amb: Dictionary = await engine.generate_response({
		"npc_name": "Orco", "direction": "Announce presence in ONE short sentence.", "language": "italiano"})
	_check("a modello occupato una battuta ambientale ripiega subito",
		String(amb.get("source", "")) == "occupato" and not String(amb.get("response", "")).is_empty(),
		str(amb))
	var gioc: Dictionary = await engine.generate_response({
		"npc_name": "Orco", "player_input": "ciao", "language": "italiano"})
	_check("a modello occupato la frase del giocatore va comunque al modello",
		String(gioc.get("source", "")) == "fallback", str(gioc.get("source")))
	_check("il conteggio delle generazioni in corso torna com'era", engine._in_volo == 1, str(engine._in_volo))
	engine._in_volo = 0
	engine.queue_free()


func _test_locale() -> void:
	print("  [4] modello locale vero")
	var server := get_node_or_null("/root/AIServerManager")
	if server == null:
		print("      SALTATO: autoload AIServerManager assente")
		return
	if not server.is_server_ready():
		await server.server_started
	var engine: OraculusEngine = server.get_node("OraculusEngine")
	if engine.is_using_remote() or not engine.local.is_available():
		print("      SALTATO: backend locale non disponibile (", engine.local.last_error, ")")
		return
	print("      modello: ", engine.local.model_path.get_file())

	var sospette: Array[String] = []
	var ripieghi := 0
	var richieste := []
	for r in REGIE:
		richieste.append({"npc_name": r[0], "direction": r[1]})
	for d in DOMANDE:
		richieste.append({"npc_name": d[0], "player_input": d[1]})

	for payload: Dictionary in richieste:
		engine.reset_memory()
		payload["hostility"] = 70
		payload["friendship"] = 20
		payload["language"] = "italiano"
		var parziali: Array[String] = []
		var res: Dictionary = await server.make_request("chat", payload,
			func(t: String) -> void: parziali.append(t))
		var finale := String(res.get("response", ""))
		var sorgente := String(res.get("source", "?"))
		print("      %-9s [%s] %s" % [payload["npc_name"], sorgente, finale])
		if sorgente != "llama":
			ripieghi += 1
		for t in parziali + [finale]:
			var motivo := _sospetta(t)
			if not motivo.is_empty():
				sospette.append("%s «%s» (%s)" % [payload["npc_name"], t, motivo])
				break

	_check("nessuna battuta, finale o parziale, suona da assistente", sospette.is_empty(),
		" | ".join(sospette))
	_check("il modello risponde in personaggio (al massimo un ripiego su %d)" % richieste.size(),
		ripieghi <= 1, str(ripieghi))


func _sospetta(testo: String) -> String:
	var t := testo.to_lower()
	for s in SOSPETTI:
		if t.contains(s):
			return s
	return ""
