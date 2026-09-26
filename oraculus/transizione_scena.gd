# ============================================================================
# Dissolvenza a nero fra due scene: lo schermo si scurisce, la scena cambia a
# schermo nero, poi il nero sfuma e compare la scena nuova.
#
#   TransizioneScena.vai_a(get_tree(), "res://oraculus/main.tscn")
#
# Il velo nero sta in un CanvasLayer figlio diretto della radice, non della
# scena: change_scene_to_file() libera solo la scena corrente, quindi il velo
# resta sopra mentre la scena nuova (main.tscn e' grande) viene caricata, e se
# ne va da solo a dissolvenza finita. Finche' c'e' blocca i clic, cosi' non si
# preme due volte Start.
# ============================================================================
class_name TransizioneScena
extends CanvasLayer

const DURATA_USCITA := 0.6
const DURATA_ENTRATA := 0.8

static var _in_corso := false

var _scena := ""
var _velo: ColorRect


## Avvia la dissolvenza verso la scena. Se una dissolvenza e' gia' in corso
## non fa niente.
static func vai_a(albero: SceneTree, scena: String) -> void:
	if _in_corso:
		return
	_in_corso = true
	var t := TransizioneScena.new()
	t._scena = scena
	# Differita: la chiamata arriva spesso da un pulsante, cioe' mentre la
	# scena sta ancora gestendo l'input.
	albero.root.add_child.call_deferred(t)


static func in_corso() -> bool:
	return _in_corso


func _init() -> void:
	name = "TransizioneScena"
	layer = 128
	# Anche a gioco in pausa (Restart ed Exit partono dalle Opzioni).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_velo)


func _ready() -> void:
	var uscita := create_tween()
	uscita.tween_property(_velo, "color:a", 1.0, DURATA_USCITA)
	await uscita.finished
	get_tree().change_scene_to_file(_scena)
	# La scena nuova entra nell'albero al frame successivo: si aspetta che ci
	# sia, e un frame in piu' perche' abbia disegnato il primo fotogramma.
	await get_tree().process_frame
	await get_tree().process_frame
	var entrata := create_tween()
	entrata.tween_property(_velo, "color:a", 0.0, DURATA_ENTRATA)
	await entrata.finished
	_in_corso = false
	queue_free()
