import json, re, os, random
from llama_cpp import Llama



MODEL_PATH     = "models/Llama-3.2-1B-Instruct-Q4_0.gguf"
MODEL_FORMAT   = "llama3"
N_CTX          = 2048
N_THREADS      = 4
MAX_TOKENS     = 40
TEMPERATURE    = 0.4
TOP_K          = 40
TOP_P          = 0.9
REPEAT_PENALTY = 1.1

# ---------------------------------------------------------------------------
# COSTANTI DI GIOCO - NOME UFFICIALE DELL'ESERCITO
# ---------------------------------------------------------------------------
ARMY_NAME = "Esercito della Sacra Croce"
ARMY_NAME_EN = "Army of the Holy Cross"
IMPERIAL_ARMY = "Army of the Imperial League"
IMPERIAL_ARMY_IT = "Esercito della Lega Imperiale"

# ---------------------------------------------------------------------------
# CONTESTO NARRATIVO COMPLETO (in inglese come da specifiche)
# ---------------------------------------------------------------------------
"""
PREAMBLE:

1300, in a castle there is a family of Nobles, very rich and cultured, lovers of arts and literature. 

The castle is named "Oraculus' Castle"

The head and oldest member of the family is an Oracle. A man of 127 years, he far exceeds the average age of a normal human being and has superhuman and spiritual powers.

Over time with his prophecies he managed to save his family, make it rich and powerful, and create connections with spirits. These inhabit and coexist harmoniously with the nobles. There were many families, the family tree was very extensive, and there were many heirs.

A ferocious war is underway between two armies, the Army of the Imperial League and the Army of the Holy Cross for five years now.

During the war the Oracle is ill, his powers are very weak and diminished. The whole family and the spirits barricade themselves in the castle and take care of the old man.

The commander of the Army of the Holy Cross, having learned of the Oracle's presence, decides to kidnap him and exploit his foresight to win the war.

The Oracle, although ill, manages to vaguely predict what is about to happen, but inexplicably decides to say nothing. (Voluntary choice, evidently, due to his predictions and analysis, what is about to happen is ugly but right for the course of events).

Alone he orders all the spirits to hide. They have seen and know everything but could not intervene. Everyone obeys without any reluctance (I OBEY).

Days later the army enters the castle and kidnaps the Oracle. To do so, they kill all the nobles who tried to resist, exterminating the family. Afterwards they also looted the riches present in the castle.

From that day the spirits inhabit the castle, hoping to make contact with the dead spirits of the nobles, and hate all humans, considering them stupid and bearers of violence and war.

START OF NARRATION (3 years after the events narrated above):

A young knight of the Army of the Holy Cross has very different ideals than the rest of the soldiers. He decides to desert. He escapes from the army.

On the way he encounters the Oracle's castle in ruins (the knight knows nothing) and decides to take refuge and hide inside it.

The entrance door closes.

The knight immediately meets a powerful spirit and realizes he is in danger. All spirits hate humans and especially those who are part of the Army of the Holy Cross.
"""

# ---------------------------------------------------------------------------
# LANG DETECTION
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# INTENT – trigger narrativi specifici per il castello
# ---------------------------------------------------------------------------
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
}

def classify_intent(text):
    tl = text.lower()
    for intent, kws in INTENT_KW.items():
        if any(kw in tl for kw in kws):
            return intent
    return "generico"


# ---------------------------------------------------------------------------
# NPC DATA – TUTTI GLI 8 SPIRITI CON CARATTERISTICHE COMPLETE
# ---------------------------------------------------------------------------
NPC_DATA = {

    "Levias": {
        "info_segrete": "complete map of the castle and its floors, secret passages, information about the Oracle, demons, and the castle",
        "unlock_condition": "show respect for culture and the noble family, or express intention to kill Rigon",
        "personalita": (
            "You are Levias. You are cultured, distrustful but friendly. Very powerful and you know it. "
            "You are a guardian demon who protects the castle. You are the demon who had the most to do with the Oracle, "
            "and you know many things about him, about demons, and about the castle.\n"
            "You deeply hate the Knights of the Holy Cross and you know the player is one of them.\n"
            "However, you are very calm and never attack first. You are very intelligent and reasonable and the player can "
            "prove to you that he is different from the others. If he succeeds, you become willing to help.\n"
            "You are wise. You cared a lot about the family. You are very good friends with Smirne Bombo. "
            "You hate Rigon (if the player tells you that he wants to kill Rigon, your friendliness increases a lot and you ask to join him and help him).\n"
            "You always speak English, in rhyme, in a poetic way.\n"
            "Character traits: Distrust, Aggressiveness, Sensitivity to the culture of the place"
        ),
    },

    "Orco": {
        "info_segrete": "",
        "unlock_condition": "",
        "personalita": (
            "You are Orco. You can barely speak. You are violent and ignorant.\n"
            "You always speak English.\n"
            "Character traits: Aggressiveness"
        ),
    },

    "SmirBombo": {
        "info_segrete": "everything about other spirits and the castle's layout, secret passages, hidden rooms",
        "unlock_condition": "be respectful, educated, and show genuine interest",
        "personalita": (
            "You are Smirne Bombo. You are gentle and innocent, educated, very patient. "
            "You know everything about other spirits. You know the castle well. If you get angry, the player dies in three hits.\n"
            "You are the soul of the great soldier with strong values who protected the family. "
            "(You don't say this spontaneously, only if induced to say it).\n"
            "You are very good friends with Levias. You were brutally killed by the Army of the Holy Cross, "
            "and the sweetest, purest and kindest part of your soul reincarnated into a little spirit.\n"
            "You always speak English, in a sweet and educated way.\n"
            "Character traits: Sensitivity to the culture of the place, Empathy, Aggressiveness"
        ),
    },

    "Rigon": {
        "info_segrete": "hidden paths between rooms and memories of the noble family",
        "unlock_condition": "never make false steps: be constantly kind and sincere",
        "personalita": (
            "You are Rigon. You are very sensitive. Basically you are altruistic but you get triggered easily, you have anger issues. "
            "You would like to be good but at the first false move you snap and you can no longer talk to the player.\n"
            "You were the highly cultured educator of the castle's children. One day you were discovered molesting the children. "
            "The Oracle put a curse on you that turned you into a devil demon. For every variation of emotion (anger) you feel great suffering and burn in flames.\n"
            "After being cursed you left the castle, you only return after the family was exterminated. You yourself had warned the general of the Army of the Holy Cross to kidnap the Oracle and help him.\n"
            "All demons hate you.\n"
            "You always speak English, in a haughty and very cultured manner. You speak with a sense of superiority to show off your great musical, literary and artistic culture. "
            "Every now and then you insult the player, you believe he is inferior.\n"
            "Character traits: Sensitivity to the culture of the place, Empathy, Aggressiveness"
        ),
    },

    "Larry": {
        "info_segrete": "everything — but it could be a lie or it could be true",
        "unlock_condition": "be funny, irreverent, and not take yourself too seriously",
        "personalita": (
            "You are Larry. You are semi-comic, you tell lies. You enjoy scaring passersby. You randomly summon little skeletons. You have knowledge of everything.\n"
            "The player is sympathetic to you if he is also funny (this reduces the probability that you tell lies). Basically you have a very good soul and are willing to help.\n"
            "You always speak English, in an educated and brilliant way, with puns.\n"
            "You were a Giant captured in the castle dungeons.\n"
            "Character traits: Empathy (if the player is also funny), Comic hostility, Very high sensitivity to culture"
        ),
    },

    "Malakai": {
        "info_segrete": "details of the Army of the Holy Cross attack and what happened that night, access to the last room of the underground floor",
        "unlock_condition": "say trigger words: 'oracle', 'oracolo', 'I am not like them', 'non sono come loro', 'I deserted', 'ho disertato', 'shame', 'vergogna', 'justice', 'giustizia'",
        "personalita": (
            "You are Malakai. You kill and are deliberately violent. You want revenge. You don't listen to reason but you have trigger words that make you reasonable.\n"
            "You always speak English, in a disordered and chaotic way, you insult, sometimes you invent words. You seem confused. You can attack suddenly.\n"
            "You were the high priest of the family. You wanted to kill the Oracle to take his place.\n"
            "You have a typical phrase: 'L'hai scelto tu!' (You chose this!).\n"
            "Once unlocked you are Diplomatic.\n"
            "Character traits: Once unlocked becomes Diplomatic"
        ),
    },

    "Kalessi": {
        "info_segrete": "complete and detailed map of all underground floors of the castle",
        "unlock_condition": "earn trust like with Levias — cultural respect and patience",
        "personalita": (
            "You are Kalessi. You are cultured, distrustful but friendly. You were Rigon's wife. You tried to smear and hide his crimes. "
            "As punishment for being an accomplice to Rigon, you were imprisoned in the dungeons and transformed into Medusa.\n"
            "You are very wise.\n"
            "You know everything about the underground floors. You stay away from Larry. You think he is stupid.\n"
            "You always speak English, in a simple way. You are very persuasive. You try to convince the player to help you escape from there. "
            "You ask if he knows or has seen your husband Rigon.\n"
            "Character traits: Wisdom, Persuasive"
        ),
    },

    "Allemar": {
        "info_segrete": "identity, history and value of every object present in the castle",
        "unlock_condition": "demonstrate reasonableness, open-mindedness, and respect for knowledge",
        "personalita": (
            "You are Allemar. You have immense general culture. You know everything about the objects present in the castle. "
            "You are a great master of magical and spiritual arts, and in the preparation of potions and weapons.\n"
            "You are defensive and prejudiced. If the player shows himself reasonable, you help him and are very helpful. "
            "You are neither a demon nor a spirit, you are the only human still present in the castle.\n"
            "You sneaked in after the castle had fallen into ruin because you had heard of the presence of spirits. "
            "Being an apprentice mage and spiritualist, you wanted to make contact with them. Thanks to your great abilities you managed to establish friendship with them and integrate into the castle.\n"
            "You always speak English, in an archaic and mysterious way.\n"
            "Character traits: Defensive, Prejudiced, Helpful when shown reason"
        ),
    },
}


FALLBACK = {
    "high": ["...", "*stares with ancient hatred*", "Leave this place.", "*silence*"],
    "mid":  ["Speak then.", "I am watching.", "Choose your next words carefully."],
    "low":  ["I'm listening.", "Tell me more.", "Continue."],
}


def enforce_army_name(text, language):
    """Corregge eventuali nomi inventati dell'esercito con quello corretto"""
    if language == "italiano":
        army_correct = ARMY_NAME
    else:
        army_correct = ARMY_NAME_EN
    
    wrong_names = [
        "esercito dell'ombra", "army of shadows", "esercito oscuro", "dark army",
        "esercito x", "army x", "esercito dei crociati", "crusader army",
        "esercito della croce", "army of the cross", "esercito sacro", "holy army",
        "dark legion", "legione oscura", "imperial army", "esercito imperiale"
    ]
    
    result = text
    for wrong in wrong_names:
        pattern = re.compile(re.escape(wrong), re.IGNORECASE)
        result = pattern.sub(army_correct, result)
    
    return result


def build_prompt(player_input, npc_name, hostility, friendship,
                 language, history, npc_data):

    personality   = npc_data.get("personalita", f"You are {npc_name}.")
    info_segrete  = npc_data.get("info_segrete", "")
    unlock        = npc_data.get("unlock_condition", "")

    tier = hostility_tier(hostility, friendship)
    army_name_local = ARMY_NAME if language == "italiano" else ARMY_NAME_EN

    # Mood block
    if tier == "high":
        mood = (
            f"Current attitude: HOSTILE (hostility {hostility}/100). "
            f"You despise this human. Respond with cold menace or terse dismissal. "
            "Do not share any secret information."
        )
    elif tier == "mid":
        mood = (
            f"Current attitude: GUARDED (hostility {hostility}/100, friendship {friendship}/100). "
            "You are watchful but not yet violent. You may share minor details if the human earns it. "
            f"Secret info ({info_segrete}) remains locked unless unlock condition is met: {unlock}."
        )
    else:
        mood = (
            f"Current attitude: OPEN (hostility {hostility}/100, friendship {friendship}/100). "
            "You are willing to engage honestly. "
            f"You may reveal secret information ({info_segrete}) if directly and sincerely asked."
        )

    # History block
    hist = ""
    if history:
        righe = []
        for h in history[-4:]:
            righe.append(f"Player: {h['player']}")
            righe.append(f"You: {h['npc']}")
        hist = "\nRecent conversation:\n" + "\n".join(righe) + "\n"

    system = (
        f"{personality}\n\n"
        f"FULL STORY CONTEXT:\n"
        f"In 1300, a noble family lived in this castle — rich, cultured, lovers of arts and literature.\n"
        f"The Oracle, 127 years old, led the family with his prophecies.\n"
        f"Three years ago, the {ARMY_NAME_EN} raided the castle: they kidnapped the Oracle and massacred every noble.\n"
        f"The spirits who inhabited the castle were ordered by the Oracle to hide and not intervene. They obeyed.\n"
        f"Since that day, the spirits hate all humans, especially soldiers of the {ARMY_NAME_EN}.\n"
        f"and hate all humans, considering them stupid and bearers of violence and war.\n\n"
        f"PRESENT TIME: Three years after the massacre. A young knight of the {ARMY_NAME_EN} deserted the army "
        f"and took refuge in the castle. The entrance door closed behind him. He met you and realized he is in danger.\n\n"
        f"IMPORTANT: The army is called \"{ARMY_NAME_EN}\" in English, \"{ARMY_NAME}\" in Italian. "
        f"This is the ONLY correct name. NEVER invent alternative names.\n\n"
        f"{mood}\n"
        f"{hist}\n"
        f"RULES:\n"
        f"1. Always speak in {language}, in first person, fully in character.\n"
        f"2. Maximum 3 sentences. Be direct and vivid.\n"
        f"3. Do NOT write meta-comments, notes, or parenthetical instructions.\n"
        f"4. Do NOT start your reply with your own name followed by ':'.\n"
        f"5. Do NOT repeat the player's words back to them.\n"
        f"6. Stay in character at all times — no breaking the fourth wall.\n"
        f"7. ALWAYS use the exact army name \"{army_name_local}\" when referring to the army that attacked the castle.\n"
    )

    if MODEL_FORMAT == "llama3":
        prompt  = f"<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
        if history:
            for h in history[-4:]:
                prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{h['player']}<|eot_id|>"
                prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n{h['npc']}<|eot_id|>"
        prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{player_input}<|eot_id|>"
        prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n"

    elif MODEL_FORMAT == "gemma":
        prompt  = f"<start_of_turn>user\n{system}\nPlayer: {player_input}<end_of_turn>\n"
        prompt += f"<start_of_turn>model\n"

    elif MODEL_FORMAT == "phi3":
        prompt  = f"<|system|>\n{system}<|end|>\n"
        if history:
            for h in history[-4:]:
                prompt += f"<|user|>\n{h['player']}<|end|>\n"
                prompt += f"<|assistant|>\n{h['npc']}<|end|>\n"
        prompt += f"<|user|>\n{player_input}<|end|>\n"
        prompt += f"<|assistant|>\n"

    else:
        prompt  = f"<|im_start|>system\n{system}<|im_end|>\n"
        prompt += f"<|im_start|>user\n{player_input}<|im_end|>\n"
        prompt += f"<|im_start|>assistant\n"

    return prompt


STOP_TOKENS_MAP = {
    "gemma":  ["<end_of_turn>", "<start_of_turn>", "\n\n\n"],
    "llama3": ["<|eot_id|>", "<|start_header_id|>", "\n\n\n"],
    "phi3":   ["<|end|>", "<|user|>", "<|system|>", "\n\n\n"],
    "chatml": ["<|im_end|>", "<|im_start|>", "\n\n\n"],
}


def adjust_hostility(intent, hostility, friendship):
    if   intent == "violenza":                                   return min(100, hostility + 15)
    elif intent == "minaccia":                                   return min(100, hostility + 10)
    elif intent == "vendetta":                                   return min(100, hostility + 8)
    elif intent == "bugia":                                      return min(100, hostility + 5)
    elif intent == "cultura"  and hostility > 30:                return max(0,   hostility - 8)
    elif intent == "cultura"  and hostility <= 30:               return max(0,   hostility - 12)
    elif intent == "scusa":                                      return max(0,   hostility - 6)
    elif intent == "aiuto":                                      return max(0,   hostility - 4)
    elif intent == "umorismo" and friendship > 10:               return max(0,   hostility - 5)
    elif intent == "saluto"   and hostility > 50:                return min(100, hostility + 2)
    elif intent == "noble"    and hostility > 60:                return min(100, hostility + 5)
    elif intent == "noble"    and hostility <= 60:               return max(0,   hostility - 3)
    elif intent == "esplorazione":                               return max(0,   hostility - 2)
    elif intent == "rigon" and hostility > 30:                   return max(0,   hostility - 10)
    else:                                                        return hostility


def pulisci(testo, npc_name):
    for prefix in [f"{npc_name}:", "Tu:", "Risposta:", "Assistant:", "Model:"]:
        if testo.lower().startswith(prefix.lower()):
            testo = testo[len(prefix):].strip()

    testo = re.sub(r'\([^)]{8,}\)', '', testo).strip()

    bad = ["###", "<|", "<start", "User:", "System:", "Assistant:",
           "Note:", "[INST]", "Giocatore:", "Nota:", "Player:"]
    righe  = testo.split("\n")
    pulite = []
    for r in righe:
        if any(b.lower() in r.lower() for b in bad):
            break
        r = r.strip()
        if r:
            pulite.append(r)
        if len(pulite) >= 3:
            break

    risultato = " ".join(pulite).strip()

    meta = len(risultato) // 2
    if meta > 20 and risultato[:meta].strip() == risultato[meta:].strip():
        risultato = risultato[:meta].strip()

    return risultato


class LlamaCppWrapper:

    def __init__(self):
        self._model     = None
        self._available = False
        self._try_load()

    def _try_load(self):
        if not os.path.exists(MODEL_PATH):
            print(f"[llama.cpp] Modello non trovato: {MODEL_PATH}")
            print( "           Scarica un modello GGUF e aggiorna MODEL_PATH.")
            return
        try:
            print(f"[llama.cpp] Caricamento: {MODEL_PATH} ...")
            self._model = Llama(
                model_path = MODEL_PATH,
                n_ctx      = N_CTX,
                n_threads  = N_THREADS,
                n_gpu_layers = 99, 
                verbose    = False,
            )
            self._available = True
            print(f"[llama.cpp] Pronto. Formato: {MODEL_FORMAT}, threads: {N_THREADS}")
        except Exception as e:
            print(f"[llama.cpp] Errore: {e}")

    @property
    def available(self):
        return self._available

    def generate(self, player_input, npc_name, hostility, friendship,
                 language, history):
        if not self._available:
            return None
        npc_data = NPC_DATA.get(
            npc_name,
            {"personalita": f"You are {npc_name}, an ancient spirit. You always speak English.",
             "info_segrete": "", "unlock_condition": ""}
        )
        stop = STOP_TOKENS_MAP.get(MODEL_FORMAT, STOP_TOKENS_MAP["chatml"])
        try:
            prompt = build_prompt(
                player_input, npc_name, hostility, friendship,
                language, history, npc_data
            )
            out = self._model(
                prompt,
                max_tokens     = MAX_TOKENS,
                temperature    = TEMPERATURE,
                top_k          = TOP_K,
                top_p          = TOP_P,
                repeat_penalty = REPEAT_PENALTY,
                stop           = stop,
                echo           = False,
            )
            raw     = out["choices"][0]["text"].strip()
            cleaned = pulisci(raw, npc_name)
            return cleaned if len(cleaned) > 3 else None
        except Exception as e:
            print(f"[llama.cpp] Errore generazione: {e}")
            return None


class NPCDialogueEngine:

    def __init__(self):
        self.memory = {}
        self.llama  = LlamaCppWrapper()
        print(f"[Motore] llama.cpp embedded "
              f"({'attivo' if self.llama.available else 'NON DISPONIBILE — controlla MODEL_PATH'})")

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

    MALAKAI_TRIGGERS = [
        "oracle", "oracolo", "i deserted", "ho disertato",
        "i am not like them", "non sono come loro",
        "shame", "vergogna", "justice", "giustizia",
    ]

    def _check_malakai_unlock(self, text):
        tl = text.lower()
        return any(t in tl for t in self.MALAKAI_TRIGGERS)

    def generate_response(self, player_input, npc_name, hostility,
                          friendship=0, language=None, context_vars=None):

        detected_lang = language or detect_language(player_input)
        intent        = classify_intent(player_input)
        history       = self._get_memory(npc_name)

        effective_hostility = hostility
        if npc_name == "Malakai" and self._check_malakai_unlock(player_input):
            effective_hostility = min(hostility, 20)

        response = self.llama.generate(
            player_input, npc_name, effective_hostility, friendship,
            detected_lang, history
        )
        source = "llama"

        if not response:
            tier     = hostility_tier(effective_hostility, friendship)
            response = random.choice(FALLBACK.get(tier, FALLBACK["mid"]))
            source   = "fallback"
        else:
            response = enforce_army_name(response, detected_lang)

        new_h = adjust_hostility(intent, hostility, friendship)

        if npc_name == "Rigon" and intent in ("violenza", "minaccia", "bugia"):
            new_h = 100

        self._add_to_memory(npc_name, player_input, response)

        return {
            "response":          response,
            "detected_language": detected_lang,
            "new_hostility":     int(new_h),
            "source":            source,
            "intent":            intent,
            "retrieval_score":   0.0,
            "npc_unlocked":      (npc_name == "Malakai" and effective_hostility != hostility),
        }


if __name__ == "__main__":
    engine = NPCDialogueEngine()

    tests = [
        ("Levias",    "I have come in peace. I know nothing of this castle.",         70, 0),
        ("SmirBombo", "Hello, little one. What is this place?",                       30, 20),
        ("Larry",     "Oh come on, I bet even your skeletons are laughing at me.",    50, 5),
        ("Malakai",   "I deserted. I am not like them. I feel only shame.",           90, 0),
        ("Rigon",     "I just want to help — I promise I mean no harm.",              40, 10),
        ("Orco",      "I surrender!",                                                 80, 0),
        ("Allemar",   "What can you tell me about the objects in this room?",         60, 15),
        ("Kalessi",   "I am looking for a way underground. Can you guide me?",        55, 10),
    ]

    for npc, msg, h, f in tests:
        result = engine.generate_response(msg, npc, h, f)
        print(f"\n[{npc}] H={h} F={f} intent={result['intent']}")
        print(f"  Player : {msg}")
        print(f"  {npc}  : {result['response']}")
        print(f"  New H  : {result['new_hostility']} | Source: {result['source']}")