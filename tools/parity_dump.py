#!/usr/bin/env python3
"""Genera res://ai/tests/parity_cases.json: per ogni funzione pura di
ai/inference.py salva input e output attesi.

La scena res://ai/tests/parity_check.tscn rilegge questo file e confronta il
risultato di ai/oraculus_logic.gd stringa per stringa. Se build_prompt
combacia, il modello riceve lo stesso input di prima e il porting e'
dimostrato, non solo sperato.

Uso:  python3 tools/parity_dump.py
"""
import hashlib
import itertools
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _stub_hf  # noqa: E402

_stub_hf.install()

import inference as inf  # noqa: E402


class _Trig:
    """_check_malakai_unlock e' un metodo di istanza ma non usa altro
    stato: questo guscio evita di costruire il motore (e caricare il
    modello) solo per chiamarlo."""
    MALAKAI_TRIGGERS = inf.NPCDialogueEngine.MALAKAI_TRIGGERS
    _check_malakai_unlock = inf.NPCDialogueEngine._check_malakai_unlock


_trig = _Trig()

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "ai", "tests", "parity_cases.json")

cases = []

# Ogni prompt completo contiene STORY_CONTEXT (9 KB): salvarli tutti in
# chiaro produrrebbe un JSON da 23 MB. Per quelle funzioni salviamo lunghezza
# e sha256, e teniamo in chiaro solo i primi FULL_SAMPLES casi, che bastano a
# diffare a mano quando qualcosa non torna.
DIGEST_FNS = {"build_prompt", "build_system_msg", "build_riddle_system",
              "build_prompt_unknown", "build_system_msg_unknown"}
FULL_SAMPLES = 3
_full_left = {}


def add(fn, args, expected):
    case = {"fn": fn, "args": args}
    if fn in DIGEST_FNS:
        case["expected_len"] = len(expected)
        case["expected_sha256"] = hashlib.sha256(expected.encode("utf-8")).hexdigest()
        if _full_left.get(fn, FULL_SAMPLES) > 0:
            _full_left[fn] = _full_left.get(fn, FULL_SAMPLES) - 1
            case["expected"] = expected
    else:
        case["expected"] = expected
    cases.append(case)


# --------------------------------------------------------------------------
# detect_language
# --------------------------------------------------------------------------

PHRASES = [
    "ciao, come stai? voglio sapere dove sono",
    "hello, how are you? I want to know where I am",
    "bonjour, pourquoi vous êtes ici",
    "hola, qué tienes por mí",
    "hallo, warum sind sie hier",
    "",
    "xyzzy plugh",
    "ciao hello",                     # ambiguo: tie-break sul primo massimo
    "come what",                      # ambiguo
    "CIAO GRAZIE SÌ PERCHÉ",          # maiuscole
    "no",                             # una sola keyword, condivisa
    "I want to kill you",
    "voglio uccidere Rigon",
    "où est la salle des étoiles",
    "dónde está el monolito",
    "wo ist der Mond Garten",
]
for p in PHRASES:
    add("detect_language", {"text": p}, inf.detect_language(p))


# --------------------------------------------------------------------------
# classify_intent
# --------------------------------------------------------------------------

INTENT_PHRASES = [
    "ciao", "salve spirito", "hello there", "hola",
    "scusa, non volevo", "sorry, forgive me",
    "parlami di libri e poesia", "tell me about art and knowledge",
    "ti uccido", "I will burn everything",
    "sto mentendo", "this is a joke",
    "che scherzo divertente", "haha funny",
    "vendetta per l'oracolo", "the war and the army",
    "aiutami per favore", "how can I help you",
    "dove è la sala dei quadri", "where is the papyrus hall",
    "cos'è questo oggetto", "what is this relic",
    "chi sei, spirito", "who are you",
    "chi viveva qui, la famiglia nobile", "tell me about the oracle",
    "vattene", "get out of here",
    "c'è un passaggio segreto", "is there a hidden staircase",
    "parlami di rigon", "kalessi la medusa", "malakai il gran sacerdote",
    "gruko capo degli orchi",
    "qual è la mission",
    "niente di tutto questo",
    "",
    # frasi che matchano piu' intent: conta l'ordine di INTENT_KW
    "ciao, dove è la stanza segreta",
    "dove posso trovare un libro",
    "voglio aiutare uccidendo rigon",
    "storia della guerra",
]
for p in INTENT_PHRASES:
    add("classify_intent", {"text": p}, inf.classify_intent(p))
    add("check_malakai_unlock", {"text": p}, _trig._check_malakai_unlock(p))

for p in ["I deserted the army", "ho disertato", "vergogna", "justice", "l'oracolo lo sa", "niente"]:
    add("check_malakai_unlock", {"text": p}, _trig._check_malakai_unlock(p))


# --------------------------------------------------------------------------
# hostility_tier / adjust_hostility
# --------------------------------------------------------------------------

HOSTILITIES = [0, 1, 19, 20, 30, 39, 40, 41, 50, 60, 69, 70, 71, 99, 100]
FRIENDSHIPS = [0, 1, 5, 10, 11, 20, 40, 59, 60, 61, 80, 99, 100]

for h, f in itertools.product(HOSTILITIES, FRIENDSHIPS):
    add("hostility_tier", {"hostility": h, "friendship": f}, inf.hostility_tier(h, f))

ALL_INTENTS = list(inf.INTENT_KW.keys()) + ["generico"]
for intent, h, f in itertools.product(ALL_INTENTS, HOSTILITIES, [0, 11, 60, 100]):
    add("adjust_hostility", {"intent": intent, "hostility": h, "friendship": f},
        inf.adjust_hostility(intent, h, f))


# --------------------------------------------------------------------------
# pulisci
# --------------------------------------------------------------------------

DIRTY = [
    "Levias: Hello there, traveller.",
    "Levias : Hello there, traveller.",
    "levias: lower case prefix.",
    "Assistant: I am here.",
    "assistantI am here.",
    "Player: what do you want",
    "<|eot_id|>Clean this up.",
    "Some text <|start_header_id|> with tokens <|end_header_id|> inside.",
    "Keep (short) but drop (this long parenthetical note here).",
    "1. Claristorium\n2. Painting Hall\n3. Promontory",
    "1. Claristorium\n2. Painting Hall",
    "1. Only one item",
    "• first\n• second\n• third\n• fourth",
    "- dash one\n- dash two",
    "* star one\n* star two\n* star three",
    "### Note: this should vanish\nBut this stays.",
    "First line.\nSecond line.\nThird line should be cut.",
    "No final punctuation here",
    "Short",
    "A",
    "",
    "   \n  \n ",
    "Sentence one is quite long and descriptive. " * 8,
    "A" * 300,
    ("The first floor holds the Claristorium as its central hub. " * 4) + "And a tail without punctuation",
    "Ends with exclamation!",
    "Ends with question?",
    "…ellipsis only…",
    "Nota: meta commento\nRisposta utile.",
    "Risposta: la vera risposta.",
    "Tu: parlami\nEcco la risposta.",
    "Accenti: perché è così, città però.",
    "Mixed 1. inline numbering should not trigger multiline handling.",
    "Bombo! Bombo! You chose this!",
]
for d in DIRTY:
    for npc in ["Levias", "Malakai", "SmirBombo"]:
        add("pulisci", {"testo": d, "npc_name": npc}, inf.pulisci(d, npc))


# --------------------------------------------------------------------------
# enforce_army_name
# --------------------------------------------------------------------------

ARMY_TEXTS = [
    "The dark army came for him.",
    "L'esercito dell'ombra arrivò.",
    "The ARMY OF SHADOWS and the Dark Legion.",
    "Esercito Oscuro, esercito dei crociati, esercito della croce.",
    "The army of the cross, the holy army, the crusader army.",
    "Legione Oscura e legione oscura ancora.",
    "Nessun nome sbagliato qui.",
    "dark armydark army",
]
for t in ARMY_TEXTS:
    for lang in ["italiano", "inglese", "francese"]:
        add("enforce_army_name", {"text": t, "language": lang}, inf.enforce_army_name(t, lang))


# --------------------------------------------------------------------------
# politiche sui segreti
# --------------------------------------------------------------------------

NPCS = list(inf.NPC_DATA.keys())
POLICY_GRID = [(90, 0), (70, 0), (45, 0), (39, 0), (20, 0), (19, 0), (30, 61), (30, 60), (0, 100)]

for npc, (h, f) in itertools.product(NPCS, POLICY_GRID):
    add("format_secret_policy", {"npc_name": npc, "hostility": h, "friendship": f},
        inf._format_secret_policy(inf.NPC_DATA[npc], h, f))

CONTEXT_VARS = [
    {},
    {"entrance_riddle_answer": "echo"},
    {"entrance_riddle_answer": "echo", "entrance_riddle_reveal_threshold": 40},
    {"entrance_riddle_answer": ""},
    {"altro": "valore"},
    {"entrance_riddle_answer": "ombra", "entrance_riddle_reveal_threshold": 0},
]
for npc, cv, f in itertools.product(["Levias", "Larry", "Malakai"], CONTEXT_VARS, [0, 40, 60, 100]):
    add("format_dynamic_secrets", {"npc_name": npc, "friendship": f, "context_vars": cv},
        inf._format_dynamic_secrets(npc, f, cv))


# --------------------------------------------------------------------------
# build_prompt / build_system_msg
# --------------------------------------------------------------------------

HISTORIES = [
    [],
    [{"player": "ciao", "npc": "Salve, viandante."}],
    [
        {"player": "chi sei", "npc": "Sono Levias."},
        {"player": "dove sono", "npc": "All'ingresso."},
        {"player": "e ora", "npc": "Ora scegli."},
    ],
    [
        {"player": "uno", "npc": "primo"},
        {"player": "due", "npc": "secondo"},
        {"player": "tre", "npc": "terzo"},
        {"player": "quattro", "npc": "quarto"},
    ],
]
LANGS = ["italiano", "inglese", "francese", "spagnolo", "tedesco"]
PROMPT_GRID = [(90, 0), (50, 20), (10, 80), (0, 0), (100, 100)]

for npc in NPCS:
    for (h, f), lang, hist in itertools.product(PROMPT_GRID, LANGS, HISTORIES):
        args = {
            "player_input": "Dove porta la porta chiusa?",
            "npc_name": npc,
            "hostility": h,
            "friendship": f,
            "language": lang,
            "history": hist,
            "context_vars": None,
        }
        add("build_prompt", args, inf.build_prompt(
            args["player_input"], npc, h, f, lang, hist, inf.NPC_DATA[npc], None))
        args2 = dict(args)
        args2.pop("history")
        args2.pop("player_input")
        add("build_system_msg", args2, inf.build_system_msg(npc, h, f, lang, inf.NPC_DATA[npc], None))

# con context_vars e un NPC fuori da NPC_DATA
for cv in CONTEXT_VARS:
    for f in [0, 70]:
        args = {
            "player_input": "Qual è la risposta dell'indovinello?",
            "npc_name": "Levias",
            "hostility": 30,
            "friendship": f,
            "language": "italiano",
            "history": HISTORIES[1],
            "context_vars": cv,
        }
        add("build_prompt", args, inf.build_prompt(
            args["player_input"], "Levias", 30, f, "italiano", HISTORIES[1],
            inf.NPC_DATA["Levias"], cv))
        args2 = dict(args)
        args2.pop("history")
        args2.pop("player_input")
        add("build_system_msg", args2,
            inf.build_system_msg("Levias", 30, f, "italiano", inf.NPC_DATA["Levias"], cv))

# NPC sconosciuto: si usa il fallback di personalita'
UNKNOWN = {"personalita": "You are Ignoto, an ancient spirit."}
add("build_prompt_unknown",
    {"player_input": "ciao", "npc_name": "Ignoto", "hostility": 70, "friendship": 0,
     "language": "inglese", "history": [], "context_vars": None},
    inf.build_prompt("ciao", "Ignoto", 70, 0, "inglese", [], UNKNOWN, None))
add("build_system_msg_unknown",
    {"npc_name": "Ignoto", "hostility": 70, "friendship": 0, "language": "inglese",
     "context_vars": None},
    inf.build_system_msg("Ignoto", 70, 0, "inglese", UNKNOWN, None))


# --------------------------------------------------------------------------
# indovinelli
# --------------------------------------------------------------------------

RIDDLE_RAW = [
    "RIDDLE: I repeat your words.\nI live in empty halls.\nANSWER: echo",
    "riddle: minuscolo va bene comunque qui\nanswer: ECO",
    "RIDDLE: troppo corto\nANSWER: a",
    "RIDDLE: abc\nANSWER: eco",
    "Nessun formato riconoscibile.",
    "ANSWER: eco\nRIDDLE: invertito ma la regex prende comunque",
    "RIDDLE: multi\nlinea\ncon\ntanti\nnewline\nqui\nANSWER: tempo",
    "RIDDLE: senza answer alla fine",
    "RIDDLE: con parola accentata come risposta\nANSWER: menzogna",
    "  RIDDLE:   spazi   ovunque   \n  ANSWER:   ombra  ",
]
def riddle_canon(res):
    """Forma canonica confrontabile da GDScript senza dipendere
    dall'ordine delle chiavi o dagli spazi di json.dumps."""
    if res is None:
        return ""
    return res["answer"] + "\u0001" + res["riddle"]


for r in RIDDLE_RAW:
    add("parse_riddle_response", {"raw": r}, riddle_canon(inf.parse_riddle_response(r)))

# Il prompt dell'indovinello e' costruito dentro generate_riddle: lo
# ricomponiamo qui con lo stesso testo, cosi' la parita' e' verificabile.
def riddle_system(theme, language):
    return (
        f"You are an ancient spirit guardian of Oraculus Castle, year 1300.\n"
        f"{inf.STORY_CONTEXT}\n\n"
        f"You guard a door with a riddle. Create ONE riddle following these rules:\n"
        f"- Theme: {theme}\n"
        f"- Tone: dark, mysterious, medieval fantasy — but the riddle itself must be SIMPLE and EASY to understand\n"
        f"- The answer must be a single common, everyday word (an object, animal, or simple concept a child would know)\n"
        f"- Describe the answer using clear, concrete, literal clues (what it looks like, what it does, where you find it)\n"
        f"- Do NOT use abstract philosophy, obscure metaphors, or wordplay — a player should be able to guess it after reading it once\n"
        f"- Length: 2-3 short, simple sentences\n"
        f"- NEVER directly mention the answer in the riddle\n"
        f"- Every riddle must be unique and different from any you have created before\n"
        f"- Respond in {language}\n\n"
        f"Respond ONLY in this exact format, nothing else:\n"
        f"RIDDLE: [riddle text]\n"
        f"ANSWER: [single word]"
    )


def riddle_user(language, theme, session_id):
    variation_hint = f" (session: {session_id})" if session_id else ""
    return f"Generate a new, unique riddle in {language} about: {theme}{variation_hint}"


for theme, lang in itertools.product(list(inf.DEFAULT_RIDDLE_THEMES[:2]) + [""], ["inglese", "italiano"]):
    add("build_riddle_system", {"theme": theme, "language": lang}, riddle_system(theme, lang))
    for sid in ["", "abc123"]:
        add("build_riddle_user", {"language": lang, "theme": theme, "session_id": sid},
            riddle_user(lang, theme, sid))


# --------------------------------------------------------------------------
# costanti: impronta di ogni stringa lunga, cosi' un errore nel file
# generato viene segnalato subito invece di propagarsi nei prompt
# --------------------------------------------------------------------------

def sha(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


constants = {
    "STORY_CONTEXT": {"len": len(inf.STORY_CONTEXT), "sha256": sha(inf.STORY_CONTEXT)},
    "ARMY_NAME": inf.ARMY_NAME,
    "ARMY_NAME_EN": inf.ARMY_NAME_EN,
    "MODEL_FORMAT": inf.MODEL_FORMAT,
    "MAX_TOKENS": inf.MAX_TOKENS,
    "intent_order": list(inf.INTENT_KW.keys()),
    "lang_order": list(inf.LANG_SIGNATURES.keys()),
    "npc_order": list(inf.NPC_DATA.keys()),
    "npc_personalita_sha": {k: sha(v.get("personalita", "")) for k, v in inf.NPC_DATA.items()},
    "npc_info_segrete_sha": {k: sha(v.get("info_segrete", "")) for k, v in inf.NPC_DATA.items()},
    "fallback": inf.FALLBACK,
    "riddle_fallbacks": inf.RIDDLE_FALLBACKS,
    "default_riddle_themes": inf.DEFAULT_RIDDLE_THEMES,
    "malakai_triggers": list(inf.NPCDialogueEngine.MALAKAI_TRIGGERS),
}

payload = {
    "meta": {
        "sorgente": "ai/inference.py",
        "generato_da": "tools/parity_dump.py",
        "n_casi": len(cases),
    },
    "constants": constants,
    "cases": cases,
}

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=1)

print("scritto %s" % OUT)
print("  %d casi, %.1f KB" % (len(cases), os.path.getsize(OUT) / 1024.0))
from collections import Counter
for fn, n in sorted(Counter(c["fn"] for c in cases).items()):
    print("  %-26s %4d" % (fn, n))
