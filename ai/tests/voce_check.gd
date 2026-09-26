# ============================================================================
# Collaudo della voce degli NPC (oraculus/NPC/voce_sintetica.gd e
# voce_parlante.gd).
#
#  [1] i campioni: ogni lettera ha il suo, breve e non muto; accenti come la
#      lettera base; punteggiatura, spazi e cifre muti;
#  [2] i profili: ogni NPC delle scene e il Tutorial hanno il loro tono;
#  [3] la casella che parla: il testo compare a poco a poco, una voce per
#      lettera, silenzio per azioni fra asterischi e puntini, lo streaming
#      prosegue senza ricominciare, una casella nascosta non parla;
#  [4] un NPC vero (larry.tscn): la sua casella ha la voce di Larry;
#  [5] il menu: la risposta compare e parla con la voce del Tutorial, e
#      ricomincia da capo anche se la risposta e' la stessa.
#
#   godot --headless --path . res://ai/tests/voce_check.tscn
# ============================================================================
extends Node

## npc_name delle scene degli NPC (vedi oraculus/NPC/*.gd).
const NOMI_SCENE := ["Rigon", "Levias", "SmirBombo", "Kalessi", "Malakai", "Allemar", "Orco", "Larry"]

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DELLA VOCE DEGLI NPC")
	print("=".repeat(70))
	_test_campioni()
	_test_profili()
	await _test_casella()
	await _test_npc()
	await _test_menu()
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


func _durata(w: AudioStreamWAV) -> float:
	return w.data.size() / 2.0 / w.mix_rate


func _picco(w: AudioStreamWAV) -> float:
	var p := 0
	for i in range(0, w.data.size(), 2):
		p = maxi(p, absi(w.data.decode_s16(i)))
	return p / 32767.0


func _test_campioni() -> void:
	print("  [1] campioni")
	var t0 := Time.get_ticks_msec()
	var problemi: Array[String] = []
	for c in "abcdefghijklmnopqrstuvwxyz":
		var w := VoceSintetica.campione(c)
		if w == null:
			problemi.append(c + ": manca")
			continue
		var d := _durata(w)
		if d < 0.03 or d > 0.12:
			problemi.append("%s: %.3f s" % [c, d])
		if _picco(w) < 0.5:
			problemi.append("%s: quasi muto" % c)
	print("      26 lettere sintetizzate in %d ms" % (Time.get_ticks_msec() - t0))
	_check("ogni lettera ha un campione breve e udibile", problemi.is_empty(), ", ".join(problemi))
	_check("le lettere accentate suonano come la lettera base",
		VoceSintetica.campione("È") == VoceSintetica.campione("e") and VoceSintetica.campione("ñ") == VoceSintetica.campione("n"))
	var muti := true
	for c in [" ", ".", ",", "!", "?", "*", "3", "'", "-"]:
		if VoceSintetica.campione(c) != null:
			muti = false
	_check("spazi, punteggiatura e cifre non suonano", muti)
	_check("vocali e consonanti hanno campioni diversi",
		VoceSintetica.campione("a").data != VoceSintetica.campione("s").data
		and VoceSintetica.campione("a").data != VoceSintetica.campione("o").data)


func _test_profili() -> void:
	print("  [2] profili")
	var mancanti: Array[String] = []
	for nome in NOMI_SCENE + ["Tutorial"]:
		if not VoceSintetica.PROFILI.has(nome):
			mancanti.append(nome)
	_check("ogni NPC delle scene e il Tutorial hanno una voce", mancanti.is_empty(), ", ".join(mancanti))
	var toni := {}
	for nome in NOMI_SCENE + ["Tutorial"]:
		toni[VoceSintetica.PROFILI[nome]["tono"]] = true
	_check("le voci hanno toni diversi", toni.size() == NOMI_SCENE.size() + 1, str(toni.keys()))


func _nuova_casella(profilo: Dictionary) -> Array:
	var l := Label.new()
	add_child(l)
	var v := VoceParlante.new()
	add_child(v)
	v.configura(l, profilo, true)
	return [l, v]


func _aspetta_fine(v: VoceParlante, massimo: float = 5.0) -> void:
	var t := 0.0
	while v.sta_parlando() and t < massimo:
		await get_tree().process_frame
		t += get_process_delta_time()


func _test_casella() -> void:
	print("  [3] casella che parla")
	var coppia := _nuova_casella(VoceSintetica.PROFILO_BASE)
	var l: Label = coppia[0]
	var v: VoceParlante = coppia[1]

	v.dici("Ciao, cavaliere.")
	await get_tree().process_frame
	_check("il testo compare a poco a poco", v.sta_parlando() and l.visible_characters < l.text.length(),
		str(l.visible_characters))
	await _aspetta_fine(v)
	_check("alla fine si vede tutto", l.visible_characters == -1 and l.text == "Ciao, cavaliere.")
	_check("una voce per lettera, spazi e punteggiatura esclusi (%d)" % v.pronunciate,
		v.pronunciate >= 8 and v.pronunciate <= 14, str(v.pronunciate))

	v.pronunciate = 0
	v.dici("*sospira*")
	await _aspetta_fine(v)
	_check("un'azione fra asterischi compare in silenzio", v.pronunciate == 0, str(v.pronunciate))
	v.dici("...")
	await _aspetta_fine(v)
	_check("i puntini d'attesa non parlano", v.pronunciate == 0, str(v.pronunciate))

	v.dici("Sono")
	await _aspetta_fine(v)
	var prima := v.pronunciate
	v.dici("Sono Levias.")
	_check("lo streaming prosegue da dove era arrivato", l.visible_characters >= 4, str(l.visible_characters))
	await _aspetta_fine(v)
	_check("e le lettere gia' dette non si ripetono", v.pronunciate - prima <= 6, str(v.pronunciate - prima))

	v.pronunciate = 0
	v.dici("Sono Levias.")
	_check("lo stesso testo di nuovo non si ripete", not v.sta_parlando() and v.pronunciate == 0)
	v.dici("Sono Larry!")
	_check("un testo diverso riparte dal primo carattere diverso (\"Sono L\")", l.visible_characters == 6, str(l.visible_characters))

	l.visible = false
	v.pronunciate = 0
	v.dici("Nessuno mi vede.")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("una casella nascosta mostra tutto e non parla", not v.sta_parlando() and v.pronunciate == 0)
	l.queue_free()
	v.queue_free()


func _test_npc() -> void:
	print("  [4] NPC vero")
	var larry: Node = load("res://oraculus/NPC/larry.tscn").instantiate()
	add_child(larry)
	await get_tree().process_frame
	var casella: Label = larry.get_node("Dialogue")
	var v := casella.get_node_or_null("Voce") as VoceParlante
	_check("la casella dell'NPC ha la voce", v != null)
	if v != null:
		_check("con il tono di Larry", is_equal_approx(v._tono, VoceSintetica.PROFILI["Larry"]["tono"]), str(v._tono))
		_check("e un player posizionale che si sente solo da vicino",
			v._player is AudioStreamPlayer2D and v._player.get_parent() == casella
			and is_equal_approx(v._player.max_distance, VoceParlante.DISTANZA_MAX))
		v.pronunciate = 0
		casella.show_text("Sono Larry, il gigante.")
		await _aspetta_fine(v)
		_check("show_text() fa parlare l'NPC", v.pronunciate > 0 and casella.text == "Sono Larry, il gigante.",
			str(v.pronunciate))
	larry.queue_free()
	await get_tree().process_frame


func _test_menu() -> void:
	print("  [5] menu")
	var menu: Node = load("res://oraculus/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var v: VoceParlante = menu.get_node("Voce")
	_check("il menu ha la voce del Tutorial", is_equal_approx(v._tono, VoceSintetica.PROFILI["Tutorial"]["tono"]))
	_check("il benvenuto compare a poco a poco", v.sta_parlando())
	await _aspetta_fine(v, 8.0)
	_check("e parla", v.pronunciate > 10, str(v.pronunciate))
	GameState.ai_language = "italiano"
	menu._process_player_input("Chi è Levias?")
	await _aspetta_fine(v, 15.0)
	var dopo_una := v.pronunciate
	menu._process_player_input("Chi è Levias?")
	_check("la stessa risposta di nuovo ricomincia da capo", v.sta_parlando() and menu.answer_text_edit.visible_characters < 5)
	await _aspetta_fine(v, 15.0)
	_check("e parla di nuovo", v.pronunciate > dopo_una)
	menu.queue_free()
	await get_tree().process_frame
