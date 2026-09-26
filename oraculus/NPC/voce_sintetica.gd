# ============================================================================
# La voce degli NPC: un suono sintetico per ogni lettera, come l'"animalese"
# di Animal Crossing, con un timbro da robot.
#
# Ogni lettera e' un campione di ~60-80 ms generato qui, senza file audio:
#  - le vocali sono un'onda a dente di sega (il ronzio "robotico") filtrata
#    su tre formanti, le frequenze che fanno riconoscere a, e, i, o, u;
#  - le consonanti sono un attacco breve (uno schiocco per p/t/k, un fruscio
#    per s/f, un ronzio nasale per m/n, una vocale scivolata per l/r) seguito
#    dalla vocale del nome della lettera in italiano (b -> "bi", f -> "effe").
#
# I campioni si generano una volta sola, alla prima lettera che serve, e si
# riusano per tutti gli NPC: ogni NPC li suona con il suo tono (PROFILI), che
# alza o abbassa insieme altezza e timbro, come fa Animal Crossing.
# ============================================================================
class_name VoceSintetica
extends RefCounted

## "tono": pitch_scale dei campioni (sotto 1 piu' grave e lento, sopra 1 piu'
## acuto e rapido). "velocita": lettere mostrate al secondo. "vibrato": di
## quanto il tono oscilla a caso da una lettera all'altra (0,25 = voce
## instabile, come quella di Malakai).
const PROFILI := {
	"Levias": {"tono": 0.8, "velocita": 26.0, "vibrato": 0.03},
	"SmirBombo": {"tono": 1.4, "velocita": 24.0, "vibrato": 0.04},
	"Rigon": {"tono": 1.1, "velocita": 32.0, "vibrato": 0.05},
	"Larry": {"tono": 0.55, "velocita": 20.0, "vibrato": 0.08},
	"Malakai": {"tono": 0.9, "velocita": 36.0, "vibrato": 0.25},
	"Kalessi": {"tono": 1.25, "velocita": 26.0, "vibrato": 0.03},
	"Allemar": {"tono": 0.95, "velocita": 24.0, "vibrato": 0.02},
	"Orco": {"tono": 0.65, "velocita": 30.0, "vibrato": 0.15},
	"Gruko": {"tono": 0.5, "velocita": 28.0, "vibrato": 0.12},
	"Tutorial": {"tono": 1.15, "velocita": 45.0, "vibrato": 0.03},
}
const PROFILO_BASE := {"tono": 1.0, "velocita": 30.0, "vibrato": 0.05}

const RATE := 22050
## Altezza del ronzio prima del tono dell'NPC.
const F0 := 150.0
const DURATA_VOCALE := 0.05

## Prime tre formanti (Hz).
const VOCALI := {
	"a": [730.0, 1090.0, 2440.0],
	"e": [530.0, 1840.0, 2480.0],
	"i": [300.0, 2250.0, 3000.0],
	"o": [570.0, 840.0, 2410.0],
	"u": [320.0, 800.0, 2240.0],
}

## lettera -> [attacco, vocale che segue].
const CONSONANTI := {
	"b": ["plosiva_bassa_sonora", "i"], "c": ["plosiva_media", "i"], "d": ["plosiva_alta_sonora", "i"],
	"f": ["fricativa_larga", "e"], "g": ["plosiva_media_sonora", "i"], "h": ["soffio", "a"],
	"j": ["fricativa_sc", "i"], "k": ["plosiva_media", "a"], "l": ["liquida_l", "e"],
	"m": ["nasale_m", "e"], "n": ["nasale_n", "e"], "p": ["plosiva_bassa", "i"],
	"q": ["plosiva_media", "u"], "r": ["liquida_r", "e"], "s": ["fricativa_s", "e"],
	"t": ["plosiva_alta", "i"], "v": ["fricativa_larga_sonora", "i"], "w": ["liquida_w", "u"],
	"x": ["fricativa_s", "i"], "y": ["liquida_y", "i"], "z": ["fricativa_s_sonora", "e"],
}

## Durata dell'attacco per tipo (s).
const DURATE := {
	"plosiva": 0.012, "fricativa": 0.035, "soffio": 0.025, "nasale": 0.03, "liquida": 0.025,
}

const ACCENTI := {
	"à": "a", "á": "a", "â": "a", "ä": "a", "ã": "a", "è": "e", "é": "e", "ê": "e", "ë": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i", "ò": "o", "ó": "o", "ô": "o", "ö": "o", "õ": "o",
	"ù": "u", "ú": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n", "ß": "s", "ý": "y",
}

static var _cache := {}


static func profilo(npc_name: String) -> Dictionary:
	return PROFILI.get(npc_name, PROFILO_BASE)


## La lettera a cui corrisponde il carattere ("È" -> "e"), o "" se il
## carattere non si pronuncia (spazi, punteggiatura, cifre).
static func lettera(c: String) -> String:
	var l := c.to_lower()
	l = ACCENTI.get(l, l)
	return l if VOCALI.has(l) or CONSONANTI.has(l) else ""


## Il campione del carattere, o null se non si pronuncia.
static func campione(c: String) -> AudioStreamWAV:
	var l := lettera(c)
	if l.is_empty():
		return null
	if not _cache.has(l):
		_cache[l] = _sintetizza(l)
	return _cache[l]


static func _sintetizza(l: String) -> AudioStreamWAV:
	var tipo := ""
	var vocale := l
	if CONSONANTI.has(l):
		tipo = String(CONSONANTI[l][0])
		vocale = String(CONSONANTI[l][1])
	var famiglia := tipo.get_slice("_", 0)
	var n_attacco := int(float(DURATE.get(famiglia, 0.0)) * RATE)
	var n := n_attacco + int(DURATA_VOCALE * RATE)
	var fv: Array = VOCALI[vocale]
	var f1 := [_ris(fv[0], 90.0), _ris(fv[1], 120.0), _ris(fv[2], 160.0)]
	var fa := _filtri_attacco(tipo)
	var sonora := tipo.ends_with("sonora")
	# Rumore ripetibile: la stessa lettera suona sempre uguale.
	var rng := RandomNumberGenerator.new()
	rng.seed = l.hash()

	var out := PackedFloat32Array()
	out.resize(n)
	var fase := 0.0
	var picco := 0.0
	for i in n:
		var t := float(i) / RATE
		var dente := 2.0 * fase - 1.0
		fase = fposmod(fase + F0 / RATE, 1.0)
		var s := 0.0
		if i < n_attacco:
			s = _attacco(famiglia, tipo, fa, dente, rng.randf_range(-1.0, 1.0), t, sonora)
		else:
			s = _passa(f1[0], dente) + 0.6 * _passa(f1[1], dente) + 0.3 * _passa(f1[2], dente)
		# Inviluppo: 3 ms di salita, 15 ms di discesa, niente clic ai bordi.
		var inviluppo := minf(1.0, t / 0.003) * minf(1.0, float(n - i) / (0.015 * RATE))
		out[i] = s * inviluppo
		picco = maxf(picco, absf(out[i]))

	var dati := PackedByteArray()
	dati.resize(n * 2)
	for i in n:
		dati.encode_s16(i * 2, int(clampf(out[i] / maxf(picco, 1e-6) * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = dati
	return wav


static func _filtri_attacco(tipo: String) -> Array:
	match tipo.trim_suffix("_sonora"):
		"plosiva_bassa": return [_ris(900.0, 1200.0)]
		"plosiva_media": return [_ris(2000.0, 1500.0)]
		"plosiva_alta": return [_ris(3500.0, 2000.0)]
		"fricativa_s": return [_ris(6000.0, 2500.0)]
		"fricativa_sc": return [_ris(2800.0, 1500.0)]
		"fricativa_larga": return [_ris(2500.0, 4000.0)]
		"soffio": return [_ris(1500.0, 3000.0)]
		"nasale_m": return [_ris(250.0, 100.0), _ris(1100.0, 250.0)]
		"nasale_n": return [_ris(250.0, 100.0), _ris(1700.0, 250.0)]
		"liquida_l": return [_ris(350.0, 100.0), _ris(1100.0, 150.0)]
		"liquida_r": return [_ris(400.0, 100.0), _ris(1300.0, 150.0)]
		"liquida_w": return [_ris(300.0, 100.0), _ris(700.0, 150.0)]
		"liquida_y": return [_ris(280.0, 100.0), _ris(2200.0, 150.0)]
	return []


static func _attacco(famiglia: String, tipo: String, filtri: Array, dente: float, rumore: float,
		t: float, sonora: bool) -> float:
	var voce := 0.3 * dente if sonora else 0.0
	match famiglia:
		"plosiva":
			return _passa(filtri[0], rumore * exp(-t / 0.003) * 4.0) + voce
		"fricativa", "soffio":
			return _passa(filtri[0], rumore) * (0.6 if famiglia == "soffio" else 1.0) + voce
		"nasale":
			return 0.6 * (_passa(filtri[0], dente) + 0.3 * _passa(filtri[1], dente))
		"liquida":
			var s := _passa(filtri[0], dente) + 0.5 * _passa(filtri[1], dente)
			if tipo == "liquida_r":
				s *= 0.6 + 0.4 * sin(TAU * 30.0 * t)
			return s
	return 0.0


## Risonatore a due poli: [a0, b1, b2, y1, y2]. E' un Array e non un
## PackedFloat64Array perche' _passa() deve aggiornarne lo stato.
static func _ris(f: float, banda: float) -> Array:
	var r := exp(-PI * banda / RATE)
	var th := TAU * f / RATE
	return [1.0 - r, 2.0 * r * cos(th), -r * r, 0.0, 0.0]


static func _passa(r: Array, x: float) -> float:
	var y: float = r[0] * x + r[1] * r[3] + r[2] * r[4]
	r[4] = r[3]
	r[3] = y
	return y
