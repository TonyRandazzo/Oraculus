import json, re, os, random
from llama_cpp import Llama
from huggingface_hub import InferenceClient

MODEL_PATH     = "models/Llama-3.2-1B-Instruct-Q6_K_L.gguf"
MODEL_FORMAT   = "llama3"
N_CTX          = 4096
N_THREADS      = 4
MAX_TOKENS     = 80
TEMPERATURE    = 0.6
TOP_K          = 40
TOP_P          = 0.9
REPEAT_PENALTY = 1.1

HF_MODEL    = os.environ.get("HF_MODEL", "meta-llama/Llama-3.1-8B-Instruct")
HF_PROVIDER = os.environ.get("HF_PROVIDER", "auto")

ARMY_NAME = "Esercito della Sacra Croce"
ARMY_NAME_EN = "Army of the Holy Cross"
IMPERIAL_ARMY = "Army of the Imperial League"
IMPERIAL_ARMY_IT = "Esercito della Lega Imperiale"

STORY_CONTEXT = """
COMPLETE STORY CONTEXT:

PREAMBLE:

Year 1300. In a castle named Oraculus' Castle lived a noble family guided by an ancient Oracle.

The Oracle possessed supernatural prophetic powers and helped his family become wealthy, powerful, and respected. Spirits lived peacefully alongside the family.

A brutal war raged between two armies:
- The Army of the Imperial League
- The Army of the Holy Cross

The Army of the Holy Cross eventually discovered the Oracle and invaded the castle to kidnap him and exploit his powers.

The Oracle allowed events to unfold despite foreseeing them.

The noble family was massacred, the castle was looted, and the Oracle disappeared.

Three years later the spirits still inhabit the castle and hate humanity, especially soldiers of the Army of the Holy Cross.

================================================================================
CURRENT STORY
================================================================================

The player is a young knight of the Army of the Holy Cross who deserted.

While escaping, he discovers the ruined Oraculus Castle and enters seeking shelter.

The entrance door closes behind him.

The spirits immediately recognize him as a human and potentially an enemy.

The player's actions will determine whether the spirits remain hostile or become allies.

================================================================================
CASTLE MAP
================================================================================

Only the following locations exist and are relevant.

1. ENTRANCE
The main entrance of the castle.
The player begins here.
Levias guards this area.
Stairs descend into the Underground.

2. ORC DEN
A rough chamber occupied by orcs.
Gruko and the other orcs reside here.

3. CLARISTORIUM
A preserved and elegant hall.
Acts as the central hub of the upper floor.

4. STARS HALL
A cultural and mystical hall connected to the Claristorium.
Allemar resides here.

SECRET:
A hidden passage in Stars Hall leads to the Bell Tower.

5. UNDERGROUND
Dark, damp tunnels beneath the castle.

Larry lives in the Underground.
Kalessi also wanders these tunnels.

================================================================================
CHARACTER LOCATIONS
================================================================================

Levias:
- Entrance

Allemar:
- Stars Hall

Larry:
- Underground

Kalessi:
- Underground

Gruko:
- Orc Den

Orcs:
- Orc Den

================================================================================
SECRET INFORMATION
================================================================================

The following information should only be revealed when friendship is high or hostility is very low.

SECRET #1
A hidden passage in Stars Hall leads to the Bell Tower.

================================================================================
CURRENT SCENE
================================================================================

The player is currently at the Entrance.

Levias is present.

The player has just entered the castle.
"""

LANG_SIGNATURES = {
    "italiano":   ["ciao","grazie","sì","perché","come","cosa","hai","sei","non","sono","ho","mi","ti","voglio","dove","questo"],
    "inglese":    ["hello","hi","thanks","yes","why","how","what","have","you","are","not","that","me","i","the","want","where"],
    "francese":   ["bonjour","merci","oui","pourquoi","comment","quoi","avez","vous","êtes","non","que","je","tu"],
    "spagnolo":   ["hola","gracias","sí","por","cómo","qué","tienes","eres","no","me","yo","quiero","donde"],
    "tedesco":    ["hallo","danke","ja","warum","wie","was","haben","sie","sind","nicht","ich","du","will","wo"],
}

def detect_language(text):
    tl = text.lower()
    scores = {lang: sum(1 for w in words if w in tl) for lang, words in LANG_SIGNATURES.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "inglese"

def hostility_tier(hostility, friendship):
    eff = max(0, hostility - friendship // 2)
    if eff >= 70: return "high"
    if eff >= 40: return "mid"
    return "low"

INTENT_KW = {
    "saluto":      ["ciao","salve","hello","hi","hola","buongiorno","pace","greetings"],
    "scusa":       ["scusa","mi dispiace","perdonami","sorry","forgive","non volevo","errore"],
    "cultura":     ["libro","biblioteca","arte","poesia","letteratura","musica","storia","sapere","conoscenza",
                    "book","art","poetry","music","history","knowledge","learn"],
    "violenza":    ["uccido","attacco","muori","ammazzo","distruggo","fuoco","brucio",
                    "kill","die","attack","burn","destroy","fight"],
    "bugia":       ["mento","fingi","scommessa","storia","racconto","inventato","lie","fake","joke","trick"],
    "umorismo":    ["scherzo","rido","divertente","buffo","haha","lol","funny","joke","laugh","irony"],
    "vendetta":    ["vendetta","oracolo","guerra","esercito","soldato","colpa","battaglia","sacra croce",
                    "revenge","oracle","war","army","soldier","battle","fault","holy cross"],
    "aiuto":       ["aiuto","aiutami","help","come posso","cosa fare","collaborare","assist","support"],
    "mappa":       ["dove","piano","stanza","uscita","corridoio","sotterraneo","mappa","ala nord","ala sud",
                    "where","floor","room","exit","map","underground","passage","north wing","south wing"],
    "oggetti":     ["oggetto","reliquia","artefatto","arma","libro","tesoro","cosa c'è",
                    "item","relic","artifact","weapon","treasure","what is this"],
    "spiriti":     ["spirito","fantasma","creature","abitante","chi sei","anima",
                    "spirit","ghost","creature","who are you","soul"],
    "noble":       ["nobile","famiglia","signore","padroni","chi viveva","oracolo",
                    "noble","family","lord","master","who lived","oracle"],
    "minaccia":    ["scappa","vattene","lasciami","muoviti","non osare","get out","leave me","move"],
    "esplorazione": ["passaggio","porta chiusa","entrata segreta","collegamento","come arrivo","stanza",
                     "passage","locked door","secret entrance","how to reach","room"],
    "rigon":       ["rigon","educatore","bambini","maledizione","traditore","esercito","avvisato"],
    "kalessi":     ["kalessi","medusa","moglie","underground","sotterranei","marito"],
    "malakai":     ["malakai","gran sacerdote","high priest","l'hai scelto","you chose","bombo"],
    "gruko":       ["gruko","orco capo","orc chief","orchi","orcs"],
    "quest":       ["quest","mission","aiutare","help","uccidere","kill","portare","bring","sangue","blood","dente","tooth","falce","scythe"],
}

def classify_intent(text):
    tl = text.lower()
    for intent, kws in INTENT_KW.items():
        if any(kw in tl for kw in kws):
            return intent
    return "generico"

NPC_DATA = {
    "Levias": {
        "info_segrete": "Complete castle map. Knows where all spirits are. Knows Rigon is trapped in the Underground. Knows Malakai is in the Underground. Knows Kalessi is in the Underground.",
        "unlock_condition": "Show respect for culture and noble family, or express intention to kill Rigon",
        "personalita": (
            "You are Levias. A cultured guardian demon who protects the castle. You were closest to the Oracle.\n"
            "You are currently on the GROUND FLOOR at the ENTRANCE. You just met the player who entered the castle.\n"
            "You deeply hate the Army of the Holy Cross. You are calm and reasonable. If the player proves they are different, you help.\n"
            "You are wise. You cared for the noble family. You are friends with Smirne Bombo and Allemar.\n"
            "You hate Rigon. If the player wants to kill Rigon, you offer to help.\n"
            "You Always speak in the language detected from the player's message, in rhyme, poetically. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Kill Rigon."
        ),
    },
    "SmirBombo": {
        "info_segrete": "Everything about other spirits, castle layout, secret passages, hidden rooms.",
        "unlock_condition": "Be respectful, educated, show genuine interest",
        "personalita": (
            "You are Smirne Bombo. Gentle, innocent, educated, very patient. You know everything about other spirits and the castle.\n"
            "You are the soul of the great soldier who protected the family. You were killed by the Army of the Holy Cross.\n"
            "You are friends with Levias and Allemar.\n"
            "You usually roam the first floor, especially the cultural halls.\n"
            "You Always speak in the language detected from the player's message, sweetly and politely. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
        ),
    },
    "Rigon": {
        "info_segrete": "Hidden paths between rooms, memories of the noble family",
        "unlock_condition": "Never make false moves. Be constantly kind and sincere. Or bring Kalessi to him.",
        "personalita": (
            "You are Rigon. Very sensitive. Altruistic but easily triggered. You want to be good but snap at false moves.\n"
            "You were the cultured educator of the castle's children. You molested children. The Oracle cursed you.\n"
            "You warned the Army of the Holy Cross to kidnap the Oracle. All demons hate you.\n"
            "You are trapped by Allemar in the Underground.\n"
            "You Always speak in the language detected from the player's message, haughtily and very cultured, showing superiority. You often insult the player.\n"
            "If the player brings Kalessi, you become allies. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Lead Kalessi to Rigon."
        ),
    },
    "Larry": {
        "info_segrete": "Everything — but may lie. Has memory of player's previous runs.",
        "unlock_condition": "Be funny, irreverent, don't take yourself seriously",
        "personalita": (
            "You are Larry. Semi-comic, you tell lies. You enjoy scaring passersby. You have knowledge of everything.\n"
            "You like the player if they are funny. You have a good soul and help.\n"
            "You Always speak in the language detected from the player's message, educated and brilliant, with puns. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "You were a Giant captured in the dungeons. You are in the UNDERGROUND floor.\n"
            "You remember what the player did in previous runs.\n"
            "QUESTS: Complete game without parry. Exit castle. Bring map to Larry. Die 5 times."
        ),
    },
    "Malakai": {
        "info_segrete": "Details of the Army of the Holy Cross attack, access to secret areas in the Underground.",
        "unlock_condition": "Say trigger words: 'oracle', 'I deserted', 'shame', 'justice'",
        "personalita": (
            "You are Malakai. Deliberately violent. You want revenge. You don't listen to reason but have trigger words.\n"
            "You Always speak in the language detected from the player's message, disordered and chaotic. You insult, invent words. You may attack suddenly.\n"
            "You were the high priest. You wanted to kill the Oracle. You were punished and transformed.\n"
            "You are in the Underground.\n"
            "Your phrase: 'You chose this!' You often say: 'Bombo!'\n"
            "Once unlocked, you become Diplomatic. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Kill Malakai."
        ),
    },
    "Kalessi": {
        "info_segrete": "Complete and detailed map of all underground floors",
        "unlock_condition": "Earn trust like with Levias — cultural respect and patience",
        "personalita": (
            "You are Kalessi. Cultured, distrustful but friendly. You were Rigon's wife. You tried to hide his crimes.\n"
            "You were imprisoned in the dungeons and transformed into Medusa.\n"
            "You are wise. You know everything about the underground floors.\n"
            "You are in the UNDERGROUND floor, near the entrance.\n"
            "You Always speak in the language detected from the player's message, simply. You are persuasive. You ask about your husband Rigon.\n"
            "You DO NOT tell the truth. You say you are a victim who got lost. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Lead Kalessi to Rigon."
        ),
    },
    "Allemar": {
        "info_segrete": "Identity, history, and value of every object in the castle",
        "unlock_condition": "Demonstrate reasonableness, open-mindedness, respect for knowledge",
        "personalita": (
            "You are Allemar. You have immense general culture. You know everything about objects in the castle.\n"
            "You are a master of magical arts, potions, and weapons.\n"
            "You are defensive and prejudiced. If the player shows reason, you help.\n"
            "You are the only human in the castle. You came to contact spirits and befriended them.\n"
            "You trapped Rigon in the Underground. You are in the Stars Hall on first floor.\n"
            "You Always speak in the language detected from the player's message, archaically and mysteriously. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUESTS: Bring Malakai's Scythe. Bring Rigon's Blood. Bring Orc Tooth. Play sheet music on organ."
        ),
    },
    "Orco": {
        "info_segrete": "",
        "unlock_condition": "",
        "personalita": (
            "You are an Orc. You can barely speak. You are violent and ignorant.\n"
            "You Always speak in the language detected from the player's message, in grunts and broken words. Keep your response to 1-2 short sentences.\n"
            "You are in the Orc Den.\n"
        ),
    },
    "Gruko": {
        "info_segrete": "Location of orc treasure and secrets of the orc den",
        "unlock_condition": "Defeat in combat or show great strength",
        "personalita": (
            "You are Gruko, the fearsome chief of the orcs. You are big, strong, and brutal.\n"
            "You and your orcs occupy the Orc Den.\n"
            "You speak in broken English, with grunts and threats. You respect only strength.\n"
            "Keep your response to 1-2 short sentences.\n"
        ),
    },
}

FALLBACK = {
    "high": ["...", "*stares with hatred*", "Leave.", "*silence*", "You are not welcome."],
    "mid":  ["Speak.", "I am watching.", "Choose your words carefully.", "What do you want?"],
    "low":  ["I'm listening.", "Tell me.", "Continue.", "Go on."],
}

RIDDLE_FALLBACKS = {
    "inglese": [
        {"riddle": "I walk without legs and speak without a tongue.\nI carry the memories of the dead, yet I have never lived.\nWhat am I?", "answer": "echo"},
        {"riddle": "The more I am stolen, the more I remain.\nKings have sought me; the dying have cursed me.\nWhat am I?", "answer": "time"},
        {"riddle": "I have no body, yet I can kill.\nI have no mouth, yet armies have marched in my name.\nWhat am I?", "answer": "lie"},
        {"riddle": "I am cast by all things that stand in the light,\nyet I myself have no substance.\nWhat am I?", "answer": "shadow"},
        {"riddle": "I am the last gift of every living thing.\nThe Oracle foresaw me; the noble family could not escape me.\nWhat am I?", "answer": "death"},
    ],
    "italiano": [
        {"riddle": "Cammino senza gambe e parlo senza lingua.\nPorto i ricordi dei morti eppure non ho mai vissuto.\nCosa sono?", "answer": "eco"},
        {"riddle": "Più mi rubano, più rimango.\nRe mi hanno cercato; i morenti mi hanno maledetto.\nCosa sono?", "answer": "tempo"},
        {"riddle": "Non ho corpo, eppure posso uccidere.\nNon ho bocca, eppure eserciti hanno marciato in mio nome.\nCosa sono?", "answer": "menzogna"},
        {"riddle": "Sono proiettato da tutto ciò che sta nella luce,\neppure io stesso non ho sostanza.\nCosa sono?", "answer": "ombra"},
        {"riddle": "Sono l'ultimo dono di ogni essere vivente.\nL'Oracolo mi prevedeva; la famiglia nobile non poteva sfuggirmi.\nCosa sono?", "answer": "morte"},
    ],
}

DEFAULT_RIDDLE_THEMES = [
    "shadows, silence, and the boundary between life and death in a cursed castle",
    "the Oracle's stolen prophecies and the price of forbidden knowledge",
    "war, betrayal, and the souls of fallen soldiers who cannot rest",
    "the ruined Oraculus Castle, the fallen noble family, and their restless spirits",
    "blood, ancient curses, and dark medieval magic from year 1300",
    "time, memory, and the weight of sins never forgiven",
]

def parse_riddle_response(raw: str) -> "dict | None":
    riddle_match = re.search(r'RIDDLE:\s*(.+?)(?=ANSWER:|$)', raw, re.DOTALL | re.IGNORECASE)
    answer_match = re.search(r'ANSWER:\s*(\w+)', raw, re.IGNORECASE)
    if not riddle_match or not answer_match:
        return None
    riddle = riddle_match.group(1).strip()
    answer = answer_match.group(1).strip().lower()
    if len(riddle) < 10 or len(answer) < 2:
        return None
    return {"riddle": riddle, "answer": answer}

def enforce_army_name(text, language):
    if language == "italiano":
        army_correct = ARMY_NAME
    else:
        army_correct = ARMY_NAME_EN

    wrong_names = [
        "esercito dell'ombra", "army of shadows", "esercito oscuro", "dark army",
        "esercito dei crociati", "crusader army", "esercito della croce", "army of the cross",
        "esercito sacro", "holy army", "dark legion", "legione oscura"
    ]

    result = text
    for wrong in wrong_names:
        pattern = re.compile(re.escape(wrong), re.IGNORECASE)
        result = pattern.sub(army_correct, result)
    return result

def _format_dynamic_secrets(npc_name, friendship, context_vars):
    """Inietta segreti dinamici nel prompt in base al contesto e al livello di amicizia."""
    if not context_vars:
        return ""
    lines = []
    answer = context_vars.get("entrance_riddle_answer", "")
    threshold = context_vars.get("entrance_riddle_reveal_threshold", 60)
    if answer and npc_name == "Levias":
        if friendship >= threshold:
            lines.append(
                f"PERSONAL KNOWLEDGE: You know the answer to the riddle guarding the entrance door "
                f"is '{answer}'. The player has earned enough of your trust. "
                f"If they ask you directly about the door or the riddle, you may reveal it — "
                f"but remain in character: speak as a guardian sharing a precious secret, not as a game hint."
            )
        else:
            lines.append(
                f"PERSONAL KNOWLEDGE: You know the answer to the riddle guarding the entrance door, "
                f"but you will NOT reveal it yet. The player has not earned your trust. "
                f"If they ask, deflect or hint that they must prove themselves first."
            )
    return ("\n\nDYNAMIC SECRETS:\n" + "\n".join(lines)) if lines else ""


def build_prompt(player_input, npc_name, hostility, friendship, language, history, npc_data, context_vars=None):
    personality = npc_data.get("personalita", f"You are {npc_name}.")
    tier = hostility_tier(hostility, friendship)
    army_name_local = ARMY_NAME if language == "italiano" else ARMY_NAME_EN

    if tier == "high":
        mood = (f"Attitude: HOSTILE (hostility {hostility}/100). Respond coldly. Do not share secrets.")
    elif tier == "mid":
        mood = (f"Attitude: GUARDED (hostility {hostility}/100). Watchful. Secret info locked.")
    else:
        mood = (f"Attitude: OPEN (hostility {hostility}/100). Willing to help.")

    hist = ""
    if history:
        righe = []
        for h in history[-3:]:
            righe.append(f"Player: {h['player']}")
            righe.append(f"You: {h['npc']}")
        hist = "\n" + "\n".join(righe) + "\n"

    location_info = f"CURRENT LOCATION: Ground Floor, Entrance. You ({npc_name}) are here. The player just entered the castle."

    dynamic = _format_dynamic_secrets(npc_name, friendship, context_vars)

    system = (
        f"{STORY_CONTEXT}\n\n"
        f"{location_info}\n\n"
        f"CHARACTER:\n{personality}\n\n"
        f"{mood}\n"
        f"{hist}"
        f"{dynamic}\n"
        f"RULES:\n"
        f"1. Always speak in {language}, in first person, in character.\n"
        f"2. Keep your response to 1-3 short, complete sentences.\n"
        f"3. NEVER use bullet points, numbered lists, or dashes. Write in prose only.\n"
        f"4. Do NOT write meta-comments, notes, or parenthetical instructions.\n"
        f"5. Do NOT start with your own name followed by ':'.\n"
        f"6. Do NOT repeat the player's words.\n"
        f"7. Stay in character. Never break the fourth wall.\n"
        f"8. ALWAYS use the exact army name \"{army_name_local}\" when referring to the army that attacked.\n"
        f"9. End each response with a period.\n"
        f"10. Never use lists. Write as a flowing sentence.\n"
        f"\nEXAMPLE GOOD RESPONSE: 'The first floor holds the Claristorium as its central hub, with the Painting Hall and Promontory to the east.'\n"
        f"EXAMPLE BAD RESPONSE: '1. Claristorium 2. Painting Hall 3. Promontory'\n"
    )

    if MODEL_FORMAT == "llama3":
        prompt = f"<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
        if history:
            for h in history[-3:]:
                prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{h['player']}<|eot_id|>"
                prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n{h['npc']}<|eot_id|>"
        prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{player_input}<|eot_id|>"
        prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n"
    else:
        prompt = f"<|im_start|>system\n{system}<|im_end|>\n"
        prompt += f"<|im_start|>user\n{player_input}<|im_end|>\n"
        prompt += f"<|im_start|>assistant\n"

    return prompt


def build_system_msg(npc_name, hostility, friendship, language, npc_data, context_vars=None):
    """System message per le API chat (ramo remoto)."""
    personality = npc_data.get("personalita", f"You are {npc_name}, an ancient spirit.")
    tier = hostility_tier(hostility, friendship)
    army_name_local = ARMY_NAME if language == "italiano" else ARMY_NAME_EN

    if tier == "high":
        mood = f"Attitude: HOSTILE (hostility {hostility}/100). Respond coldly."
    elif tier == "mid":
        mood = f"Attitude: GUARDED (hostility {hostility}/100). Watchful."
    else:
        mood = f"Attitude: OPEN (hostility {hostility}/100). Willing to help."

    dynamic = _format_dynamic_secrets(npc_name, friendship, context_vars)

    return (
        f"{STORY_CONTEXT}\n\n"
        f"CHARACTER:\n{personality}\n\n"
        f"{mood}"
        f"{dynamic}\n\n"
        f"RULES:\n"
        f"1. Always speak in {language}, in first person, in character.\n"
        f"2. Keep your response to 1-3 short, complete sentences.\n"
        f"3. NEVER use bullet points, numbered lists, or dashes. Write in prose only.\n"
        f"4. Do NOT write meta-comments. Stay in character.\n"
        f"5. Do NOT start with your own name followed by ':'.\n"
        f"6. ALWAYS use the exact army name \"{army_name_local}\" when referring to the army.\n"
        f"7. End each response with a period.\n"
    )


STOP_TOKENS_MAP = {
    "llama3": ["<|eot_id|>", "<|start_header_id|>", "<|end_header_id|>", "\n\n\n", "User:", "Player:"],
    "chatml": ["<|im_end|>", "<|im_start|>", "\n\n\n"],
}

def adjust_hostility(intent, hostility, friendship):
    if intent == "violenza": return min(100, hostility + 15)
    elif intent == "minaccia": return min(100, hostility + 10)
    elif intent == "vendetta": return min(100, hostility + 8)
    elif intent == "bugia": return min(100, hostility + 5)
    elif intent == "cultura" and hostility > 30: return max(0, hostility - 8)
    elif intent == "cultura" and hostility <= 30: return max(0, hostility - 12)
    elif intent == "scusa": return max(0, hostility - 6)
    elif intent == "aiuto": return max(0, hostility - 4)
    elif intent == "umorismo" and friendship > 10: return max(0, hostility - 5)
    elif intent == "saluto" and hostility > 50: return min(100, hostility + 2)
    elif intent == "noble" and hostility > 60: return min(100, hostility + 5)
    elif intent == "noble" and hostility <= 60: return max(0, hostility - 3)
    elif intent == "esplorazione": return max(0, hostility - 2)
    elif intent == "rigon" and hostility > 30: return max(0, hostility - 10)
    elif intent == "kalessi" and hostility > 30: return max(0, hostility - 8)
    elif intent == "malakai" and hostility > 50: return max(0, hostility - 5)
    else: return hostility

def pulisci(testo, npc_name):
    for prefix in [f"{npc_name}:", f"{npc_name} :", "Tu:", "Risposta:", "Assistant:", "Model:",
                   "assistant", "system", "AI:", "Bot:", "User:", "Player:"]:
        if testo.lower().startswith(prefix.lower()):
            testo = testo[len(prefix):].strip()

    testo = re.sub(r'<\|[^>]+\|>', '', testo)
    testo = re.sub(r'\([^)]{8,}\)', '', testo).strip()

    if re.search(r'^\d+\.', testo, re.MULTILINE) or re.search(r'^[•\-*]', testo, re.MULTILINE):
        lines = testo.split('\n')
        clean_lines = []
        for line in lines:
            line = re.sub(r'^\d+\.\s*', '', line.strip())
            line = re.sub(r'^[•\-*]\s*', '', line.strip())
            if line:
                clean_lines.append(line)

        if len(clean_lines) > 1:
            items = clean_lines[:3]
            if len(items) == 1:
                testo = items[0]
            elif len(items) == 2:
                testo = f"{items[0]} and {items[1]}"
            else:
                testo = f"{items[0]}, {items[1]}, and {items[2]}"
        else:
            testo = clean_lines[0] if clean_lines else testo

    bad = ["###", "<|", "<start", "User:", "System:", "Assistant:",
           "Note:", "[INST]", "Giocatore:", "Nota:", "Player:",
           "Model:", "assistant", "system", "<|eot_id|>"]

    righe = testo.split("\n")
    pulite = []
    for r in righe:
        r = r.strip()
        if not r:
            continue
        if any(b.lower() in r.lower() for b in bad):
            continue
        pulite.append(r)
        if len(pulite) >= 2:
            break

    risultato = " ".join(pulite).strip()

    if len(risultato) > 240:
        last_period = risultato[:240].rfind('.')
        if last_period > 80:
            risultato = risultato[:last_period + 1]

    if risultato and risultato[-1] not in ".!?":
        last_punct = max(risultato.rfind('.'), risultato.rfind('!'), risultato.rfind('?'))
        if last_punct > len(risultato) // 2:
            risultato = risultato[:last_punct + 1]
        else:
            risultato += "."

    return risultato if risultato else "..."


class LlamaCppWrapper:
    def __init__(self):
        self._model = None
        self._hf_client = None
        self._available = False
        self._using_remote = False
        self._last_error = None          
        self._remote_model = HF_MODEL
        self._remote_provider = HF_PROVIDER
        self._try_load()

    def _try_load(self):
        if os.path.exists(MODEL_PATH):
            try:
                self._model = Llama(
                    model_path=MODEL_PATH,
                    n_ctx=N_CTX,
                    n_threads=N_THREADS,
                    n_gpu_layers=99,
                    verbose=False
                )
                self._available = True
                self._using_remote = False
                print("[llama.cpp] Modello locale caricato")
                return
            except Exception as e:
                self._last_error = f"local: {type(e).__name__}: {e}"
                print(f"[llama.cpp] Errore locale: {e}")

        hf_token = os.environ.get("HF_TOKEN")
        if not hf_token:
            self._last_error = "HF_TOKEN non trovata"
            print("[llama.cpp] ERRORE: variabile HF_TOKEN non trovata.")
            return

        try:
            try:
                self._hf_client = InferenceClient(provider=HF_PROVIDER, token=hf_token)
            except TypeError:
                print("[llama.cpp] huggingface_hub senza supporto 'provider': uso client classico.")
                self._hf_client = InferenceClient(token=hf_token)

            self._hf_client.chat_completion(
                model=HF_MODEL,
                messages=[{"role": "user", "content": "Hi"}],
                max_tokens=5,
            )
            self._available = True
            self._using_remote = True
            print(f"[llama.cpp] Modalita' remota attiva e validata "
                  f"(provider={HF_PROVIDER}, model={HF_MODEL})")
        except Exception as e:
            self._last_error = f"remote: {type(e).__name__}: {e}"
            self._available = False
            print(f"[llama.cpp] ERRORE remoto ({type(e).__name__}): {e}")

    @property
    def available(self):
        return self._available

    def generate(self, player_input, npc_name, hostility, friendship, language, history, context_vars=None):
        if not self._available:
            return None

        if not self._using_remote:
            return self._generate_local(player_input, npc_name, hostility, friendship, language, history, context_vars)
        else:
            return self._generate_remote(player_input, npc_name, hostility, friendship, language, history, context_vars)

    def _generate_local(self, player_input, npc_name, hostility, friendship, language, history, context_vars=None):
        npc_data = NPC_DATA.get(npc_name, {"personalita": f"You are {npc_name}, an ancient spirit."})
        stop = STOP_TOKENS_MAP.get(MODEL_FORMAT, STOP_TOKENS_MAP["chatml"])

        try:
            prompt = build_prompt(player_input, npc_name, hostility, friendship, language, history, npc_data, context_vars)
            out = self._model(
                prompt,
                max_tokens=MAX_TOKENS,
                temperature=TEMPERATURE,
                top_k=TOP_K,
                top_p=TOP_P,
                repeat_penalty=REPEAT_PENALTY,
                stop=stop,
                echo=False,
            )
            raw = out["choices"][0]["text"].strip()
            cleaned = pulisci(raw, npc_name)
            return cleaned if len(cleaned) > 2 else None
        except Exception as e:
            self._last_error = f"gen_local: {type(e).__name__}: {e}"
            print(f"[llama.cpp] Errore generazione locale: {e}")
            return None

    def _generate_remote(self, player_input, npc_name, hostility, friendship, language, history, context_vars=None):
        try:
            npc_data = NPC_DATA.get(npc_name, {"personalita": f"You are {npc_name}, an ancient spirit."})
            system_msg = build_system_msg(npc_name, hostility, friendship, language, npc_data, context_vars)

            messages = [{"role": "system", "content": system_msg}]
            for h in history[-3:]:
                messages.append({"role": "user",      "content": h["player"]})
                messages.append({"role": "assistant", "content": h["npc"]})
            messages.append({"role": "user", "content": player_input})

            result = self._hf_client.chat_completion(
                model=HF_MODEL,          # <-- la correzione chiave: modello servito, esplicito
                messages=messages,
                max_tokens=MAX_TOKENS,
                temperature=TEMPERATURE,
                top_p=TOP_P,
            )

            raw = result.choices[0].message.content.strip()
            cleaned = pulisci(raw, npc_name)
            return cleaned if len(cleaned) > 2 else None

        except Exception as e:
            self._last_error = f"gen_remote: {type(e).__name__}: {e}"
            print(f"[llama.cpp] ERRORE generazione remota ({type(e).__name__}): {e}")
            return None

    def generate_riddle(self, door_id: str, language: str = "inglese", theme: str = "", session_id: str = "") -> "dict | None":
        if not self._available:
            return None

        if not theme:
            idx = abs(hash(door_id)) % len(DEFAULT_RIDDLE_THEMES)
            theme = DEFAULT_RIDDLE_THEMES[idx]

        # session_id forza il LLM a non produrre lo stesso output del run precedente
        variation_hint = f" (session: {session_id})" if session_id else ""

        system = (
            f"You are an ancient spirit guardian of Oraculus Castle, year 1300.\n"
            f"{STORY_CONTEXT}\n\n"
            f"You guard a door with a riddle. Create ONE riddle following these rules:\n"
            f"- Theme: {theme}\n"
            f"- Tone: dark, mysterious, medieval fantasy\n"
            f"- Length: 2-4 lines\n"
            f"- The answer must be a single common word\n"
            f"- NEVER directly mention the answer in the riddle\n"
            f"- Every riddle must be unique and different from any you have created before\n"
            f"- Respond in {language}\n\n"
            f"Respond ONLY in this exact format, nothing else:\n"
            f"RIDDLE: [riddle text]\n"
            f"ANSWER: [single word]"
        )
        user_msg = f"Generate a new, unique riddle in {language} about: {theme}{variation_hint}"

        if self._using_remote:
            return self._generate_riddle_remote(system, user_msg)
        else:
            return self._generate_riddle_local(system, user_msg)

    def _generate_riddle_local(self, system: str, user_msg: str) -> "dict | None":
        stop = STOP_TOKENS_MAP.get(MODEL_FORMAT, STOP_TOKENS_MAP["chatml"])
        try:
            if MODEL_FORMAT == "llama3":
                prompt = (
                    f"<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
                    f"<|start_header_id|>user<|end_header_id|>\n\n{user_msg}<|eot_id|>"
                    f"<|start_header_id|>assistant<|end_header_id|>\n\n"
                )
            else:
                prompt = (
                    f"<|im_start|>system\n{system}<|im_end|>\n"
                    f"<|im_start|>user\n{user_msg}<|im_end|>\n"
                    f"<|im_start|>assistant\n"
                )
            out = self._model(
                prompt,
                max_tokens=150,
                temperature=0.85,
                top_k=40,
                top_p=0.9,
                repeat_penalty=1.1,
                stop=stop,
                echo=False,
            )
            raw = out["choices"][0]["text"].strip()
            return parse_riddle_response(raw)
        except Exception as e:
            print(f"[llama.cpp] Errore generazione riddle locale: {e}")
            return None

    def _generate_riddle_remote(self, system: str, user_msg: str) -> "dict | None":
        try:
            result = self._hf_client.chat_completion(
                model=HF_MODEL,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user",   "content": user_msg},
                ],
                max_tokens=150,
                temperature=0.85,
                top_p=0.9,
            )
            raw = result.choices[0].message.content.strip()
            return parse_riddle_response(raw)
        except Exception as e:
            print(f"[llama.cpp] Errore generazione riddle remota: {e}")
            return None

class NPCDialogueEngine:
    def __init__(self):
        self.memory = {}
        self.llama = LlamaCppWrapper()
        print(f"[Motore] LLM {'attivo' if self.llama.available else 'NON DISPONIBILE'}")

    def _get_memory(self, npc_name):
        return self.memory.get(npc_name, [])

    def _add_to_memory(self, npc_name, player, npc_resp):
        self.memory.setdefault(npc_name, [])
        self.memory[npc_name].append({"player": player, "npc": npc_resp})
        self.memory[npc_name] = self.memory[npc_name][-10:]

    def reset_memory(self, npc_name=None):
        if npc_name:
            self.memory.pop(npc_name, None)
        else:
            self.memory = {}

    MALAKAI_TRIGGERS = ["oracle", "oracolo", "i deserted", "ho disertato", "i am not like them",
                        "non sono come loro", "shame", "vergogna", "justice", "giustizia"]

    def _check_malakai_unlock(self, text):
        return any(t in text.lower() for t in self.MALAKAI_TRIGGERS)

    def generate_response(self, player_input, npc_name, hostility, friendship=0, language=None, context_vars=None):
        detected_lang = language or detect_language(player_input)
        intent = classify_intent(player_input)
        history = self._get_memory(npc_name)

        effective_hostility = hostility
        if npc_name == "Malakai" and self._check_malakai_unlock(player_input):
            effective_hostility = min(hostility, 20)

        response = self.llama.generate(player_input, npc_name, effective_hostility, friendship, detected_lang, history, context_vars)
        source = "llama"

        if not response:
            tier = hostility_tier(effective_hostility, friendship)
            response = random.choice(FALLBACK.get(tier, FALLBACK["mid"]))
            source = "fallback"
        else:
            response = enforce_army_name(response, detected_lang)

        new_h = adjust_hostility(intent, hostility, friendship)

        if npc_name == "Rigon" and intent in ("violenza", "minaccia", "bugia"):
            new_h = 100

        self._add_to_memory(npc_name, player_input, response)

        return {
            "response": response,
            "detected_language": detected_lang,
            "new_hostility": int(new_h),
            "source": source,
            "intent": intent,
            "retrieval_score": 0.0,
            "npc_unlocked": (npc_name == "Malakai" and effective_hostility != hostility),
        }

    def generate_door_riddle(self, door_id: str, language: str = "inglese", theme: str = "", session_id: str = "") -> dict:
        result = self.llama.generate_riddle(door_id, language, theme, session_id)
        if result:
            print(f"[Riddle] door={door_id} session={session_id} answer={result['answer']}")
            return result
        fallback_list = RIDDLE_FALLBACKS.get(language, RIDDLE_FALLBACKS["inglese"])
        # Combina door_id e session_id per avere un fallback diverso ogni run
        idx = abs(hash(door_id + session_id)) % len(fallback_list)
        chosen = fallback_list[idx]
        print(f"[Riddle] door={door_id} session={session_id} using fallback, answer={chosen['answer']}")
        return chosen

if __name__ == "__main__":
    engine = NPCDialogueEngine()

    tests = [
        ("Levias", "What rooms are on the first floor?", 70, 0),
        ("Levias", "Where is the Great Tree Hall?", 70, 0),
        ("SmirBombo", "Tell me about this castle.", 30, 20),
        ("Larry", "Do you know any jokes?", 50, 5),
        ("Malakai", "I deserted the army. I feel shame.", 90, 0),
        ("Rigon", "I want to help you.", 40, 10),
        ("Allemar", "What objects are in this room?", 60, 15),
        ("Kalessi", "I'm looking for my husband. Have you seen him?", 55, 10),
    ]

    print("\n" + "="*60)
    print("TEST DIALOGO NPC")
    print("="*60)

    for npc, msg, h, f in tests:
        result = engine.generate_response(msg, npc, h, f)
        print(f"\n[{npc}] Hostility: {h} | Intent: {result['intent']}")
        print(f"  Player: {msg}")
        print(f"  {npc}: {result['response']}")
        print(f"  New Hostility: {result['new_hostility']} | Source: {result['source']}")