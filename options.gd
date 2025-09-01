extends Control

@onready var music_bar = $ProgressBar
@onready var sfx_bar = $ProgressBar2

func _ready():
	# Imposta i valori iniziali delle barre in base ai volumi attuali
	music_bar.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100
	sfx_bar.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) * 100
	
	# Collega i segnali delle barre
	music_bar.value_changed.connect(_on_music_changed)
	sfx_bar.value_changed.connect(_on_sfx_changed)

func _on_music_changed(value: float):
	# Converti il valore da 0-100 a dB (scala logaritmica)
	var volume_db = linear_to_db(value / 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)

func _on_sfx_changed(value: float):
	# Converti il valore da 0-100 a dB (scala logaritmica)
	var volume_db = linear_to_db(value / 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), volume_db)


func _on_texture_button_pressed() -> void:
	get_tree().paused = false
	visible = false
	if $"../Pause":
		$"../Pause".visible = true


func _on_pause_pressed() -> void:
	get_tree().paused = true
	visible = true
	if $"../Pause":
		$"../Pause".visible = false
