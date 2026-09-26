extends Control
## Il pannello delle opzioni, lo stesso nel menu (Title/Options2) e in gioco
## (Player/CanvasLayer/Options).
##
##  - Musica / SFX: cursori con la maniglia da trascinare, regolano i bus
##    "Music" e "SFX" (vedi GameState.set_volume, che li salva anche).
##  - Continue: chiude il pannello e riprende il gioco.
##  - Restart: ricarica la scena attuale, da capo.
##  - Exit: dal gioco torna al menu; dal menu chiude il gioco.
##
## Il clic dei pulsanti lo aggiunge UiSounds da solo, come per ogni pulsante.

const SCENA_MENU := "res://oraculus/menu.tscn"
## Prima di chiudere il gioco si aspetta la fine del clic del pulsante.
const ATTESA_USCITA := 0.3

@onready var musica: HSlider = $Musica
@onready var effetti: HSlider = $SFX


func _ready() -> void:
	musica.value = GameState.volume(&"Music") * 100.0
	effetti.value = GameState.volume(&"SFX") * 100.0
	musica.value_changed.connect(func(v: float) -> void: GameState.set_volume(&"Music", v / 100.0))
	effetti.value_changed.connect(func(v: float) -> void: GameState.set_volume(&"SFX", v / 100.0))
	# Sul Web il gioco non si puo' chiudere: dal menu Exit non avrebbe effetto.
	if OS.has_feature("web") and _nel_menu():
		$Exit.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause():
	get_tree().paused = !get_tree().paused
	visible = !visible
	var pausa := get_node_or_null("../Pause")
	if pausa != null:
		pausa.visible = !pausa.visible


## Continue.
func _on_texture_button_pressed() -> void:
	get_tree().paused = false
	visible = false
	var pausa := get_node_or_null("../Pause")
	if pausa != null:
		pausa.visible = true


func _on_pause_pressed() -> void:
	get_tree().paused = true
	visible = true
	var pausa := get_node_or_null("../Pause")
	if pausa != null:
		pausa.visible = false


## Restart: la scena attuale da capo, come il pulsante della schermata di
## sconfitta: sessione nuova (indovinelli, porte, chiave) e spiriti che non
## ricordano la partita di prima.
func _on_restart_pressed() -> void:
	get_tree().paused = false
	_nuova_partita()
	get_tree().reload_current_scene()


## Exit: dal gioco torna al menu (e il prossimo Start e' una partita nuova);
## dal menu chiude il gioco.
func _on_exit_pressed() -> void:
	get_tree().paused = false
	if _nel_menu():
		await get_tree().create_timer(ATTESA_USCITA, true, false, true).timeout
		get_tree().quit()
		return
	_nuova_partita()
	get_tree().change_scene_to_file(SCENA_MENU)


func _nel_menu() -> bool:
	var scena := get_tree().current_scene
	return scena != null and scena.scene_file_path == SCENA_MENU


func _nuova_partita() -> void:
	GameState.reset_all()
	var ai := get_node_or_null("/root/AIServerManager")
	if ai != null:
		ai.reset_memory()
