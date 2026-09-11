#!/usr/bin/env python3
"""Genera res://ai/oraculus_data.gd a partire da ai/inference.py.

Le costanti (STORY_CONTEXT, NPC_DATA, INTENT_KW, ...) vengono emesse come
literal GDScript byte-per-byte identici agli originali Python: nessuna
ricopiatura a mano, quindi nessuna divergenza possibile. L'ordine di
inserimento dei dizionari e' preservato (conta per classify_intent e
detect_language).

Uso:  python3 tools/gen_oraculus_data.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _stub_hf  # noqa: E402

_stub_hf.install()

import inference as inf  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "ai", "oraculus_data.gd")

TAB = "\t"


# --------------------------------------------------------------------------
# escaping
# --------------------------------------------------------------------------

def esc(s: str) -> str:
    """Literal GDScript su una riga."""
    out = (s.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t"))
    return '"' + out + '"'


def unesc(lit: str) -> str:
    """Inverso di esc(), per verificare il round-trip."""
    assert lit[0] == '"' and lit[-1] == '"'
    body = lit[1:-1]
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            nxt = body[i + 1]
            out.append({"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}[nxt])
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def can_triple(s: str) -> bool:
    """Le triple-quote GDScript non sono raw: vietiamo backslash ed escape."""
    if "\\" in s or '"""' in s or "\r" in s:
        return False
    if s.endswith('"') or s.startswith('"'):
        return False
    return "\n" in s


def gd_string(s: str, indent: int) -> str:
    """Literal GDScript. Le triple-quote tengono il corpo leggibile, ma i
    newline iniziali e finali vengono emessi come escape \\n espliciti: un
    newline reale subito dopo l'apertura """ + '"""' + """ sarebbe ambiguo da
    leggere, mentre l'escape non lascia dubbi (le triple-quote GDScript
    processano gli escape, non sono raw)."""
    if can_triple(s):
        lead = len(s) - len(s.lstrip("\n"))
        trail = len(s) - len(s.rstrip("\n"))
        core = s[lead:len(s) - trail]
        assert "\\" not in core
        return '"""' + ("\\n" * lead) + core + ("\\n" * trail) + '"""'
    lit = esc(s)
    assert unesc(lit) == s, "round-trip escaping fallito"
    return lit


def gd_value(v, indent: int) -> str:
    pad = TAB * indent
    inner = TAB * (indent + 1)
    if isinstance(v, str):
        return gd_string(v, indent)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, (list, tuple)):
        if not v:
            return "[]"
        items = ",\n".join(inner + gd_value(x, indent + 1) for x in v)
        return "[\n" + items + ",\n" + pad + "]"
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = []
        for k, val in v.items():
            rows.append(inner + esc(k) + ": " + gd_value(val, indent + 1))
        return "{\n" + ",\n".join(rows) + ",\n" + pad + "}"
    raise TypeError(type(v))


def const(name: str, value, typ: str) -> str:
    return "const %s: %s = %s\n\n" % (name, typ, gd_value(value, 0))


# --------------------------------------------------------------------------
# emissione
# --------------------------------------------------------------------------

parts = []
parts.append('''# ============================================================================
# FILE GENERATO AUTOMATICAMENTE — NON MODIFICARE A MANO.
# Sorgente: ai/inference.py
# Rigenera con: python3 tools/gen_oraculus_data.py
#
# Contiene tutte le costanti-dato del motore di dialogo, byte-per-byte
# identiche a quelle Python. L'ordine delle chiavi dei dizionari e'
# significativo: classify_intent restituisce il primo intent che matcha e
# detect_language prende il primo massimo, quindi l'ordine di inserimento
# non va toccato.
# ============================================================================
class_name OraculusData
extends RefCounted

''')

parts.append("# --- configurazione modello ----------------------------------------------\n\n")
parts.append('const MODEL_PATH: String = %s\n' % esc(inf.MODEL_PATH))
parts.append('const MODEL_FORMAT: String = %s\n' % esc(inf.MODEL_FORMAT))
parts.append("const N_CTX: int = %d\n" % inf.N_CTX)
parts.append("const N_THREADS: int = %d\n" % inf.N_THREADS)
parts.append("const MAX_TOKENS: int = %d\n" % inf.MAX_TOKENS)
parts.append("const TEMPERATURE: float = %r\n" % inf.TEMPERATURE)
parts.append("const TOP_K: int = %d\n" % inf.TOP_K)
parts.append("const TOP_P: float = %r\n" % inf.TOP_P)
parts.append("const REPEAT_PENALTY: float = %r\n" % inf.REPEAT_PENALTY)
parts.append("const RIDDLE_MAX_TOKENS: int = 150\n")
parts.append("const RIDDLE_TEMPERATURE: float = 0.85\n")
parts.append("const RIDDLE_TOP_P: float = 0.9\n")
parts.append("const RIDDLE_TOP_K: int = 40\n\n")
parts.append('const HF_MODEL: String = %s\n' % esc("meta-llama/Llama-3.2-1B-Instruct"))
parts.append('const HF_PROVIDER: String = %s\n\n' % esc("auto"))

parts.append("# --- nomi degli eserciti --------------------------------------------------\n\n")
parts.append('const ARMY_NAME: String = %s\n' % esc(inf.ARMY_NAME))
parts.append('const ARMY_NAME_EN: String = %s\n' % esc(inf.ARMY_NAME_EN))
parts.append('const IMPERIAL_ARMY: String = %s\n' % esc(inf.IMPERIAL_ARMY))
parts.append('const IMPERIAL_ARMY_IT: String = %s\n\n' % esc(inf.IMPERIAL_ARMY_IT))

parts.append("# --- contesto narrativo --------------------------------------------------\n\n")
parts.append(const("STORY_CONTEXT", inf.STORY_CONTEXT, "String"))

parts.append("# --- rilevamento lingua --------------------------------------------------\n\n")
parts.append(const("LANG_SIGNATURES", inf.LANG_SIGNATURES, "Dictionary"))

parts.append("# --- classificazione intent ---------------------------------------------\n\n")
parts.append(const("INTENT_KW", inf.INTENT_KW, "Dictionary"))

parts.append("# --- dati NPC -----------------------------------------------------------\n\n")
parts.append(const("NPC_DATA", inf.NPC_DATA, "Dictionary"))

parts.append("# --- risposte di riserva ------------------------------------------------\n\n")
parts.append(const("FALLBACK", inf.FALLBACK, "Dictionary"))
parts.append(const("RIDDLE_FALLBACKS", inf.RIDDLE_FALLBACKS, "Dictionary"))
parts.append(const("DEFAULT_RIDDLE_THEMES", inf.DEFAULT_RIDDLE_THEMES, "Array"))

parts.append("# --- token di stop e trigger --------------------------------------------\n\n")
parts.append(const("STOP_TOKENS_MAP", inf.STOP_TOKENS_MAP, "Dictionary"))
parts.append(const("MALAKAI_TRIGGERS", list(inf.NPCDialogueEngine.MALAKAI_TRIGGERS), "Array"))

parts.append("""# --- prefissi ripuliti da pulisci() -------------------------------------
# Nota: i primi due dipendono da npc_name e vengono composti a runtime.

const CLEAN_PREFIXES_STATIC: Array = [
\t"Tu:",
\t"Risposta:",
\t"Assistant:",
\t"Model:",
\t"assistant",
\t"system",
\t"AI:",
\t"Bot:",
\t"User:",
\t"Player:",
]

const BAD_MARKERS: Array = [
\t"###",
\t"<|",
\t"<start",
\t"User:",
\t"System:",
\t"Assistant:",
\t"Note:",
\t"[INST]",
\t"Giocatore:",
\t"Nota:",
\t"Player:",
\t"Model:",
\t"assistant",
\t"system",
\t"<|eot_id|>",
]

const WRONG_ARMY_NAMES: Array = [
\t"esercito dell'ombra",
\t"army of shadows",
\t"esercito oscuro",
\t"dark army",
\t"esercito dei crociati",
\t"crusader army",
\t"esercito della croce",
\t"army of the cross",
\t"esercito sacro",
\t"holy army",
\t"dark legion",
\t"legione oscura",
]
""")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("".join(parts))

print("scritto %s (%d byte)" % (OUT, os.path.getsize(OUT)))
