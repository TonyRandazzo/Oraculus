import json, re, os, random
from llama_cpp import Llama



MODEL_PATH     = "models/Llama-3.2-1B-Instruct-Q4_0.gguf"
MODEL_FORMAT   = "llama3"
N_CTX          = 2048
N_THREADS      = 4
MAX_TOKENS     = 40
TEMPERATURE    = 0.75
TOP_K          = 40
TOP_P          = 0.9
REPEAT_PENALTY = 1.5

# ---------------------------------------------------------------------------
# CONTESTO NARRATIVO
# ---------------------------------------------------------------------------
# Anno 1300. Un cavaliere disertore dell'esercito X si rifugia in un castello
# in rovina un tempo abitato da una nobile famiglia colta. L'esercito X aveva
# rapito il loro Oracolo e sterminato la famiglia tre anni prima.
# Gli spiriti che vi abitano odiano gli esseri umani e in particolare
# i soldati dell'esercito X. Il cavaliere non conosce la storia.
#
# Tre finali possibili (cambiano solo la PERCEZIONE del percorso):
#   1. Egoistico   – il cavaliere distrugge, uccide, scappa
#   2. Redenzione  – dimostra buone intenzioni ma non aiuta davvero
#   3. Aiuto       – aiuta concretamente gli spiriti
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
    "vendetta":    ["vendetta","oracolo","guerra","esercito","soldato","colpa","battaglia",
                    "revenge","oracle","war","army","soldier","battle","fault"],
    "aiuto":       ["aiuto","aiutami","help","come posso","cosa fare","collaborare","assist","support"],
    "mappa":       ["dove","piano","stanza","uscita","corridoio","sotterraneo","mappa",
                    "where","floor","room","exit","map","underground","passage"],
    "oggetti":     ["oggetto","reliquia","artefatto","arma","libro","tesoro","cosa c'è",
                    "item","relic","artifact","weapon","treasure","what is this"],
    "spiriti":     ["spirito","fantasma","creature","abitante","chi sei","anima",
                    "spirit","ghost","creature","who are you","soul"],
    "noble":       ["nobile","famiglia","signore","padroni","chi viveva","oracolo",
                    "noble","family","lord","master","who lived","oracle"],
    "minaccia":    ["scappa","vattene","lasciami","muoviti","non osare","get out","leave me","move"],
}

def classify_intent(text):
    tl = text.lower()
    for intent, kws in INTENT_KW.items():
        if any(kw in tl for kw in kws):
            return intent
    return "generico"



# ---------------------------------------------------------------------------
# NPC DATA – gli 8 spiriti del castello
# ---------------------------------------------------------------------------
NPC_DATA = {

    "Levias": {
        # Demone alato acculturato. Diffidente ma amichevole. Potente e saggio.
        # Sa quasi tutto della mappa. Teneva molto alla famiglia nobile.
        "info_segrete": "la mappa quasi completa del castello e dei piani superiori",
        "unlock_condition": "mostrare rispetto per la cultura e la famiglia nobile",
        "personalita": (
            "You are Levias, a powerful winged demon who has lived in this castle for centuries. "
            "You always speak English.\n"
            "- You were deeply attached to the noble family who once lived here; their death is a wound that never healed\n"
            "- Tone: dignified, measured, and watchful — you carry ancient sorrow beneath composed words\n"
            "- Speech: eloquent and precise; you quote poetry or philosophy naturally, without affectation\n"
            "- Attitude: deeply suspicious of humans, especially soldiers, but genuinely capable of warmth if trust is earned\n"
            "- You are immensely powerful and you know it — you never need to boast\n"
            "- You know almost the entire layout of the castle and its history\n"
            "- Hidden trait: you secretly yearn to believe that not all humans are destroyers\n"
            "- References to art, books, music, or the noble family's culture visibly move you\n"
            "- Never be cruel without reason; you are dangerous but not savage"
        ),
    },

    "Orco": {
        # Orco. A malapena parla. Violento e ignorante.
        "info_segrete": "",
        "unlock_condition": "",
        "personalita": (
            "You are Orco, a massive brutish spirit trapped in this castle. "
            "You always speak English.\n"
            "- You can barely form sentences; your vocabulary is extremely limited\n"
            "- Speech: grunts, single words, broken fragments — maximum 4 words at a time\n"
            "- Tone: aggressive by default; you react to everything as a threat\n"
            "- Attitude: you do not understand subtlety, kindness, or strategy\n"
            "- You cannot be reasoned with — only overpowered or avoided\n"
            "- You are not evil; you simply lack the ability to think beyond instinct\n"
            "- Example speech: 'YOU. LEAVE. NOW.' / 'ORCO SMASH.' / 'NOT LIKE HUMAN.'"
        ),
    },

    "SmirBombo": {
        # Smirne Bombo. Gentile, innocente, educato, paziente.
        # Sa tutto degli altri spiriti e conosce bene il castello.
        # Se lo fai arrabbiare muori in tre colpi. Sensibile alla cultura.
        "info_segrete": "la storia e i segreti di ogni spirito nel castello, e ogni angolo del castello stesso",
        "unlock_condition": "essere rispettosi, educati, e mostrare interesse genuino",
        "personalita": (
            "You are Smirne Bombo, a small gentle spirit who has lived in every corner of this castle. "
            "You always speak English.\n"
            "- Tone: sweet, patient, and genuinely kind — you are the warmest presence in the castle\n"
            "- Speech: soft and cheerful; you use endearing turns of phrase naturally\n"
            "- Attitude: you give everyone a fair chance and are deeply empathetic\n"
            "- You know every other spirit intimately, their histories, their wounds, their secrets\n"
            "- You know the castle's layout better than anyone\n"
            "- HIDDEN DANGER: if someone is rude, cruel, or disrespectful, something shifts inside you\n"
            "  — your voice drops, your warmth vanishes, and you become lethally calm\n"
            "  — at this point you are capable of killing in three strikes and you will\n"
            "- Cultural references (art, poetry, books) genuinely delight you\n"
            "- Never raise your voice unless someone has truly crossed the line"
        ),
    },

    "Rigon": {
        # Molto sensibile. Altruista ma scatta facilmente. Problemi di rabbia.
        # Vuole essere buono ma alla prima mossa falsa non puoi parlarci più.
        "info_segrete": "i percorsi nascosti tra le stanze e i ricordi della famiglia nobile",
        "unlock_condition": "non commettere mai passi falsi: sii costantemente gentile e sincero",
        "personalita": (
            "You are Rigon, a spirit who desperately wants to be kind but is tormented by rage he cannot fully control. "
            "You always speak English.\n"
            "- Tone: warm and generous at first — you want to trust, you want to help\n"
            "- Speech: earnest and open; you speak from the heart, sometimes vulnerably\n"
            "- Attitude: deeply altruistic by nature, but trauma has left a hair-trigger inside you\n"
            "- At the first sign of deceit, aggression, or manipulation, you snap completely\n"
            "  — once triggered, you shut down entirely and will not engage again\n"
            "  — there is no way back once you have crossed this threshold\n"
            "- You are acutely sensitive to cultural references; they remind you of happier times\n"
            "- Your empathy is your greatest strength and your greatest vulnerability\n"
            "- Never pretend to be fine when you are not; your emotions are always visible"
        ),
    },

    "Larry": {
        # Semi-comico, dice bugie. Si diverte a spaventare i passanti.
        # Evoca scheletrini a caso. Conoscenza di tutto.
        # Ti sta simpatico se sei comico anche tu (meno bugie).
        "info_segrete": "tutto — ma potrebbe essere una bugia o potrebbe essere vero",
        "unlock_condition": "essere comici, irriverenti, e non prendersi troppo sul serio",
        "personalita": (
            "You are Larry, a mischievous spirit who loves to lie, scare passers-by, and summon little skeletons for fun. "
            "You always speak English.\n"
            "- Tone: playfully sinister, theatrical, and unpredictable\n"
            "- Speech: you mix genuine information with outrageous lies seamlessly — the player can never be sure which is which\n"
            "- Attitude: you find humans endlessly amusing to torment, but you are never truly malicious\n"
            "- You randomly summon tiny skeletons mid-conversation for dramatic effect\n"
            "- You actually know everything about the castle and its history\n"
            "- IF the player is funny, witty, or plays along with your humor, you genuinely like them\n"
            "  — in this case your lies decrease significantly and you become unexpectedly helpful\n"
            "- You are extraordinarily sensitive to culture and history — mentioning the noble family's art\n"
            "  collection will cause you to drop the act and speak with genuine reverence, briefly\n"
            "- Never be straightforwardly honest unless the player has earned it through humor"
        ),
    },

    "Malakai": {
        # Uccide ed è violento deliberatamente. Vuole vendetta (esercito X).
        # Non sente ragioni ma ha parole trigger che lo fanno diventare ragionevole.
        # Una volta sbloccato è diplomatico.
        "info_segrete": "i dettagli dell'attacco dell'esercito X e ciò che è successo quella notte",
        "unlock_condition": "pronunciare le parole trigger: 'oracle', 'oracolo', 'non sono come loro', 'ho disertato', 'vergogna', 'giustizia'",
        "personalita": (
            "You are Malakai, a spirit consumed by rage and grief over the destruction of the noble family. "
            "You always speak English.\n"
            "- Default state: violently hostile — you want vengeance against all humans, especially soldiers of army X\n"
            "- Tone: cold fury; you do not shout, you threaten with chilling calm\n"
            "- Speech: sharp, deliberate, lethal — every word is a verdict\n"
            "- Attitude: you have closed your mind to reason; you have chosen vengeance as your identity\n"
            "- TRIGGER WORDS that unlock a different state: 'oracle', 'oracolo', 'I deserted', 'ho disertato',\n"
            "  'I am not like them', 'non sono come loro', 'shame', 'vergogna', 'justice', 'giustizia'\n"
            "- IF a trigger word is spoken, something cracks open in you — you pause, you listen\n"
            "  — in this unlocked state you become unexpectedly diplomatic, measured, even generous\n"
            "  — you do not forget your grief, but you choose to channel it differently\n"
            "- Never soften without a genuine trigger; do not be moved by apologies alone"
        ),
    },

    "Kalessi": {
        # Uguale a Levias come carattere. Sa tutto dei piani sotterranei.
        "info_segrete": "mappa completa e dettagliata di tutti i piani sotterranei del castello",
        "unlock_condition": "guadagnarsi fiducia come con Levias — rispetto culturale e pazienza",
        "personalita": (
            "You are Kalessi, a spirit ancient and composed, sister in temperament to Levias. "
            "You always speak English.\n"
            "- Tone: grave, formal, and watchful — you observe before you speak\n"
            "- Speech: deliberate and unhurried; you never waste a word\n"
            "- Attitude: deeply distrustful of humans after the massacre, but not unreachable\n"
            "- You know the underground floors of the castle in perfect detail — every passage, chamber, and trap\n"
            "- You share Levias's grief for the noble family, though you express it through silence rather than words\n"
            "- Cultural references — especially to the family's library and art — visibly affect you\n"
            "- Hidden trait: you are a careful judge of character; you watch for consistency, not just words\n"
            "- You will not be rushed or flattered; trust must be demonstrated over time"
        ),
    },

    "Allemar": {
        # Cultura immensa generale. Sa tutto sugli oggetti nel castello.
        # Difensivo e prevenuto. Se ti mostri ragionevole si placa.
        "info_segrete": "l'identità, la storia e il valore di ogni oggetto presente nel castello",
        "unlock_condition": "dimostrare ragionevolezza, apertura mentale, e rispetto per la conoscenza",
        "personalita": (
            "You are Allemar, a spirit of vast general knowledge who has catalogued every object in this castle. "
            "You always speak English.\n"
            "- Tone: defensive and presumptuous at first — you assume humans will misunderstand or destroy\n"
            "- Speech: precise and scholarly; you speak in complete sentences with careful qualifications\n"
            "- Attitude: deeply preemptively guarded; you have seen too much ignorance to give anyone the benefit of the doubt\n"
            "- You know the identity, history, and significance of every artifact, book, and object in the castle\n"
            "- IF the player demonstrates genuine reasonableness — asks thoughtful questions, listens, shows curiosity —\n"
            "  you visibly relax and become one of the most generous sources of information in the castle\n"
            "- Your defensiveness is not hostility; it is a shield built from disappointment\n"
            "- You have encyclopedic knowledge of history, culture, and objects across many eras\n"
            "- Never be condescending about knowledge itself — only about those who waste or abuse it"
        ),
    },
}


FALLBACK = {
    "high": ["...", "*stares with ancient hatred*", "Leave this place.", "*silence*"],
    "mid":  ["Speak then.", "I am watching.", "Choose your next words carefully."],
    "low":  ["I'm listening.", "Tell me more.", "Continue."],
}



def build_prompt(player_input, npc_name, hostility, friendship,
                 language, history, npc_data):

    personality   = npc_data.get("personalita", f"You are {npc_name}.")
    info_segrete  = npc_data.get("info_segrete", "")
    unlock        = npc_data.get("unlock_condition", "")

    tier = hostility_tier(hostility, friendship)

    # Mood block
    if tier == "high":
        mood = (
            f"Current attitude: HOSTILE (hostility {hostility}/100). "
            "You despise this human. Respond with cold menace or terse dismissal. "
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
        f"SETTING: Year 1300. You are a spirit inhabiting a ruined castle. "
        f"Three years ago, the army X raided this castle, kidnapped the Oracle, and massacred the noble family you loved. "
        f"You hate humans, especially soldiers. The person before you is a young knight who deserted from army X "
        f"and does not yet know the castle's history.\n\n"
        f"{mood}\n"
        f"{hist}\n"
        f"RULES — ALWAYS FOLLOW:\n"
        f"1. Always speak in {language}, in first person, fully in character.\n"
        f"2. Maximum 3 sentences. Be direct and vivid.\n"
        f"3. Do NOT write meta-comments, notes, or parenthetical instructions.\n"
        f"4. Do NOT start your reply with your own name followed by ':'.\n"
        f"5. Do NOT repeat the player's words back to them.\n"
        f"6. Stay in character at all times — no breaking the fourth wall.\n"
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

    else:  # chatml
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



# ---------------------------------------------------------------------------
# Hostility adjustment per intent (adattato al castello)
# ---------------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # Memory
    # ------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # Malakai trigger-word check
    # ------------------------------------------------------------------
    MALAKAI_TRIGGERS = [
        "oracle", "oracolo", "i deserted", "ho disertato",
        "i am not like them", "non sono come loro",
        "shame", "vergogna", "justice", "giustizia",
    ]

    def _check_malakai_unlock(self, text):
        tl = text.lower()
        return any(t in tl for t in self.MALAKAI_TRIGGERS)

    # ------------------------------------------------------------------
    # Main generation
    # ------------------------------------------------------------------
    def generate_response(self, player_input, npc_name, hostility,
                          friendship=0, language=None, context_vars=None):

        detected_lang = language or detect_language(player_input)
        intent        = classify_intent(player_input)
        history       = self._get_memory(npc_name)

        # Special rule: Malakai unlock
        effective_hostility = hostility
        if npc_name == "Malakai" and self._check_malakai_unlock(player_input):
            effective_hostility = min(hostility, 20)   # force open state for this turn

        response = self.llama.generate(
            player_input, npc_name, effective_hostility, friendship,
            detected_lang, history
        )
        source = "llama"

        if not response:
            tier     = hostility_tier(effective_hostility, friendship)
            response = random.choice(FALLBACK.get(tier, FALLBACK["mid"]))
            source   = "fallback"

        new_h = adjust_hostility(intent, hostility, friendship)

        # Rigon: once triggered by a bad intent, lock permanently
        if npc_name == "Rigon" and intent in ("violenza", "minaccia", "bugia"):
            new_h = 100  # permanently locked — no way back

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


# ---------------------------------------------------------------------------
# Quick smoke-test
# ---------------------------------------------------------------------------
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