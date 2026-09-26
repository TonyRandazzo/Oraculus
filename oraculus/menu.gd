extends Control

## Il menu risponde alle domande del giocatore su lore, comandi, obiettivi,
## struttura del castello e cosa fare, con le schede di OraculusGuide:
## risposte scritte a mano in tutte le lingue del menu, pronte all'istante e
## sempre corrette. Se nessuna scheda corrisponde lo dice, ed elenca cosa si
## puo' chiedere. Il modello qui non c'e': vedi ai/oraculus_guide.gd.

@onready var question_text_edit = $Label
@onready var answer_text_edit: Label = $Dialogue
@onready var language_select: OptionButton = $LanguageSelect

## Il riquadro delle risposte cresce verso il basso con il testo: oltre questa
## altezza (pixel del Label, prima della sua scala 0.5) coprirebbe il campo in
## cui si scrive, quindi il carattere si rimpicciolisce.
const RISPOSTA_ALTEZZA_MAX := 540.0
const RISPOSTA_FONT_MAX := 50
const RISPOSTA_FONT_MIN := 24
## Prima di chiudere il gioco si aspetta la fine del clic del pulsante.
const ATTESA_USCITA := 0.3

## La larghezza del riquadro com'e' nella scena: _mostra() lo riporta a
## questa larghezza e all'altezza minima per il testo.
var _larghezza_risposta: float
## La risposta compare lettera per lettera con la voce del Tutorial.
var _voce: VoceParlante

func _ready() -> void:
	_larghezza_risposta = answer_text_edit.size.x
	_voce = VoceParlante.new()
	_voce.name = "Voce"
	add_child(_voce)
	_voce.configura(answer_text_edit, VoceSintetica.profilo("Tutorial"), false)
	if question_text_edit is LineEdit:
		question_text_edit.text_submitted.connect(_on_text_submitted)
	else:
		question_text_edit.gui_input.connect(_on_question_gui_input)
		question_text_edit.focus_exited.connect(_on_focus_exited)
	_mostra(OraculusGuide.benvenuto(GameState.ai_language))
	_setup_language_select()
	# La musica sul bus "Music": la regola il cursore Musica delle Opzioni.
	var musica := get_node_or_null("Music2")
	if musica is AudioStreamPlayer:
		musica.bus = &"Music"
	# Sul Web il gioco non si puo' chiudere.
	var esci := get_node_or_null("Esci")
	if esci != null and OS.has_feature("web"):
		esci.visible = false

## La tendina mostra le sigle (EN, IT, ...) ma quello che viaggia fino al
## prompt e' il nome esteso: e' la stringa che finisce in "Always speak in
## <lingua>", quindi deve restare quella che il motore conosce.
func _setup_language_select() -> void:
	if language_select == null:
		return
	language_select.clear()
	for voce in GameState.LANGUAGES:
		language_select.add_item(String(voce["code"]))
	var i := GameState.language_index()
	language_select.select(i if i >= 0 else 0)

func _on_language_selected(indice: int) -> void:
	if indice < 0 or indice >= GameState.LANGUAGES.size():
		return
	GameState.set_ai_language(String(GameState.LANGUAGES[indice]["name"]))
	_mostra(OraculusGuide.benvenuto(GameState.ai_language))

func _on_question_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		question_text_edit.accept_event()
		_process_player_input(question_text_edit.text)

func _on_text_submitted(text: String) -> void:
	_process_player_input(text)

func _on_text_changed(text: String) -> void:
	pass

func _on_focus_exited() -> void:
	if question_text_edit.text.strip_edges() != "":
		_process_player_input(question_text_edit.text)

func _process_player_input(text: String) -> void:
	var domanda := text.strip_edges()
	if domanda.is_empty():
		return
	question_text_edit.text = ""
	var suoni := get_node_or_null("/root/UiSounds")
	if suoni != null:
		suoni.play_send()
	var lingua: String = GameState.ai_language
	var risposta := OraculusGuide.risposta(domanda, lingua)
	_mostra(risposta if not risposta.is_empty() else OraculusGuide.non_so(lingua))

## Scrive la risposta, pronunciata lettera per lettera, e la fa stare nel
## riquadro: piu' e' lunga, piu' piccolo il carattere, fino a RISPOSTA_FONT_MIN.
func _mostra(testo: String) -> void:
	# La Label e' impaginata sul testo intero anche mentre compare, quindi la
	# misura qui sotto vale gia' per la risposta completa.
	_voce.dici(testo, true)
	var dimensione := RISPOSTA_FONT_MAX
	answer_text_edit.add_theme_font_size_override("font_size", dimensione)
	while dimensione > RISPOSTA_FONT_MIN and answer_text_edit.get_minimum_size().y > RISPOSTA_ALTEZZA_MAX:
		dimensione -= 2
		answer_text_edit.add_theme_font_size_override("font_size", dimensione)
	# Il Label cresce con il testo ma non si restringe da solo. Non
	# reset_size(): con l'a capo automatico la larghezza minima e' 1 pixel, e
	# il testo andrebbe a capo a ogni lettera.
	answer_text_edit.size = Vector2(_larghezza_risposta, 0)

## Start, al rilascio del pulsante: dissolvenza a nero, main.tscn, e
## dissolvenza dal nero alla scena (vedi TransizioneScena).
func _on_start_pressed() -> void:
	TransizioneScena.vai_a(get_tree(), "res://oraculus/main.tscn")

## Il pulsante in alto a sinistra: chiude il gioco, dopo il clic.
func _on_esci_pressed() -> void:
	await get_tree().create_timer(ATTESA_USCITA).timeout
	get_tree().quit()

func _on_options_pressed() -> void:
	$Title/Options2.visible = true
	get_tree().paused = true
