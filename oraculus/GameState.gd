extends Node

# ── Session identity ──────────────────────────────────────────────────────────
var session_id: String = ""

func _ready() -> void:
	randomize()   # seed the global RNG — senza questo shuffle() è deterministico
	_new_session()

func _new_session() -> void:
	session_id = "%d_%d" % [randi(), Time.get_unix_time_from_system()]
	_door_assignments.clear()
	_minigame_pool.clear()
	_fallback_pool.clear()

# ── Door assignment ───────────────────────────────────────────────────────────
# Chiamato da ogni porta in _ready(). Assegna casualmente "riddle" o "minigame"
# con un indice minigame unico per porta (pool ciclico shuffled).

const MINIGAME_COUNT := 2

var _door_assignments: Dictionary = {}   # door_id -> {mode, index?}
var _mode_pool: Array = []       # pool bilanciato: alterna riddle e minigame
var _minigame_pool: Array = []   # indici minigame unici per porta

func assign_door(door_id: String) -> Dictionary:
	if door_id in _door_assignments:
		return _door_assignments[door_id]

	if _mode_pool.is_empty():
		_refill_mode_pool()

	var mode: String = _mode_pool.pop_front()
	var assignment: Dictionary
	if mode == "riddle":
		assignment = {"mode": "riddle"}
	else:
		if _minigame_pool.is_empty():
			_refill_minigame_pool()
		assignment = {"mode": "minigame", "index": _minigame_pool.pop_front()}

	_door_assignments[door_id] = assignment
	return assignment

func _refill_mode_pool() -> void:
	# Quantità uguali di riddle e minigame, ordine casuale.
	_mode_pool = ["riddle", "riddle", "minigame", "minigame"]
	_mode_pool.shuffle()

func _refill_minigame_pool() -> void:
	_minigame_pool = range(MINIGAME_COUNT)
	_minigame_pool.shuffle()

# ── Fallback riddle pool ──────────────────────────────────────────────────────
# Porte diverse ottengono fallback diversi; il pool si rimescola quando esaurito.

var _fallback_pool: Array = []

const FALLBACK_RIDDLES: Array = [
	{"riddle": "I am cast by all who stand in the light,\nyet I myself have no substance.\nWhat am I?", "answer": "shadow"},
	{"riddle": "The more you take, the more you leave behind.\nWhat am I?", "answer": "footsteps"},
	{"riddle": "I have cities, but no houses live there.\nI have mountains, but no trees grow there.\nI have water, but no fish swim there.\nWhat am I?", "answer": "map"},
	{"riddle": "I speak without a mouth and hear without ears.\nI have no body, but I come alive with wind.\nWhat am I?", "answer": "echo"},
	{"riddle": "I can fly without wings.\nI can cry without eyes.\nWherever I go, darkness flies.\nWhat am I?", "answer": "cloud"},
	{"riddle": "I have hands but cannot clap.\nWhat am I?", "answer": "clock"},
	{"riddle": "The man who builds me doesn't want me.\nThe man who buys me doesn't use me.\nThe man who uses me doesn't know it.\nWhat am I?", "answer": "coffin"},
	{"riddle": "I go up when rain comes down.\nWhat am I?", "answer": "umbrella"},
	{"riddle": "Feed me and I live.\nGive me water and I die.\nWhat am I?", "answer": "fire"},
	{"riddle": "I am always in front of you\nbut cannot be seen.\nWhat am I?", "answer": "future"},
	{"riddle": "The more you share me,\nthe more of me you have.\nWhat am I?", "answer": "knowledge"},
	{"riddle": "I have a neck but no head,\nand wear a cap but have no hair.\nWhat am I?", "answer": "bottle"},
	{"riddle": "I run all day and never walk,\nI have a mouth but never talk,\nI have a bed but never sleep.\nWhat am I?", "answer": "river"},
	{"riddle": "The more it dries, the wetter I become.\nWhat am I?", "answer": "towel"},
	{"riddle": "I have teeth but cannot bite.\nI have a spine but am not alive.\nWhat am I?", "answer": "comb"},
	{"riddle": "Born in the dark, I eat the light.\nI age and shrink and vanish in the night.\nWhat am I?", "answer": "candle"},
	{"riddle": "I am lighter than a feather\nyet no man can hold me for long.\nWhat am I?", "answer": "breath"},
	{"riddle": "I have no legs, yet I travel the world.\nI have no wings, yet through the air I am hurled.\nWhat am I?", "answer": "letter"},
	{"riddle": "Kings and queens may call me theirs,\nbut I bow to no master.\nEvery man who walks the earth\nshall one day know my answer.\nWhat am I?", "answer": "death"},
	{"riddle": "I follow you all day long,\nbut when the night or rain comes,\nI am gone.\nWhat am I?", "answer": "shadow"},
	{"riddle": "I build up castles, I tear down mountains.\nI make some men blind and others see.\nWhat am I?", "answer": "sand"},
	{"riddle": "The more walls I have, the bigger I am not.\nWhat am I?", "answer": "prison"},
	{"riddle": "I am taken from a mine and shut in a wooden case,\nfrom which I am never released,\nand yet almost every person uses me.\nWhat am I?", "answer": "pencil"},
	{"riddle": "I have one eye but cannot see.\nThousands pass through me,\nbut I am still.\nWhat am I?", "answer": "needle"},
]

func get_fallback_riddle() -> Dictionary:
	if _fallback_pool.is_empty():
		_fallback_pool = FALLBACK_RIDDLES.duplicate()
		_fallback_pool.shuffle()
	return _fallback_pool.pop_front()

# ── Entrance riddle answer (Levias can hint it at high friendship) ────────────
var entrance_riddle_answer: String = ""

# ── Puzzle key state ──────────────────────────────────────────────────────────
var puzzle_key_found: bool = false
signal puzzle_key_collected

func collect_puzzle_key() -> void:
	puzzle_key_found = true
	emit_signal("puzzle_key_collected")

# ── Session reset (chiamato al riavvio) ───────────────────────────────────────
func reset_all() -> void:
	_new_session()
	_mode_pool.clear()
	entrance_riddle_answer = ""
	puzzle_key_found = false
