extends Node2D

var stanza2 = false
var fading = false
var fade_time = 1.5 
var fade_timer = 0.0
var fade_out_player: AudioStreamPlayer
var fade_in_player: AudioStreamPlayer

# Volumi di default come float
var music1_default_volume = -30.0
var music2_default_volume = -10.0

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if fading:
		fade_timer += delta
		var t = fade_timer / fade_time
		if t >= 1.0:
			fade_out_player.stop()
			# Ripristina i volumi originali
			if fade_out_player == $Music:
				fade_out_player.volume_db = music1_default_volume
			else:
				fade_out_player.volume_db = music2_default_volume

			if fade_in_player == $Music:
				fade_in_player.volume_db = music1_default_volume
			else:
				fade_in_player.volume_db = music2_default_volume

			fading = false
		else:
			# Fade out a -80.0, fade in fino al volume originale
			var fade_in_target = music1_default_volume if fade_in_player == $Music else music2_default_volume
			fade_out_player.volume_db = lerp(float(fade_out_player.volume_db), -80.0, t)
			fade_in_player.volume_db = lerp(-80.0, fade_in_target, t)

func _on_area_2d_2_area_entered(area: Area2D) -> void:
	if area.is_in_group("music_player") and not fading:
		if stanza2 == false:
			fade_out_player = $Music
			fade_in_player = $Music2
			fade_in_player.volume_db = -80.0
			fade_in_player.play()
			stanza2 = true
		else:
			fade_out_player = $Music2
			fade_in_player = $Music
			fade_in_player.volume_db = -80.0
			fade_in_player.play()
			stanza2 = false
		fade_timer = 0.0
		fading = true
