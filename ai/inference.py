
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
        # Piu' di un tentativo: il modello rispetta il formato RIDDLE:/ANSWER:
        # quasi sempre, ma ogni tanto scrive l'indovinello e si ferma prima
        # della riga ANSWER. parse_riddle_response() allora torna None (ed e'
        # giusto: senza risposta la porta non si aprirebbe) e il giocatore
        # riceve un indovinello di riserva pur avendo il modello acceso.
        for tentativo in range(RIDDLE_ATTEMPTS):
            result = self.llama.generate_riddle(door_id, language, theme, session_id)
            if result:
                print(f"[Riddle] door={door_id} session={session_id} "
                      f"answer={result['answer']} (tentativo {tentativo + 1})")
                return result
        fallback_list = RIDDLE_FALLBACKS.get(language, RIDDLE_FALLBACKS["inglese"])
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