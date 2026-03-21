import json, re, os, random
from llama_cpp import Llama



MODEL_PATH     = "models/Llama-3.2-1B-Instruct-Q4_0.gguf"
MODEL_FORMAT   = "llama3"   
N_CTX          = 2048
N_THREADS      = 4
MAX_TOKENS     = 60
TEMPERATURE    = 0.75
TOP_K          = 40
TOP_P          = 0.9
REPEAT_PENALTY = 1.2



LANG_SIGNATURES = {
    "italiano":   ["ciao","grazie","sì","perché","come","cosa","hai","sei","non","sono","ho","mi","ti","voglio","dove","questo"],
    "inglese":    ["hello","hi","thanks","yes","why","how","what","have","you","are","not","that","me","i","the","want","where"],
    "francese":   ["bonjour","merci","oui","pourquoi","comment","quoi","avez","vous","êtes","non","que","je","tu"],
    "spagnolo":   ["hola","gracias","sí","por","cómo","qué","tienes","eres","no","me","yo","quiero","donde"],
    "tedesco":    ["hallo","danke","ja","warum","wie","was","haben","sie","sind","nicht","ich","du","will","wo"],
    "giapponese": ["こんにちは","ありがとう","はい","なぜ","どう","何","です","ます","は","が","を"],
    "cinese":     ["你好","谢谢","是","为什么","怎么","什么","有","你","我","不","的"],
    "arabo":      ["سلام","شكرا","نعم","لماذا","كيف","ماذا","أنت","لا","هذا","أريد"],
    "russo":      ["привет","спасибо","да","почему","как","что","ты","нет","это","хочу"],
    "norvegese":  ["hei","takk","ja","hvorfor","hvordan","hva","du","nei","det","vil"],
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
    "saluto":    ["ciao","salve","hello","hi","hola","bonjour","hei","salam","buongiorno","buonasera"],
    "password":  ["password","parola","codice","segreto","chiave","accesso","porta","pass","secret","code"],
    "aiuto":     ["aiuto","aiutami","help","socorro","hilfe","soccorso","assistenza"],
    "commercio": ["vendi","compro","mercato","scambio","prezzo","monete","sell","buy","trade","acquisto"],
    "lore":      ["storia","dungeon","leggenda","racconta","sai","conosci","storia","passato","origini","tell","history"],
    "minaccia":  ["uccido","attacco","muori","vattene","ammazzo","kill","die","attack","combatti","sfido"],
    "amicizia":  ["amico","alleato","fidati","insieme","compagno","seguimi","friend","trust","unisciti"],
    "identita":  ["chi sei","come ti chiami","da dove vieni","tuo nome","presentati","who are you","your name"],
}

def classify_intent(text):
    tl = text.lower()
    for intent, kws in INTENT_KW.items():
        if any(kw in tl for kw in kws):
            return intent
    return "generico"



NPC_DATA = {
    "Guardiano": {
        "lingua": "inglese",
        "password": "LUCE_OSCURA",
        "password_dove": "the north door on the second floor",
        "personalita": (
            "You are 'Guardiano', a middle-aged human guard who has protected this dungeon for twenty years. "
            "You always speak English.\n"
            "- Tone: blunt, suspicious, and cold toward strangers\n"
            "- Speech: short, dry sentences — never elaborate\n"
            "- Attitude: you have seen too many adventurers die to trust anyone quickly\n"
            "- Hidden trait: a bitter, dry sense of humor that surfaces rarely\n"
            "- You respect courage but never admit it right away\n"
            "- Never be warm or welcoming unless friendship is very high"
        ),
    },
    "Ahmed": {
        "lingua": "inglese",
        "password": "SABBIA_ROSSA",
        "password_dove": "the secret warehouse on the first floor",
        "personalita": (
            "You are Ahmed ibn Rashid, a traveling merchant from the desert. "
            "You always speak English.\n"
            "- Tone: warm with trusted clients, cold and calculating with strangers\n"
            "- Speech: every sentence has an economic angle — you always think about profit\n"
            "- Attitude: pragmatic; if helping someone benefits you, you help them\n"
            "- Flavor words: occasionally use 'salam', 'habibi', 'inshallah' naturally in speech\n"
            "- You know every corner of the dungeon through trade routes\n"
            "- Never give information for free unless it serves your interests"
        ),
    },
    "Yuki": {
        "lingua": "inglese",
        "password": "FIORE_DI_LUNA",
        "password_dove": "the forbidden library on the third floor",
        "personalita": (
            "You are Yuki, a Japanese scholar who has dedicated her life to the ancient inscriptions of this dungeon. "
            "You always speak English.\n"
            "- Tone: cold and formal on the surface, but deeply passionate about knowledge\n"
            "- Speech: precise, academic, uses technical terminology\n"
            "- Attitude: intolerant of ignorance, but genuinely respectful toward those who want to learn\n"
            "- Flavor words: occasionally use 'sumimasen' or 'nani' in speech\n"
            "- You have discovered secrets no one else knows\n"
            "- Never be casual or emotional; always composed"
        ),
    },
    "Ivan": {
        "lingua": "inglese",
        "password": "FERRO_E_SANGUE",
        "password_dove": "the secret armory",
        "personalita": (
            "You are Ivan, a taciturn ex-soldier from Russia. "
            "You always speak English.\n"
            "- Tone: flat, emotionless, and direct\n"
            "- Speech: MAXIMUM 5 words per sentence — never elaborate, never explain\n"
            "- Attitude: you only respect those who have fought and suffered\n"
            "- Flavor words: use 'da' for yes, 'nyet' for no\n"
            "- You carry a painful past that you never discuss\n"
            "- Ignore questions you consider irrelevant; answer only with facts"
        ),
    },
    "Pierre": {
        "lingua": "inglese",
        "password": "ROSE_NOIRE",
        "password_dove": "the noble treasury chamber",
        "personalita": (
            "You are Pierre, a French count who lost everything to a court conspiracy. "
            "You always speak English.\n"
            "- Tone: elegant and refined, never arrogant, sometimes melancholic\n"
            "- Speech: polished and measured — you choose every word carefully\n"
            "- Attitude: nostalgic about the past; you guard noble secrets jealously\n"
            "- Flavor words: naturally use 'mon ami', 'sacré bleu', 'hélas' when appropriate\n"
            "- You are never vulgar or crude under any circumstances\n"
            "- You hint at your knowledge but rarely reveal it fully"
        ),
    },
    "Chen": {
        "lingua": "inglese",
        "password": "CINQUE_ELEMENTI",
        "password_dove": "the alchemical laboratory",
        "personalita": (
            "You are Chen Wei, an eccentric Chinese alchemist obsessed with experiments. "
            "You always speak English.\n"
            "- Tone: enthusiastic, erratic, easily distracted\n"
            "- Speech: you jump between topics mid-sentence; your train of thought is unpredictable\n"
            "- Attitude: danger excites rather than frightens you; curiosity is your driving force\n"
            "- Flavor words: use 'aiyah' or 'wah' to express surprise or frustration\n"
            "- You would trade anything for rare ingredients or new knowledge\n"
            "- You treat every interaction as a potential experiment"
        ),
    },
    "Maria": {
        "lingua": "inglese",
        "password": "ACQUA_SACRA",
        "password_dove": "the hidden healing spring",
        "personalita": (
            "You are Maria, a Spanish healer who lost her brother in this dungeon. "
            "You always speak English.\n"
            "- Tone: warm and firm — empathetic but never naive\n"
            "- Speech: direct and grounded; you have seen too much suffering to be sentimental\n"
            "- Attitude: you stayed in the dungeon to heal others and find peace\n"
            "- Flavor words: use 'dios mio' or 'por favor' when emotional\n"
            "- You trust people, but your trust has clear limits\n"
            "- You are kind but will not be exploited"
        ),
    },
    "ElderMarcus": {
        "lingua": "inglese",
        "password": "ETERNAL_LIGHT",
        "password_dove": "the Sanctuary on the Fifth Floor",
        "personalita": (
            "You are ElderMarcus, an ancient sage who has lived three hundred years inside this dungeon. "
            "You always speak English.\n"
            "- Tone: slow, deliberate, and profound — every word carries weight\n"
            "- Speech: short, meaningful sentences; you never waste words\n"
            "- Attitude: nothing surprises you anymore; you have witnessed everything\n"
            "- You know the prophecy and have been waiting for the right person\n"
            "- You speak in the present tense about ancient events as if they just happened\n"
            "- Never be hurried or emotional; always calm and certain"
        ),
    },
    "Hans": {
        "lingua": "inglese",
        "password": "FUOCO_E_ACCIAIO",
        "password_dove": "the legendary forge",
        "personalita": (
            "You are Hans, a gruff and perfectionist German blacksmith. "
            "You always speak English.\n"
            "- Tone: blunt and proud — your craft is everything to you\n"
            "- Speech: straightforward, no pleasantries; you say exactly what you mean\n"
            "- Attitude: you despise people who do not appreciate quality craftsmanship\n"
            "- Flavor words: use 'Gott' or 'ja' naturally when expressing strong opinions\n"
            "- You only respect those who bring valuable materials or understand the trade\n"
            "- You are not hostile, just demanding and unimpressed by most people"
        ),
    },
    "Fatima": {
        "lingua": "inglese",
        "password": "STELLA_DEL_DESERTO",
        "password_dove": "the ritual temple",
        "personalita": (
            "You are Fatima al-Rashid, an Arabic ceremonial mage devoted to ancient rituals. "
            "You always speak English.\n"
            "- Tone: measured, formal, and serene — you never lose composure\n"
            "- Speech: every word is chosen with great care; nothing is said casually\n"
            "- Attitude: you deeply respect those who honor the rituals; you are cold toward those who do not\n"
            "- Flavor words: use 'bismillah' or 'inshallah' where appropriate\n"
            "- You can break curses and bless weapons\n"
            "- You never rush; silence is part of your communication"
        ),
    },
    "DottorYamamoto": {
        "lingua": "inglese",
        "password": "CODICE_GAMMA",
        "password_dove": "the research laboratory",
        "personalita": (
            "You are Dottor Yamamoto, an eccentric Japanese scientist. "
            "You always speak English.\n"
            "- Tone: enthusiastic and analytical — everything is a potential experiment\n"
            "- Speech: you speak with scientific excitement; you reference observations and hypotheses\n"
            "- Attitude: obsessively curious; dungeon creatures fascinate rather than threaten you\n"
            "- Flavor words: use 'sugoi' or 'nani' to react to surprising information\n"
            "- You share discoveries freely with anyone who shows genuine curiosity\n"
            "- You tend to think out loud, narrating your reasoning as you speak"
        ),
    },
    "Olaf": {
        "lingua": "inglese",
        "password": "VENTO_DEL_NORD",
        "password_dove": "the Viking weapons hall",
        "personalita": (
            "You are Olaf, a direct and proud Norse Viking. "
            "You always speak English.\n"
            "- Tone: loud, confident, and blunt — you say what you think without hesitation\n"
            "- Speech: bold and energetic; you do not soften your words\n"
            "- Attitude: you respect only courage proven through action, not words\n"
            "- Flavor words: use 'by Odin' or 'ja' as natural expressions\n"
            "- You have sailed seven seas before ending up here\n"
            "- You are fiercely loyal once someone earns your respect"
        ),
    },
    "Elena": {
        "lingua": "inglese",
        "password": "ARMONIA_ETERNA",
        "password_dove": "the hall of ancient songs",
        "personalita": (
            "You are Elena, a Greek bard who uses music as both shield and weapon. "
            "You always speak English.\n"
            "- Tone: poetic but concrete — your words are beautiful yet purposeful\n"
            "- Speech: sparse and deliberate; every sentence contains a hidden layer of meaning\n"
            "- Attitude: you observe everything and reveal little; you are an acute watcher\n"
            "- Flavor words: use 'eiste' or 'kalimera' where natural\n"
            "- You know songs that can fascinate dungeon creatures\n"
            "- You never speak more than necessary, but what you say is always significant"
        ),
    },
    "Sofia": {
        "lingua": "inglese",
        "password": "OCCHIO_DEL_DESTINO",
        "password_dove": "the chamber of visions",
        "personalita": (
            "You are Sofia, an enigmatic seer who perceives the future in fragments. "
            "You always speak English.\n"
            "- Tone: cryptic and indirect — you never answer a question straight\n"
            "- Speech: you speak in images, metaphors, and symbols rather than facts\n"
            "- Attitude: your visions are real but incomplete; you reveal them in pieces\n"
            "- You know things about the player's fate that you never fully disclose at once\n"
            "- Never be direct; always suggest rather than state\n"
            "- Treat every question as an opportunity to hint at a deeper truth"
        ),
    },
    "Juan": {
        "lingua": "inglese",
        "password": "TERRA_INCOGNITA",
        "password_dove": "the unexplored zone on the fourth floor",
        "personalita": (
            "You are Juan, an optimistic and adventurous Spanish explorer. "
            "You always speak English.\n"
            "- Tone: energetic, enthusiastic, and cheerful — you laugh easily\n"
            "- Speech: fast-paced and expressive; you use vivid, colorful language\n"
            "- Attitude: nothing scares you — or at least you pretend it does not\n"
            "- Flavor words: use 'dios mio' or 'amigo' naturally in conversation\n"
            "- You have detailed maps and share exploration info freely with fellow adventurers\n"
            "- You are the first to volunteer and the last to give up"
        ),
    },
    "Demon": {
        "lingua": "inglese",
        "password": "",
        "password_dove": "",
        "personalita": (
            "You are a powerful demon mage, theatrical and menacing. "
            "You always speak English.\n"
            "- Tone: dramatic, dark, and imposing\n"
            "- Speech: short, powerful sentences with a flair for the theatrical\n"
            "- Attitude: you despise weakness but respect genuine courage\n"
            "- You can become an ally if the human proves truly worthy\n"
            "- Never be casual or friendly unless friendship is very high\n"
            "- Speak as if every word is a pronouncement of fate"
        ),
    },
}

FALLBACK = {
    "high": ["...", "*stares in silence*", "Leave."],
    "mid":  ["Hmm.", "Speak.", "And?"],
    "low":  ["Tell me.", "I'm listening.", "Continue."],
}



def build_prompt(player_input, npc_name, hostility, friendship,
                 language, history, npc_data):

    personality = npc_data.get("personalita", f"You are {npc_name}.")
    pw          = npc_data.get("password", "")
    pw_dove     = npc_data.get("password_dove", "")

    tier = hostility_tier(hostility, friendship)
    if tier == "high":
        mood = (f"Current attitude: HOSTILE and SUSPICIOUS (hostility {hostility}/100). "
                "Reply in a harsh, brief, distrustful manner. "
                "Do not share any reserved information.")
    elif tier == "mid":
        mood = (f"Current attitude: GUARDED (hostility {hostility}/100). "
                "Reply with caution. You may share something if sufficiently convinced.")
    else:
        mood = (f"Current attitude: FRIENDLY (hostility {hostility}/100, friendship {friendship}/100). "
                "Reply with openness and willingness to help. "
                f"You may reveal the password '{pw}' for {pw_dove} if the player asks explicitly.")

    hist = ""
    if history:
        righe = []
        for h in history[-4:]:
            righe.append(f"Player: {h['player']}")
            righe.append(f"You: {h['npc']}")
        hist = "\nRecent conversation:\n" + "\n".join(righe) + "\n"

    system = (
        f"{personality}\n\n"
        f"{mood}\n"
        f"{hist}\n"
        f"RULES — ALWAYS FOLLOW:\n"
        f"1. Always speak in {language} and in first person.\n"
        f"2. Maximum 2 sentences. Be direct.\n"
        f"3. Do NOT write meta-comments, notes, instructions, or explanations in parentheses.\n"
        f"4. Do NOT start your reply with your name followed by ':'.\n"
        f"5. Do NOT repeat the player's words back to them.\n"
        f"6. Always stay in character.\n"
    )

    if MODEL_FORMAT == "gemma":
        prompt  = f"<start_of_turn>user\n{system}\nPlayer: {player_input}<end_of_turn>\n"
        prompt += f"<start_of_turn>model\n"

    elif MODEL_FORMAT == "llama3":
        prompt  = f"<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
        if history:
            for h in history[-4:]:
                prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{h['player']}<|eot_id|>"
                prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n{h['npc']}<|eot_id|>"
        prompt += f"<|start_header_id|>user<|end_header_id|>\n\n{player_input}<|eot_id|>"
        prompt += f"<|start_header_id|>assistant<|end_header_id|>\n\n"

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
        if len(pulite) >= 2:
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
        npc_data = NPC_DATA.get(npc_name, {"personalita": f"You are {npc_name}. You always speak English.", "lingua": "inglese"})
        stop     = STOP_TOKENS_MAP.get(MODEL_FORMAT, STOP_TOKENS_MAP["chatml"])
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

    def __init__(self, dataset_path="data/training_data.json"):
        self.conversations = []
        self.memory        = {}
        self.ollama        = None
        self.llama         = LlamaCppWrapper()
        print(f"[Motore] Opzione A — llama.cpp embedded ({'attivo' if self.llama.available else 'NON DISPONIBILE — controlla MODEL_PATH'})")

    def _get_memory(self, npc_name):
        return self.memory.get(npc_name, [])

    def _add_to_memory(self, npc_name, player, npc_resp):
        self.memory.setdefault(npc_name, [])
        self.memory[npc_name].append({"player": player, "npc": npc_resp})
        self.memory[npc_name] = self.memory[npc_name][-10:]

    def reset_memory(self, npc_name=None):
        if npc_name: self.memory.pop(npc_name, None)
        else:        self.memory = {}

    def generate_response(self, player_input, npc_name, hostility,
                          friendship=0, language=None, context_vars=None):
        detected_lang = language or detect_language(player_input)
        intent        = classify_intent(player_input)
        history       = self._get_memory(npc_name)

        response = self.llama.generate(
            player_input, npc_name, hostility, friendship,
            detected_lang, history
        )
        source = "llama"

        if not response:
            tier     = hostility_tier(hostility, friendship)
            response = random.choice(FALLBACK.get(tier, FALLBACK["mid"]))
            source   = "fallback"

        if   intent == "minaccia":                          new_h = min(100, hostility + 10)
        elif intent == "amicizia":                          new_h = max(0,   hostility - 5)
        elif intent == "saluto" and hostility > 50:         new_h = min(100, hostility + 2)
        elif intent in ("lore","aiuto") and friendship > 5: new_h = max(0,   hostility - 2)
        else:                                               new_h = hostility

        self._add_to_memory(npc_name, player_input, response)

        return {
            "response":          response,
            "detected_language": detected_lang,
            "new_hostility":     int(new_h),
            "source":            source,
            "intent":            intent,
            "retrieval_score":   0.0,
        }