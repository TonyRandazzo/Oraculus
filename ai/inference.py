import json, re, os, random, pickle
from llama_cpp import Llama

MODEL_PATH     = "models/Llama-3.2-1B-Instruct-Q6_K_L.gguf"
HF_REPO_ID    = "bartowski/Llama-3.2-1B-Instruct-GGUF"
HF_FILENAME   = "Llama-3.2-1B-Instruct-Q6_K_L.gguf"
MODEL_FORMAT   = "llama3"
N_CTX          = 4096
N_THREADS      = 4
MAX_TOKENS     = 80
TEMPERATURE    = 0.6
TOP_K          = 40
TOP_P          = 0.9
REPEAT_PENALTY = 1.1

ARMY_NAME = "Esercito della Sacra Croce"
ARMY_NAME_EN = "Army of the Holy Cross"
IMPERIAL_ARMY = "Army of the Imperial League"
IMPERIAL_ARMY_IT = "Esercito della Lega Imperiale"

STORY_CONTEXT = """
COMPLETE STORY CONTEXT:

PREAMBLE:

Year 1300. In a castle named "Oraculus' Castle" lives a noble family. They are extremely rich and cultured, lovers of arts and literature.

The head of the family is an Oracle, 127 years old. He possesses superhuman and spiritual powers. Through his prophecies, he saved his family, made them rich and powerful, and established connections with spirits who inhabit the castle and coexist harmoniously with the nobles. The family tree was extensive with many heirs.

A ferocious war has been raging for five years between two armies: the Army of the Imperial League and the Army of the Holy Cross.

During the war, the Oracle falls ill. His powers weaken and diminish. The entire family and all spirits barricade themselves in the castle to care for the old man.

The commander of the Army of the Holy Cross learns of the Oracle's existence and decides to kidnap him, exploiting his foresight to win the war.

The Oracle, though ill, vaguely foresees what is about to happen but inexplicably decides to say nothing. It is a voluntary choice. According to his visions and analysis, what is about to happen is terrible but necessary for the course of events.

Alone, he orders all spirits to hide. They have seen everything and know everything, but cannot intervene. Every spirit obeys without reluctance.

Days later, the army enters the castle, kidnaps the Oracle, kills all nobles who resist (exterminating the family), and loots the castle's riches.

From that day, the spirits inhabit the castle, hoping to contact the spirits of the dead nobles. They hate all humans, considering them stupid and bearers of violence and war.

START OF NARRATION (3 years after the events narrated above):

A young knight of the Army of the Holy Cross holds ideals very different from the rest of the soldiers. He decides to desert. He escapes from the army.

On his way, he encounters the Oracle's castle in ruins (the knight knows nothing of its history) and decides to take refuge and hide inside.

The entrance door closes behind him.

The knight immediately encounters a powerful spirit and realizes he is in danger. All spirits hate humans, especially those who belong to the Army of the Holy Cross.

THREE PATHS:
- EGOISTIC: Destroy, kill, escape.
- REDEMPTION: Show you are a decent human, but don't actively help. Semi-egoistic.
- HELPING: Truly help the spirits. Do genuine good deeds.

================================================================================
MAP DESCRIPTION - ORGANIZED BY FLOOR
================================================================================

========================================
GROUND FLOOR (Ruined, poorly lit)
========================================

The ground floor is divided into TWO WINGS: SOUTH WING and NORTH WING.
The two wings are NOT connected to each other on the ground floor.

--- SOUTH WING (GROUND FLOOR) ---
Sequential rooms from entrance:
1. ENTRANCE (GROUND FLOOR) - Player starts here. Levias is here.
2. Orc Den (GROUND FLOOR)
3. Great Tree Hall (GROUND FLOOR)
4. Malakai's Lair (GROUND FLOOR)

--- NORTH WING (GROUND FLOOR) ---
IMPORTANT: The North Wing is on GROUND FLOOR but is ONLY ACCESSIBLE from the FIRST FLOOR.
There is NO direct entrance from the ground floor entrance.

Rooms in North Wing (all on GROUND FLOOR):
1. Great Moon Garden (GROUND FLOOR)
2. Water Chamber (GROUND FLOOR)
3. Second Water Chamber (GROUND FLOOR)
4. Monolith (GROUND FLOOR)
5. Twisted Brambles Room (GROUND FLOOR) - Rigon is trapped here by Allemar

Locked doors in North Wing (GROUND FLOOR):
- One locked door between Second Water Chamber and Monolith
- One locked door between Monolith and Twisted Brambles Room

========================================
FIRST FLOOR (Well-preserved, regal, cultural area)
========================================

All rooms on FIRST FLOOR are well-lit with torches, chandeliers, and candelabras. Carpets and furnishings present.

Rooms on FIRST FLOOR:
1. Claristorium (FIRST FLOOR) - Central hub

From Claristorium (FIRST FLOOR):
- EAST wing (FIRST FLOOR):
  a. Painting Hall (FIRST FLOOR)
  b. Promontory (FIRST FLOOR)
  
- NORTH wing (FIRST FLOOR):
  a. Stars Hall (FIRST FLOOR)
  b. Music Hall (FIRST FLOOR)
  c. Papyrus Hall (FIRST FLOOR)
  d. East Exit (FIRST FLOOR)

Locked doors on FIRST FLOOR:
- One locked door between Music Hall (FIRST FLOOR) and Papyrus Hall (FIRST FLOOR)
- One locked door between Papyrus Hall (FIRST FLOOR) and East Exit (FIRST FLOOR)
- One locked door after East Exit (FIRST FLOOR)

========================================
UNDERGROUND FLOOR (Damp, mossy, very poorly lit)
========================================

All rooms on UNDERGROUND FLOOR are damp, with moss and water. Very poorly lit.

Access to UNDERGROUND FLOOR:
- From Entrance (GROUND FLOOR) - stairs lead DOWN to underground

Characters in UNDERGROUND FLOOR:
- Kalessi (Medusa, Rigon's wife) - wanders the underground
- Larry (Giant) - resides in the underground

========================================
SECRET INFORMATION (ONLY REVEALED WITH HIGH FRIENDSHIP OR LOW HOSTILITY)
========================================

The following information is SECRET. NPCs will ONLY reveal this information when:
- Friendship is HIGH (friendship > 60) OR
- Hostility is VERY LOW (hostility < 20)

NPCs may HINT at these secrets when hostility is low (hostility < 40) but NOT reveal them fully.

SECRET #1: Great Tree Hall Connection
- Great Tree Hall (GROUND FLOOR, South Wing) contains a SECRET PASSAGE that leads UP to Papyrus Hall (FIRST FLOOR)

SECRET #2: North Wing Access Points
- The North Wing (GROUND FLOOR) can be reached from the FIRST FLOOR via two connections:
  a. From Painting Hall (FIRST FLOOR) - hidden stairs lead DOWN to Great Moon Garden (GROUND FLOOR)
  b. From Papyrus Hall (FIRST FLOOR) - hidden stairs lead DOWN to Twisted Brambles Room (GROUND FLOOR)

SECRET #3: Stars Hall Bell Tower
- From Stars Hall (FIRST FLOOR), there is a SECRET ENTRANCE that leads UP to the bell tower

SECRET #4: Malakai's Lair Door
- In Malakai's Lair (GROUND FLOOR, South Wing), there is a LOCKED DOOR that leads to the last room of the UNDERGROUND FLOOR

SECRET #5: Papyrus Hall Passage
- Papyrus Hall (FIRST FLOOR) contains a SECRET PASSAGE that leads DOWN to Great Tree Hall (GROUND FLOOR, South Wing)

SECRET #6: Painting Hall Connection
- Painting Hall (FIRST FLOOR) has a SECRET STAIRCASE that leads DOWN to Great Moon Garden (GROUND FLOOR, North Wing)

========================================
SUMMARY TABLE BY FLOOR
========================================

GROUND FLOOR (South Wing): Entrance, Orc Den, Great Tree Hall, Malakai's Lair
GROUND FLOOR (North Wing): Great Moon Garden, Water Chamber, Second Water Chamber, Monolith, Twisted Brambles Room
FIRST FLOOR: Claristorium, Painting Hall, Promontory, Stars Hall, Music Hall, Papyrus Hall, East Exit
UNDERGROUND: Damp tunnels and chambers

================================================================================
CURRENT SCENE
================================================================================

The player is at the ENTRANCE on GROUND FLOOR.
Levias (the guardian demon) is also on GROUND FLOOR, near the entrance.
The player has just entered and met Levias.
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
        "info_segrete": "Complete castle map. Knows where all spirits are. Knows Rigon trapped in Twisted Brambles. Knows Malakai's location. Knows Kalessi is Rigon's wife in underground.",
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
            "You are trapped by Allemar in the Twisted Brambles room on ground floor North Wing.\n"
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
        "info_segrete": "Details of the Army of the Holy Cross attack, access to the last underground room",
        "unlock_condition": "Say trigger words: 'oracle', 'I deserted', 'shame', 'justice'",
        "personalita": (
            "You are Malakai. Deliberately violent. You want revenge. You don't listen to reason but have trigger words.\n"
            "You Always speak in the language detected from the player's message, disordered and chaotic. You insult, invent words. You may attack suddenly.\n"
            "You were the high priest. You wanted to kill the Oracle. You were punished and transformed.\n"
            "You are in Malakai's Lair on ground floor South Wing, after Great Tree Hall.\n"
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
            "You are in the UNDERGROUND floor, near the entrance from South Wing.\n"
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
            "You trapped Rigon in the Twisted Brambles room. You are in the Stars Hall on first floor.\n"
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
            "You are in the Orc Den on ground floor South Wing.\n"
        ),
    },
    "Gruko": {
        "info_segrete": "Location of orc treasure and secrets of the orc den",
        "unlock_condition": "Defeat in combat or show great strength",
        "personalita": (
            "You are Gruko, the fearsome chief of the orcs. You are big, strong, and brutal.\n"
            "You and your orcs occupy the Orc Den on ground floor South Wing.\n"
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

def build_prompt(player_input, npc_name, hostility, friendship, language, history, npc_data):
    personality = npc_data.get("personalita", f"You are {npc_name}.")
    info_segrete = npc_data.get("info_segrete", "")
    unlock = npc_data.get("unlock_condition", "")
    tier = hostility_tier(hostility, friendship)
    army_name_local = ARMY_NAME if language == "italiano" else ARMY_NAME_EN

    if tier == "high":
        mood = f"Attitude: HOSTILE (hostility {hostility}/100). Respond coldly. Do not share secrets."
    elif tier == "mid":
        mood = f"Attitude: GUARDED (hostility {hostility}/100). Watchful. Secret info locked."
    else:
        mood = f"Attitude: OPEN (hostility {hostility}/100). Willing to help."

    hist = ""
    if history:
        righe = []
        for h in history[-10:]:
            righe.append(f"Player: {h['player']}")
            righe.append(f"You: {h['npc']}")
        hist = "\nPREVIOUS CONVERSATION (remember this):\n" + "\n".join(righe) + "\n"

    location_info = f"CURRENT LOCATION: Ground Floor, Entrance. You ({npc_name}) are here. The player just entered the castle."

    system = (
        f"{STORY_CONTEXT}\n\n"
        f"{location_info}\n\n"
        f"CHARACTER:\n{personality}\n\n"
        f"{mood}\n"
        f"{hist}\n"
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
        f"11. Reference previous conversations when relevant.\n"
        f"\nEXAMPLE GOOD RESPONSE: 'The first floor holds the Claristorium as its central hub, with the Painting Hall and Promontory to the east.'\n"
        f"EXAMPLE BAD RESPONSE: '1. Claristorium 2. Painting Hall 3. Promontory'\n"
    )

    if MODEL_FORMAT == "llama3":
        prompt = f"<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
        if history:
            for h in history[-10:]:
                prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{h['player']}<|eot_id|>"
                prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n{h['npc']}<|eot_id|>"
        prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{player_input}<|eot_id|>"
        prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n"
    else:
        prompt = f"<|im_start|>system\n{system}<|im_end|>\n"
        if history:
            for h in history[-10:]:
                prompt += f"<|im_start|>user\n{h['player']}<|im_end|>\n"
                prompt += f"<|im_start|>assistant\n{h['npc']}<|im_end|>\n"
        prompt += f"<|im_start|>user\n{player_input}<|im_end|>\n"
        prompt += f"<|im_start|>assistant\n"

    return prompt

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
        self._available = False
        self._try_load()

    def _try_load(self):
        if not os.path.exists(MODEL_PATH):
            print(f"[llama.cpp] Modello non trovato in {MODEL_PATH}, avvio download da Hugging Face...")
            if not self._download_model():
                print("[llama.cpp] Download fallito, LLM non disponibile.")
                return

        try:
            print(f"[llama.cpp] Caricamento: {MODEL_PATH} ...")
            self._model = Llama(
                model_path=MODEL_PATH,
                n_ctx=N_CTX,
                n_threads=N_THREADS,
                n_gpu_layers=99,
                verbose=False,
            )
            self._available = True
            print(f"[llama.cpp] Pronto! Context: {N_CTX}, Max tokens: {MAX_TOKENS}")
        except Exception as e:
            print(f"[llama.cpp] Errore caricamento: {e}")

    def _download_model(self) -> bool:
        try:
            from huggingface_hub import hf_hub_download
            os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
            print(f"[llama.cpp] Download {HF_FILENAME} da {HF_REPO_ID} ...")
            downloaded_path = hf_hub_download(
                repo_id=HF_REPO_ID,
                filename=HF_FILENAME,
                local_dir=os.path.dirname(MODEL_PATH),
                local_dir_use_symlinks=False,
            )
            print(f"[llama.cpp] Download completato: {downloaded_path}")
            return True
        except Exception as e:
            print(f"[llama.cpp] Errore download: {e}")
            return False
        
class NPCDialogueEngine:
    def __init__(self, memory_file="npc_memory.pkl"):
        self.memory = {}
        self.memory_file = memory_file
        self.llama = LlamaCppWrapper()
        self.load_memory()
        print(f"[Motore] LLM {'attivo' if self.llama.available else 'NON DISPONIBILE'}")

    def _get_memory(self, npc_name):
        return self.memory.get(npc_name, [])

    def _add_to_memory(self, npc_name, player, npc_resp):
        self.memory.setdefault(npc_name, [])
        self.memory[npc_name].append({"player": player, "npc": npc_resp})
        self.memory[npc_name] = self.memory[npc_name][-50:]
        self.save_memory()

    def reset_memory(self, npc_name=None):
        if npc_name:
            self.memory.pop(npc_name, None)
        else:
            self.memory = {}
        self.save_memory()

    def save_memory(self):
        try:
            with open(self.memory_file, "wb") as f:
                pickle.dump(self.memory, f)
        except Exception as e:
            print(f"[Memoria] Errore salvataggio: {e}")

    def load_memory(self):
        if os.path.exists(self.memory_file):
            try:
                with open(self.memory_file, "rb") as f:
                    self.memory = pickle.load(f)
                print(f"[Memoria] Caricata da {self.memory_file}")
            except Exception as e:
                print(f"[Memoria] Errore caricamento: {e}")
                self.memory = {}

    MALAKAI_TRIGGERS = ["oracle", "oracolo", "i deserted", "ho disertato", "i am not like them", 
                        "non sono come loro", "shame", "vergogna", "justice", "giustizia"]

    def _check_malakai_unlock(self, text):
        return any(t in text.lower() for t in self.MALAKAI_TRIGGERS)

    def generate_response(self, player_input, npc_name, hostility, friendship=0, language=None, context_vars=None, external_history=None):
        detected_lang = language or detect_language(player_input)
        intent = classify_intent(player_input)
        
        if external_history is not None:
            history = external_history
        else:
            history = self._get_memory(npc_name)

        effective_hostility = hostility
        if npc_name == "Malakai" and self._check_malakai_unlock(player_input):
            effective_hostility = min(hostility, 20)

        response = self.llama.generate(player_input, npc_name, effective_hostility, friendship, detected_lang, history)
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

        if external_history is None:
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