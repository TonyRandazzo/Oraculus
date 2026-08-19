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
	{"riddle": "When light shines on you, I appear on the ground next to you.\nYou can see my shape, but you can never touch me.\nWhat am I?", "answer": "shadow"},
	{"riddle": "Every step you take leaves more of me behind you on the ground.\nWhat am I?", "answer": "footsteps"},
	{"riddle": "I show cities, but nobody lives in them.\nI show mountains, but no trees grow on them.\nI show rivers, but no fish swim in them.\nWhat am I?", "answer": "map"},
	{"riddle": "I repeat the words you shout in an empty room or a cave.\nI only happen when there is a sound first.\nWhat am I?", "answer": "echo"},
	{"riddle": "I float in the sky, I am full of water, and I can turn dark before it rains.\nWhat am I?", "answer": "cloud"},
	{"riddle": "I have two hands and a round face, and I show you the time all day,\nbut my hands can never clap together.\nWhat am I?", "answer": "clock"},
	{"riddle": "Someone builds me even though they don't want to end up inside me.\nWhoever ends up inside me will never know it.\nWhat am I?", "answer": "coffin"},
	{"riddle": "When it starts to rain, people open me up above their heads to stay dry.\nWhat am I?", "answer": "umbrella"},
	{"riddle": "Give me wood or paper and I grow bigger.\nPour water on me and I disappear.\nWhat am I?", "answer": "fire"},
	{"riddle": "It is always coming toward you, one day at a time,\nbut you can never see it or touch it before it arrives.\nWhat am I?", "answer": "future"},
	{"riddle": "If you teach it to someone else, you still keep all of it yourself,\nand now two people have it instead of one.\nWhat am I?", "answer": "knowledge"},
	{"riddle": "I have a narrow neck but no head, and a cap on top but no hair.\nYou often find me in a kitchen, full of liquid.\nWhat am I?", "answer": "bottle"},
	{"riddle": "I flow all day but I never walk.\nI have a mouth where I meet the sea, but I never talk.\nWhat am I?", "answer": "river"},
	{"riddle": "You use me to dry yourself off,\nbut the more I do that job, the wetter I get.\nWhat am I?", "answer": "towel"},
	{"riddle": "I have many teeth in a row, but I cannot bite or chew.\nYou pull me through your hair every morning.\nWhat am I?", "answer": "comb"},
	{"riddle": "I am made of wax, and when you light me on fire,\nI slowly get shorter and shorter until I burn out.\nWhat am I?", "answer": "candle"},
	{"riddle": "I weigh almost nothing at all, but if you hold me in for too long,\nit starts to hurt and you have to let me out.\nWhat am I?", "answer": "breath"},
	{"riddle": "I have no legs, but you can send me far across the country.\nSomeone writes on me, puts me in an envelope, and mails me.\nWhat am I?", "answer": "letter"},
	{"riddle": "Every living person will meet me one day, even kings and queens,\nand no one has ever found a way to escape me.\nWhat am I?", "answer": "death"},
	{"riddle": "I always come after the day is over,\nand I disappear again as soon as the sun rises.\nWhat am I?", "answer": "night"},
	{"riddle": "Children can build me into a castle at the beach,\nbut over thousands of years I can also wear down a whole mountain.\nWhat am I?", "answer": "sand"},
	{"riddle": "The more walls you build around me, the smaller the space inside actually becomes.\nPeople are locked inside me and cannot leave.\nWhat am I?", "answer": "prison"},
	{"riddle": "My core comes from a mine, but I am not a jewel.\nI live inside a thin wooden case, and you use me to write or draw.\nWhat am I?", "answer": "pencil"},
	{"riddle": "I have a small hole at one end called an eye, but I cannot see with it.\nA thread passes through that hole when someone sews with me.\nWhat am I?", "answer": "needle"},
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
