# ============================================================================
# Fa "parlare" una Label: il testo compare una lettera alla volta, e ogni
# lettera si sente con la voce sintetica dell'NPC (VoceSintetica), come nelle
# caselle di dialogo di Animal Crossing.
#
#  - Punti e virgole fanno una pausa; spazi, punteggiatura e cifre non
#    suonano; le azioni fra asterischi ("*sospira*") compaiono in silenzio.
#  - Se il testo nuovo continua quello vecchio (la battuta che arriva in
#    streaming, token dopo token) la comparsa prosegue da dove era, senza
#    ricominciare ne' ripetere la voce. Se cambia, riparte dal primo carattere
#    diverso.
#  - La Label e' impaginata sul testo intero fin da subito
#    (VC_CHARS_AFTER_SHAPING): le parole non saltano da una riga all'altra
#    mentre compaiono, e la casella ha gia' la sua misura finale.
#  - Una casella nascosta non parla: il testo le compare tutto, in silenzio.
# ============================================================================
class_name VoceParlante
extends Node

## Pausa dopo . ! ? e a capo, e dopo , ; : (in multipli di una lettera).
const PAUSA_FRASE := 6.0
const PAUSA_VIRGOLA := 3.0
## Al massimo un suono ogni tanti secondi: a velocita' alte si salta qualche
## lettera invece di impastare i suoni.
const INTERVALLO_MIN := 0.03
## Oltre questa distanza (pixel del mondo) un NPC non si sente: al caricamento
## della scena parlano tutti insieme, ma si devono sentire solo i vicini.
const DISTANZA_MAX := 450.0
const VOLUME_DB := -6.0
const BUS := &"SFX"

## Lettere pronunciate finora: per i collaudi.
var pronunciate := 0

var _label: Label
var _tono := 1.0
var _velocita := 30.0
var _vibrato := 0.05
var _player: Node
var _playback: AudioStreamPlaybackPolyphonic
var _attesa := 0.0
var _dal_suono := 1.0
## Dopo l'ultima lettera il player resta acceso il tempo dell'ultimo suono,
## poi si spegne: decine di NPC con un flusso aperto per niente pesano.
var _coda := 0.0
var _rng := RandomNumberGenerator.new()


## posizionale: true per gli NPC (la voce viene dalla casella e si attenua
## con la distanza), false per il menu.
func configura(label: Label, profilo: Dictionary, posizionale: bool) -> void:
	_label = label
	_tono = float(profilo.get("tono", 1.0))
	_velocita = float(profilo.get("velocita", 30.0))
	_vibrato = float(profilo.get("vibrato", 0.05))
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	var flusso := AudioStreamPolyphonic.new()
	flusso.polyphony = 4
	if posizionale:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = DISTANZA_MAX
		p.attenuation = 1.5
		p.stream = flusso
		p.volume_db = VOLUME_DB
		p.bus = _bus()
		# Figlio diretto della Label, non di questo nodo: un Node2D sotto un
		# Node semplice perderebbe la posizione dell'NPC.
		label.add_child(p)
		_player = p
	else:
		var p := AudioStreamPlayer.new()
		p.stream = flusso
		p.volume_db = VOLUME_DB
		p.bus = _bus()
		add_child(p)
		_player = p
	set_process(false)


## Mostra il testo e lo fa pronunciare, lettera per lettera. da_capo=true
## ricomincia dalla prima lettera anche se il testo e' uguale a quello di
## prima: per il menu, dove ogni risposta e' una frase nuova.
func dici(testo: String, da_capo: bool = false) -> void:
	var vecchio := _label.text
	var gia := _label.visible_characters
	if gia < 0:
		gia = vecchio.length()
	_label.text = testo
	var da := 0 if da_capo else mini(gia, _prefisso_comune(vecchio, testo))
	if da >= testo.length():
		_label.visible_characters = -1
		return
	_label.visible_characters = da
	_attesa = 0.0
	_coda = 0.0
	set_process(true)


## Tutto il testo subito, senza voce.
func mostra_tutto() -> void:
	_label.visible_characters = -1


func sta_parlando() -> bool:
	return _label.visible_characters >= 0


func _process(delta: float) -> void:
	_dal_suono += delta
	if not sta_parlando():
		# Finito di scrivere: si aspetta che l'ultimo suono finisca.
		_coda -= delta
		if _coda <= 0.0:
			if _player.playing:
				_player.stop()
			_playback = null
			set_process(false)
		return
	if not _label.is_visible_in_tree():
		mostra_tutto()
		return
	_attesa -= delta
	var testo := _label.text
	while _attesa <= 0.0 and sta_parlando():
		var i := _label.visible_characters
		if i >= testo.length():
			mostra_tutto()
			break
		var c := testo[i]
		_label.visible_characters = i + 1 if i + 1 < testo.length() else -1
		_attesa += _durata(c)
		if _dal_suono >= INTERVALLO_MIN and not _fra_asterischi(testo, i):
			var campione := VoceSintetica.campione(c)
			if campione != null:
				_suona(campione)
	if not sta_parlando():
		_coda = 0.4


func _suona(campione: AudioStreamWAV) -> void:
	if _playback == null or not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	var tono := _tono * (1.0 + _rng.randf_range(-_vibrato, _vibrato))
	_playback.play_stream(campione, 0.0, 0.0, tono)
	_dal_suono = 0.0
	pronunciate += 1


func _durata(c: String) -> float:
	var una := 1.0 / maxf(_velocita, 1.0)
	if c in [".", "!", "?", "\n"]:
		return una * PAUSA_FRASE
	if c in [",", ";", ":"]:
		return una * PAUSA_VIRGOLA
	return una


static func _fra_asterischi(testo: String, i: int) -> bool:
	return testo.substr(0, i).count("*") % 2 == 1 or testo[i] == "*"


static func _prefisso_comune(a: String, b: String) -> int:
	var n := mini(a.length(), b.length())
	for i in n:
		if a[i] != b[i]:
			return i
	return n


static func _bus() -> StringName:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
