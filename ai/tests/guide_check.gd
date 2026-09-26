# ============================================================================
# Collaudo della guida del menu (ai/oraculus_guide.gd) e dei suoni
# dell'interfaccia (oraculus/ui_sounds.gd).
#
#  [1] le schede: tutte e cinque le lingue, id unici, e ogni carattere delle
#      risposte presente nel font del menu (niente quadratini);
#  [2] il riconoscimento: domande vere in cinque lingue -> la scheda giusta;
#      domande fuori dalle schede -> nessuna scheda (tocca al modello);
#  [3] i tempi: una risposta dalle schede in meno di un millisecondo;
#  [4] il menu vero: la risposta piu' lunga di ogni lingua sta nel riquadro
#      senza coprire il campo in cui si scrive, e l'invio suona;
#  [5] i suoni: tutti caricati; un pulsante suona, un TouchScreenButton
#      senza effetti no;
#  [6] domande formulate in altro modo (quelle su cui il modello da 1B
#      sbagliava): la scheda giusta con le sole parole chiave, e "non so"
#      per quelle fuori tema.
#
#   godot --headless --path . res://ai/tests/guide_check.tscn
# ============================================================================
extends Node

const LINGUE := ["italiano", "inglese", "francese", "spagnolo", "tedesco"]
const FONT_MENU := "res://oraculus/thirdparty/kenney/fonts/Fonts/Kenney Pixel.ttf"

## [domanda, scheda attesa]
const CASI := [
	["ciao", "saluto"], ["Hello!", "saluto"], ["cosa posso chiederti?", "saluto"],
	["grazie mille", "grazie"], ["merci", "grazie"],
	["Che tipo di gioco è Oraculus?", "gioco"], ["What kind of game is this?", "gioco"],
	["Raccontami la storia", "storia"], ["What's the lore?", "storia"], ["Quelle est l'histoire ?", "storia"],
	["¿Cuál es la historia?", "storia"], ["Was ist die Geschichte?", "storia"], ["Cosa è successo alla famiglia nobile?", "storia"],
	["Chi è l'Oracolo?", "oracolo"], ["Who is the Oracle?", "oracolo"], ["¿Quién es el Oráculo?", "oracolo"],
	["Perché c'è una guerra?", "guerra"], ["What is the Holy Cross army?", "guerra"],
	["Chi sono io?", "protagonista"], ["Who am I?", "protagonista"], ["Wer bin ich?", "protagonista"],
	["Quali spiriti ci sono?", "spiriti"], ["Which characters are there?", "spiriti"],
	["Chi è Levias?", "levias"], ["Dove si trova Levias?", "levias"], ["Who is Smirne Bombo?", "smirne"],
	["Parlami di Rigon", "rigon"], ["Qui est Larry ?", "larry"], ["¿Quién es Malakai?", "malakai"],
	["Wer ist Kalessi?", "kalessi"], ["Chi è il mago?", "allemar"], ["Who is Gruko?", "orchi"],
	["Qual è l'obiettivo del gioco?", "obiettivo"], ["How do I win?", "obiettivo"], ["Quel est le but du jeu ?", "obiettivo"],
	["¿Cuál es el objetivo?", "obiettivo"], ["Was ist das Ziel?", "obiettivo"], ["Come esco dal castello?", "obiettivo"],
	["Quali sono i percorsi?", "percorsi"], ["What are the three paths?", "percorsi"],
	["Quali missioni ci sono?", "missioni"], ["Any quests?", "missioni"],
	["Cosa devo fare?", "cosa_fare"], ["What should I do first?", "cosa_fare"], ["Que dois-je faire ?", "cosa_fare"],
	["¿Qué debo hacer?", "cosa_fare"], ["Was soll ich tun?", "cosa_fare"], ["Sono bloccato, un consiglio?", "cosa_fare"],
	["Com'è fatto il castello?", "mappa"], ["Show me the map", "mappa"], ["Quanti piani ha il castello?", "mappa"],
	["Come apro le porte?", "porte"], ["How do riddles work?", "porte"], ["Comment ouvrir une porte ?", "porte"],
	["Come funziona il puzzle?", "minigiochi"], ["How does the light minigame work?", "minigiochi"],
	["Quali sono i comandi?", "comandi"], ["What are the controls?", "comandi"], ["Quelles sont les commandes ?", "comandi"],
	["¿Cuáles son los controles?", "comandi"], ["Wie ist die Steuerung?", "comandi"], ["Si può giocare col gamepad?", "comandi"],
	["Come salto?", "movimento"], ["How do I jump?", "movimento"], ["Come faccio a scivolare?", "movimento"],
	["Come corro?", "movimento"], ["Wie klettere ich?", "movimento"],
	["Come attacco?", "combattimento"], ["How do I parry?", "combattimento"], ["Comment attaquer ?", "combattimento"],
	["Come parlo con gli spiriti?", "dialogo"], ["How do I talk to someone?", "dialogo"], ["¿Cómo hablo con ellos?", "dialogo"],
	["Come uso le pozioni?", "inventario"], ["How does the inventory work?", "inventario"], ["A cosa serve la pergamena?", "inventario"],
	["Cosa succede se muoio?", "salute"], ["Can I save the game?", "salute"], ["Come mi curo?", "salute"],
	["Come metto in pausa?", "opzioni"], ["How do I change the language?", "opzioni"], ["Wie stelle ich die Lautstärke ein?", "opzioni"],
	# Parole corte che in un'altra lingua sono tutt'altro: l'articolo tedesco
	# "die", il possessivo francese "ton", il verbo spagnolo "son".
	["What happens if I die?", "salute"], ["Was passiert, wenn ich sterbe?", "salute"],
	["Quel est ton conseil ?", "cosa_fare"], ["¿Cuáles son los controles?", "comandi"],
	# Quaranta domande scritte dopo, senza guardare le chiavi: al primo giro
	# ne riconosceva 32; i buchi sono stati chiusi e restano qui come prova.
	["Di cosa parla il gioco?", "gioco"], ["Chi abitava il castello prima?", "storia"],
	["Perché sono qui?", "protagonista"], ["Chi mi odia?", "spiriti"],
	["Come faccio a farmi aiutare dagli spiriti?", "dialogo"], ["Come si apre l'inventario?", "inventario"],
	["Che tasto per parare?", "combattimento"], ["Dov'è Allemar?", "allemar"],
	["Come si risolve un indovinello?", "porte"], ["Cosa fa la pozione?", "inventario"],
	["Come cambio lingua?", "opzioni"], ["Come si usa lo scroll?", "inventario"],
	["Cosa c'è sotto il castello?", "mappa"], ["Come arrivo al primo piano?", "mappa"],
	["What does Kalessi want?", "kalessi"], ["Where can I find Larry?", "larry"],
	["What happens if I attack a spirit?", "combattimento"], ["How do I open the inventory?", "inventario"],
	["What is the Claristorium?", "mappa"], ["How many floors are there?", "mappa"],
	["Who kidnapped the Oracle?", "oracolo"], ["Why do the spirits hate me?", "spiriti"],
	["Can I be friends with the spirits?", "dialogo"], ["How do I get the key for the puzzle?", "minigiochi"],
	["How do I go down the stairs?", "movimento"], ["What's behind the locked doors?", "porte"],
	["Comment parler aux esprits ?", "dialogo"], ["Où est la sortie ?", "obiettivo"],
	["Qui est Allemar ?", "allemar"], ["Comment sauter ?", "movimento"],
	["¿Cómo abro las puertas?", "porte"], ["¿Quién es Levias?", "levias"],
	["¿Qué pasa si muero?", "salute"], ["¿Cómo uso los objetos?", "inventario"],
	["Wie öffne ich Türen?", "porte"], ["Wer ist Rigon?", "rigon"],
	["Wie greife ich an?", "combattimento"], ["Was muss ich machen?", "cosa_fare"],
	["Wie rede ich mit Geistern?", "dialogo"], ["Gibt es eine Karte?", "mappa"],
]

## Nessuna scheda: queste vanno al modello.
const NON_COPERTE := ["Quanto dura il gioco?", "Posso giocare con un amico?", "Is the game scary?",
	"Est-ce difficile ?", "¿Es difícil?", "Ist das schwer?", "Chi ha disegnato la grafica?"]

## Per [6]: [domanda, scheda attesa]. "" vuol dire fuori dalle schede: il
## menu deve dire che non sa.
const PARAFRASI := [
	["Cosa sta succedendo in questo posto?", "storia"], ["Why is everything in ruins here?", "storia"],
	["Dove vado adesso?", "cosa_fare"], ["I'm lost, where should I go?", "cosa_fare"],
	["¿Adónde voy ahora?", "cosa_fare"], ["Wohin jetzt?", "cosa_fare"],
	["Qual è il senso del gioco?", "obiettivo"], ["How does it end?", "obiettivo"],
	["Come vado più veloce?", "movimento"], ["How can I get higher up?", "movimento"],
	["Come mi difendo?", "combattimento"],
	["Who is the old man they took away?", "oracolo"], ["Chi è il demone all'ingresso?", "levias"],
	["Qui est le démon de l'entrée ?", "levias"], ["Who is the woman with snakes for hair?", "kalessi"],
	["Chi è il prigioniero?", "rigon"], ["Who is the huge funny guy?", "larry"],
	["Chi è l'unico umano?", "allemar"], ["Who is the chief of the brutes?", "orchi"],
	["Posso giocare con un amico?", ""], ["How long is the game?", ""], ["Wie lange dauert das Spiel?", ""],
	["Chi ha fatto questo gioco?", ""], ["What's the weather like today?", ""],
]
var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DELLA GUIDA DEL MENU")
	print("=".repeat(70))
	_test_schede()
	_test_riconoscimento()
	_test_tempi()
	await _test_menu()
	await _test_suoni()
	_test_parafrasi()
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


func _test_schede() -> void:
	print("  [1] schede")
	var mancanti: Array[String] = []
	var id_visti := {}
	for s in OraculusGuide.SCHEDE:
		id_visti[s["id"]] = int(id_visti.get(s["id"], 0)) + 1
		for l in LINGUE:
			if String(s.get(l, "")).strip_edges().is_empty():
				mancanti.append("%s/%s" % [s["id"], l])
	_check("ogni scheda ha tutte e cinque le lingue", mancanti.is_empty(), ", ".join(mancanti))
	var doppi := id_visti.keys().filter(func(k): return id_visti[k] > 1)
	_check("gli id delle schede sono unici", doppi.is_empty(), str(doppi))
	for l in LINGUE:
		_check("NON_SO ha la lingua " + l, OraculusGuide.NON_SO.has(l))

	var font: FontFile = load(FONT_MENU)
	var assenti := {}
	for s in OraculusGuide.SCHEDE:
		for l in LINGUE:
			for c in String(s[l]):
				if not font.has_char(c.unicode_at(0)):
					assenti[c] = true
	for l in LINGUE:
		for c in OraculusGuide.non_so(l):
			if not font.has_char(c.unicode_at(0)):
				assenti[c] = true
	_check("ogni carattere delle risposte esiste nel font del menu", assenti.is_empty(),
		" ".join(PackedStringArray(assenti.keys())))


func _test_riconoscimento() -> void:
	print("  [2] riconoscimento")
	var sbagliate: Array[String] = []
	for caso in CASI:
		var trovati := OraculusGuide.argomenti(caso[0])
		if trovati.is_empty() or trovati[0] != caso[1]:
			sbagliate.append("«%s» -> %s (atteso %s)" % [caso[0], str(trovati), caso[1]])
	_check("%d domande in cinque lingue -> la scheda giusta" % CASI.size(), sbagliate.is_empty(),
		" | ".join(sbagliate))
	var pescate: Array[String] = []
	for d in NON_COPERTE:
		var trovati := OraculusGuide.argomenti(d)
		if not trovati.is_empty():
			pescate.append("«%s» -> %s" % [d, str(trovati)])
	_check("le domande fuori dalle schede vanno al modello", pescate.is_empty(), " | ".join(pescate))
	_check("la risposta e' nella lingua scelta",
		OraculusGuide.risposta("Who is Levias?", "italiano").begins_with("Levias è un demone")
		and OraculusGuide.risposta("Chi è Levias?", "tedesco").begins_with("Levias ist"))
	var doppia := OraculusGuide.argomenti("come salto e come attacco?")
	_check("due argomenti con lo stesso peso: due schede", doppia.size() == 2, str(doppia))


func _test_tempi() -> void:
	print("  [3] tempi")
	var t0 := Time.get_ticks_usec()
	var n := 0
	for giro in 10:
		for caso in CASI:
			OraculusGuide.risposta(caso[0], "italiano")
			n += 1
	var medio := float(Time.get_ticks_usec() - t0) / n
	print("      risposta dalle schede: %.0f µs in media" % medio)
	_check("una risposta dalle schede in meno di un millisecondo", medio < 1000.0, "%.0f µs" % medio)


func _test_menu() -> void:
	print("  [4] menu")
	var menu: Node = load("res://oraculus/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var riquadro: Label = menu.answer_text_edit
	var campo: Control = menu.question_text_edit
	_check("il menu si apre con il benvenuto nella lingua scelta",
		riquadro.text == OraculusGuide.benvenuto(GameState.ai_language), riquadro.text)
	var fuori: Array[String] = []
	for l in LINGUE:
		var piu_lunga := ""
		for s in OraculusGuide.SCHEDE:
			if String(s[l]).length() > piu_lunga.length():
				piu_lunga = s[l]
		menu._mostra(piu_lunga)
		await get_tree().process_frame
		var fondo := riquadro.get_global_rect().end.y
		if fondo > campo.get_global_rect().position.y:
			fuori.append("%s: fondo %.0f > campo %.0f (font %d)" % [l, fondo, campo.get_global_rect().position.y,
				riquadro.get_theme_font_size("font_size")])
	_check("la risposta piu' lunga di ogni lingua non copre il campo di testo", fuori.is_empty(), " | ".join(fuori))
	menu._mostra("Ciao.")
	_check("una risposta corta torna al carattere pieno",
		riquadro.get_theme_font_size("font_size") == menu.RISPOSTA_FONT_MAX)

	var suoni := get_node_or_null("/root/UiSounds")
	_check("l'autoload UiSounds c'e'", suoni != null)
	if suoni != null:
		suoni._send.stop()
		GameState.ai_language = "italiano"
		menu._process_player_input("Chi è Levias?")
		_check("dal menu l'invio suona", suoni._send.playing)
		_check("e la risposta arriva subito dalle schede",
			String(riquadro.text).begins_with("Levias è un demone"), riquadro.text)
		menu._process_player_input("Quanto dura il gioco?")
		_check("una domanda fuori tema riceve subito il non so",
			riquadro.text == OraculusGuide.non_so("italiano"), riquadro.text)
	menu.queue_free()
	await get_tree().process_frame


func _test_suoni() -> void:
	print("  [5] suoni")
	var suoni := get_node_or_null("/root/UiSounds")
	if suoni == null:
		return
	var mancanti: Array[String] = []
	for nome in ["_click", "_send", "_pickup", "_use", "_door"]:
		if suoni.get(nome).stream == null:
			mancanti.append(nome)
	_check("i suoni (clic, invio, raccolta, uso, porta) sono caricati", mancanti.is_empty(), ", ".join(mancanti))
	_check("i suoni vanno sul bus SFX", suoni._click.bus == &"SFX")
	var b := Button.new()
	add_child(b)
	await get_tree().process_frame
	suoni._click.stop()
	b.pressed.emit()
	_check("un pulsante suona", suoni._click.playing)

	var t := TouchScreenButton.new()
	add_child(t)
	await get_tree().process_frame
	suoni._click.stop()
	t.pressed.emit()
	_check("un TouchScreenButton che non fa niente non suona", not suoni._click.playing)
	t.pressed.connect(func() -> void: pass)
	t.pressed.emit()
	_check("un TouchScreenButton che fa qualcosa suona", suoni._click.playing)
	suoni._click.stop()
	t.action = "move_left"
	t.pressed.emit()
	_check("un tasto di movimento a schermo non suona", not suoni._click.playing)
	b.queue_free()
	t.queue_free()


func _test_parafrasi() -> void:
	print("  [6] domande formulate in altro modo")
	var sbagliate: Array[String] = []
	for caso in PARAFRASI:
		var trovati := OraculusGuide.argomenti(caso[0])
		var primo := "" if trovati.is_empty() else trovati[0]
		if primo != caso[1]:
			sbagliate.append("«%s» -> %s (atteso %s)" % [caso[0], str(trovati), caso[1] if caso[1] else "nessuna"])
	_check("%d domande riformulate -> la scheda giusta, o nessuna se fuori tema" % PARAFRASI.size(),
		sbagliate.is_empty(), " | ".join(sbagliate))
