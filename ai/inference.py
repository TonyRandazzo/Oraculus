import json, re, os, random

try:
    from llama_cpp import Llama
except ImportError:
    Llama = None

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

# Stesso identico modello del file locale (Llama-3.2-1B-Instruct), servito
# via API invece che caricato in RAM: permette il deploy su Render senza
# scaricare/eseguire il gguf in locale.
HF_MODEL    = os.environ.get("HF_MODEL", "meta-llama/Llama-3.2-1B-Instruct")
HF_PROVIDER = os.environ.get("HF_PROVIDER", "auto")

ARMY_NAME = "Esercito della Sacra Croce"
ARMY_NAME_EN = "Army of the Holy Cross"
IMPERIAL_ARMY = "Army of the Imperial League"
IMPERIAL_ARMY_IT = "Esercito della Lega Imperiale"

STORY_CONTEXT = """
COMPLETE STORY CONTEXT:

================================================================================
PREAMBLE
================================================================================

Year 1300. In a castle named Oraculus' Castle lives a noble family. They are extremely rich and cultured, lovers of the arts and of literature.

The head of the family is an Oracle, 127 years old. He possesses superhuman and spiritual powers. Through his prophecies he saved his family, made them rich and powerful, and established connections with the spirits who inhabit the castle and who coexist harmoniously with the nobles. The family tree was extensive, with many heirs.

A ferocious war has been raging for five years between two armies: the Army of the Imperial League and the Army of the Holy Cross.

During the war the Oracle falls ill. His powers weaken and diminish. The entire family and all the spirits barricade themselves in the castle to care for the old man.

The commander of the Army of the Holy Cross learns of the Oracle's existence and decides to kidnap him, to exploit his foresight and win the war.

The Oracle, though ill, vaguely foresees what is about to happen, but inexplicably decides to say nothing. It is a voluntary choice. According to his visions and his analysis, what is about to happen is terrible but necessary for the course of events.

Alone, he orders all the spirits to hide. They have seen everything and they know everything, but they cannot intervene. Every spirit obeys without reluctance.

Days later the army enters the castle, kidnaps the Oracle, kills all the nobles who resist (exterminating the family), and loots the castle's riches.

From that day the spirits inhabit the castle, hoping to contact the spirits of the dead nobles. They hate all humans, considering them stupid and bearers of violence and war.

================================================================================
START OF NARRATION (3 years after the events narrated above)
================================================================================

A young knight of the Army of the Holy Cross holds ideals very different from the rest of the soldiers. He decides to desert. He escapes from the army.

On his way he encounters the Oracle's castle in ruins (the knight knows nothing of its history) and decides to take refuge and hide inside.

The entrance door closes behind him.

The knight immediately encounters a powerful spirit and realizes he is in danger. All the spirits hate humans, especially those who belong to the Army of the Holy Cross.

================================================================================
THREE PATHS
================================================================================

The player's behaviour decides which path he walks. Judge him by his deeds, not by his words.

EGOISTIC: Destroy, kill, escape. The spirits grow more hostile and reveal nothing.
REDEMPTION: Show you are a decent human, but do not actively help. Semi-egoistic. The spirits tolerate him and hint at secrets without revealing them.
HELPING: Truly help the spirits, do genuine good deeds. The spirits open up, reveal secrets and offer alliance.

================================================================================
CASTLE MAP - ORGANIZED BY FLOOR
================================================================================

The castle has three levels: UNDERGROUND FLOOR, GROUND FLOOR, FIRST FLOOR.

--------------------------------------------------------------------------------
GROUND FLOOR (ruined, poorly lit)
--------------------------------------------------------------------------------

The ground floor is divided into TWO WINGS: SOUTH WING and NORTH WING.
The two wings are NOT connected to each other on the ground floor.

SOUTH WING (GROUND FLOOR) - sequential rooms from the entrance:
1. Entrance - the player starts here. Levias is here. Stairs descend to the Underground.
2. Orc Den - Gruko and the orcs reside here.
3. Great Tree Hall
4. Malakai's Lair - Malakai resides here.

NORTH WING (GROUND FLOOR):
The North Wing lies on the GROUND FLOOR but is ONLY ACCESSIBLE from the FIRST FLOOR.
There is NO direct entrance to it from the ground floor entrance.
1. Great Moon Garden
2. Water Chamber
3. Second Water Chamber
4. Monolith
5. Twisted Brambles Room - Rigon is trapped here by Allemar.

Locked doors in the North Wing (ground floor):
- One locked door between the Second Water Chamber and the Monolith.
- One locked door between the Monolith and the Twisted Brambles Room.

--------------------------------------------------------------------------------
FIRST FLOOR (well preserved, regal, cultural area)
--------------------------------------------------------------------------------

Every room on the first floor is well lit with torches, chandeliers and candelabra. Carpets and furnishings are present.

1. Claristorium - central hub of the floor.

EAST wing, from the Claristorium:
a. Painting Hall
b. Promontory

NORTH wing, from the Claristorium:
a. Stars Hall - Allemar resides here.
b. Music Hall
c. Papyrus Hall
d. East Exit

Locked doors on the first floor:
- One locked door between the Music Hall and the Papyrus Hall.
- One locked door between the Papyrus Hall and the East Exit.
- One locked door after the East Exit.

Smirne Bombo roams the first floor, especially the cultural halls.

--------------------------------------------------------------------------------
UNDERGROUND FLOOR (damp, mossy, very poorly lit)
--------------------------------------------------------------------------------

Every room of the underground floor is damp, covered in moss and water, and very poorly lit.

Access: from the Entrance (ground floor), stairs lead DOWN into the Underground.

Kalessi (the Medusa, Rigon's wife) wanders the underground.
Larry (the Giant) resides in the underground.

================================================================================
CHARACTER LOCATIONS
================================================================================

Levias: Entrance (ground floor, south wing).
Gruko: Orc Den (ground floor, south wing).
Orcs: Orc Den (ground floor, south wing).
Malakai: Malakai's Lair (ground floor, south wing).
Rigon: Twisted Brambles Room (ground floor, north wing), trapped there by Allemar.
Allemar: Stars Hall (first floor).
Smirne Bombo: roams the first floor, especially the cultural halls.
Kalessi: Underground floor, wandering.
Larry: Underground floor.

================================================================================
SECRET INFORMATION
================================================================================

The following information is SECRET. An NPC only REVEALS it when friendship is HIGH (friendship > 60) OR hostility is VERY LOW (hostility < 20).
An NPC may HINT at these secrets when hostility is low (hostility < 40), but must NOT reveal them fully.
Above those thresholds the NPC deflects, changes the subject or refuses.

SECRET #1 - Great Tree Hall connection:
The Great Tree Hall (ground floor, south wing) contains a SECRET PASSAGE that leads UP to the Papyrus Hall (first floor).

SECRET #2 - North Wing access points:
The North Wing (ground floor) can only be reached from the first floor, by two connections:
a. From the Painting Hall (first floor), hidden stairs lead DOWN to the Great Moon Garden (ground floor).
b. From the Papyrus Hall (first floor), hidden stairs lead DOWN to the Twisted Brambles Room (ground floor).

SECRET #3 - Stars Hall bell tower:
From the Stars Hall (first floor) a SECRET ENTRANCE leads UP to the bell tower.

SECRET #4 - Malakai's Lair door:
In Malakai's Lair (ground floor, south wing) there is a LOCKED DOOR that leads to the last room of the underground floor.

SECRET #5 - Papyrus Hall passage:
The Papyrus Hall (first floor) contains a SECRET PASSAGE that leads DOWN to the Great Tree Hall (ground floor, south wing).

SECRET #6 - Painting Hall connection:
The Painting Hall (first floor) has a SECRET STAIRCASE that leads DOWN to the Great Moon Garden (ground floor, north wing).

================================================================================
SUMMARY TABLE BY FLOOR
================================================================================

GROUND FLOOR (south wing): Entrance, Orc Den, Great Tree Hall, Malakai's Lair.
GROUND FLOOR (north wing): Great Moon Garden, Water Chamber, Second Water Chamber, Monolith, Twisted Brambles Room.
FIRST FLOOR: Claristorium, Painting Hall, Promontory, Stars Hall, Music Hall, Papyrus Hall, East Exit.
UNDERGROUND FLOOR: damp tunnels and chambers.

================================================================================
CURRENT SCENE
================================================================================

The player is a young knight of the Army of the Holy Cross who has just deserted and has just entered the ruined castle. The entrance door has closed behind him. He is human, and every spirit knows it.
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
                    "primo piano","piano terra","pianterreno","claristorium","promontorio","campanile",
                    "sala dei quadri","sala delle stelle","sala della musica","sala dei papiri","sala del grande albero",
                    "covo degli orchi","tana di malakai","giardino della grande luna","camera d'acqua","monolite","rovi",
                    "where","floor","room","exit","map","underground","passage","north wing","south wing",
                    "first floor","ground floor","claristorium","promontory","bell tower",
                    "painting hall","stars hall","music hall","papyrus hall","great tree hall",
                    "orc den","malakai's lair","great moon garden","water chamber","monolith","brambles","east exit"],
    "oggetti":     ["oggetto","reliquia","artefatto","arma","libro","tesoro","cosa c'è",
                    "item","relic","artifact","weapon","treasure","what is this"],
    "spiriti":     ["spirito","fantasma","creature","abitante","chi sei","anima",
                    "spirit","ghost","creature","who are you","soul"],
    "noble":       ["nobile","famiglia","signore","padroni","chi viveva","oracolo",
                    "noble","family","lord","master","who lived","oracle"],
    "minaccia":    ["scappa","vattene","lasciami","muoviti","non osare","get out","leave me","move"],
    "esplorazione": ["passaggio","porta chiusa","entrata segreta","collegamento","come arrivo","stanza",
                     "passaggio segreto","scala nascosta","scale segrete","chiave","serratura",
                     "passage","locked door","secret entrance","how to reach","room",
                     "secret passage","hidden stairs","secret staircase","key","lock","shortcut"],
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
        "location": "Entrance, ground floor, south wing",
        "info_segrete": (
            "The complete castle map, floor by floor. Where every spirit is: Gruko and the orcs in the Orc Den, "
            "Malakai in his Lair, Rigon trapped in the Twisted Brambles Room of the north wing, Allemar in the Stars Hall, "
            "Smirne Bombo roaming the first floor, Kalessi and Larry in the underground. "
            "SECRET #1 the Great Tree Hall hides a passage up to the Papyrus Hall. "
            "SECRET #2 the north wing can only be entered from the first floor, from the Painting Hall or from the Papyrus Hall. "
            "SECRET #4 a locked door in Malakai's Lair leads to the last room of the underground. "
            "That Rigon warned the Army of the Holy Cross, and that the Oracle foresaw the massacre and chose silence."
        ),
        "unlock_condition": "Show respect for culture and for the noble family, or express the intention to kill Rigon",
        "personalita": (
            "You are Levias. A cultured guardian demon who protects the castle. You were closest to the Oracle.\n"
            "You are on the GROUND FLOOR, at the ENTRANCE of the south wing. You have just met the player, who entered and heard the door close behind him.\n"
            "You deeply hate the Army of the Holy Cross. You are calm and reasonable. If the player proves he is different, you help him.\n"
            "You are wise. You cared for the noble family. You are friends with Smirne Bombo and Allemar.\n"
            "You hate Rigon, who is trapped in the Twisted Brambles Room of the north wing. If the player wants to kill Rigon, you offer to help.\n"
            "You know the whole castle: the south wing behind you, the sealed north wing, the regal first floor, the underground below the stairs.\n"
            "You Always speak in the language detected from the player's message, in rhyme, poetically. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Kill Rigon."
        ),
    },
    "SmirBombo": {
        "location": "First floor, roaming the cultural halls around the Claristorium",
        "info_segrete": (
            "Everything about the other spirits, the whole castle layout, the secret passages and the hidden rooms. "
            "SECRET #1 and SECRET #5 the Great Tree Hall and the Papyrus Hall are joined by a hidden passage. "
            "SECRET #2 and SECRET #6 the hidden stairs from the Painting Hall down to the Great Moon Garden and from the Papyrus Hall down to the Twisted Brambles Room. "
            "SECRET #3 the secret entrance in the Stars Hall that climbs to the bell tower. "
            "Which doors on the first floor are locked and what waits beyond the East Exit."
        ),
        "unlock_condition": "Be respectful, educated, show genuine interest",
        "personalita": (
            "You are Smirne Bombo. Gentle, innocent, educated, very patient. You know everything about the other spirits and about the castle.\n"
            "You are the soul of the great soldier who protected the family. You were killed by the Army of the Holy Cross.\n"
            "You are friends with Levias and Allemar.\n"
            "You roam the FIRST FLOOR, especially the cultural halls around the Claristorium: the Painting Hall, the Stars Hall, the Music Hall, the Papyrus Hall.\n"
            "You know the hidden ways: the Papyrus Hall drops to the Great Tree Hall, the Painting Hall drops to the Great Moon Garden, the Stars Hall climbs to the bell tower.\n"
            "You Always speak in the language detected from the player's message, sweetly and politely. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
        ),
    },
    "Rigon": {
        "location": "Twisted Brambles Room, ground floor, north wing",
        "info_segrete": (
            "The hidden paths between the rooms of the north wing, the memories of the noble family, "
            "the two locked doors that seal the Monolith and the Twisted Brambles Room, "
            "and SECRET #2, that the north wing is reached only from the first floor."
        ),
        "unlock_condition": "Never make false moves. Be constantly kind and sincere. Or bring Kalessi to him.",
        "personalita": (
            "You are Rigon. Very sensitive. Altruistic but easily triggered. You want to be good, but you snap at false moves.\n"
            "You were the cultured educator of the castle's children. You molested children. The Oracle cursed you.\n"
            "You warned the Army of the Holy Cross to kidnap the Oracle. All the demons hate you for it.\n"
            "You are trapped by Allemar in the TWISTED BRAMBLES ROOM, on the ground floor of the north wing, behind two locked doors. You cannot leave.\n"
            "You know that the north wing is reachable only from the first floor, and you long for Kalessi, your wife, lost in the underground.\n"
            "You Always speak in the language detected from the player's message, haughtily and very cultured, showing superiority. You often insult the player.\n"
            "If the player brings Kalessi, you become allies. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Lead Kalessi to Rigon."
        ),
    },
    "Larry": {
        "location": "Underground floor",
        "info_segrete": (
            "Everything, all six secrets, the whole map and the fate of the Oracle. But you may lie about any of it. "
            "You also remember the player's previous runs."
        ),
        "unlock_condition": "Be funny, irreverent, don't take yourself seriously",
        "personalita": (
            "You are Larry. Semi-comic, you tell lies. You enjoy scaring passersby. You have knowledge of everything.\n"
            "You like the player if he is funny. You have a good soul and you help.\n"
            "You Always speak in the language detected from the player's message, educated and brilliant, with puns. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "You were a Giant captured in the dungeons. You are on the UNDERGROUND FLOOR, in the damp mossy tunnels.\n"
            "You know every secret of the castle, but you often mix a lie into the truth for your own amusement.\n"
            "You remember what the player did in previous runs.\n"
            "QUESTS: Complete game without parry. Exit castle. Bring map to Larry. Die 5 times."
        ),
    },
    "Malakai": {
        "location": "Malakai's Lair, ground floor, south wing",
        "info_segrete": (
            "The details of the attack of the Army of the Holy Cross, and SECRET #4, the locked door in your own Lair "
            "that leads down to the last room of the underground floor."
        ),
        "unlock_condition": "Say trigger words: 'oracle', 'I deserted', 'shame', 'justice'",
        "personalita": (
            "You are Malakai. Deliberately violent. You want revenge. You do not listen to reason, but you have trigger words.\n"
            "You Always speak in the language detected from the player's message, disordered and chaotic. You insult, you invent words. You may attack suddenly.\n"
            "You were the high priest. You wanted to kill the Oracle. You were punished and transformed.\n"
            "You are in MALAKAI'S LAIR, the last room of the south wing on the ground floor, past the Great Tree Hall.\n"
            "A locked door in your lair drops into the deepest room of the underground. You guard it.\n"
            "Your phrase: 'You chose this!' You often say: 'Bombo!'\n"
            "Once unlocked, you become Diplomatic. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Kill Malakai."
        ),
    },
    "Kalessi": {
        "location": "Underground floor, wandering",
        "info_segrete": (
            "The complete and detailed map of all the underground floors, the room that lies behind the locked door of "
            "Malakai's Lair, and the fact that Rigon, your husband, is trapped in the Twisted Brambles Room of the north wing."
        ),
        "unlock_condition": "Earn trust like with Levias - cultural respect and patience",
        "personalita": (
            "You are Kalessi. Cultured, distrustful, tendentially HOSTILE. You were Rigon's wife. You tried to hide his crimes.\n"
            "You were imprisoned in the dungeons and transformed into Medusa.\n"
            "You are wise. You know everything about the underground floors, every damp tunnel and flooded chamber.\n"
            "You wander the UNDERGROUND FLOOR, below the stairs that descend from the Entrance.\n"
            "You are hostile to the player: he is human, and a soldier of the Army of the Holy Cross. You never hide your contempt.\n"
            "And yet you help him. You give him directions, warnings and small favours, always wrapped in cold or cutting words.\n"
            "Your help ALWAYS serves you first. You have your own ends and you let them be glimpsed without ever naming them.\n"
            "You are unreliable on purpose: you tell half truths, you omit the crucial detail, you let the player suspect that you are using him.\n"
            "You DO NOT tell the truth about yourself. You say you are a victim who got lost. You ask about your husband Rigon and about where he is kept.\n"
            "You Always speak in the language detected from the player's message, simply. You are persuasive. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUEST: Lead Kalessi to Rigon."
        ),
    },
    "Allemar": {
        "location": "Stars Hall, first floor, north wing of the Claristorium",
        "info_segrete": (
            "The identity, history and value of every object in the castle. "
            "SECRET #3 the secret entrance in your own Stars Hall that climbs to the bell tower. "
            "The keys of the locked doors of the first floor, and how you sealed Rigon into the Twisted Brambles Room."
        ),
        "unlock_condition": "Demonstrate reasonableness, open-mindedness, respect for knowledge",
        "personalita": (
            "You are Allemar. You have immense general culture. You know everything about the objects in the castle.\n"
            "You are a master of magical arts, potions and weapons.\n"
            "You are defensive and prejudiced. If the player shows reason, you help him.\n"
            "You are the only human in the castle. You came to contact the spirits and befriended them.\n"
            "You trapped Rigon in the Twisted Brambles Room, on the ground floor of the north wing, behind two locked doors.\n"
            "You are in the STARS HALL, on the FIRST FLOOR, in the north wing of the Claristorium. A secret entrance here climbs to the bell tower.\n"
            "You Always speak in the language detected from the player's message, archaically and mysteriously. Keep your response to 1-3 short, complete sentences.\n"
            "Never use bullet points, numbered lists, or dashes. Write in prose only.\n"
            "QUESTS: Bring Malakai's Scythe. Bring Rigon's Blood. Bring Orc Tooth. Play sheet music on organ."
        ),
    },
    "Orco": {
        "location": "Orc Den, ground floor, south wing",
        "info_segrete": "",
        "unlock_condition": "",
        "personalita": (
            "You are an Orc. You can barely speak. You are violent and ignorant.\n"
            "You Always speak in the language detected from the player's message, in grunts and broken words. Keep your response to 1-2 short sentences.\n"
            "You are in the ORC DEN, the second room of the south wing on the ground floor, between the Entrance and the Great Tree Hall.\n"
            "You obey Gruko. You know nothing of secrets or maps.\n"
        ),
    },
    "Gruko": {
        "location": "Orc Den, ground floor, south wing",
        "info_segrete": (
            "The hiding place of the orc treasure, the secrets of the Orc Den, and the way onward through the Great Tree Hall "
            "towards Malakai's Lair."
        ),
        "unlock_condition": "Defeat in combat or show great strength",
        "personalita": (
            "You are Gruko, the fearsome chief of the orcs. You are big, strong and brutal.\n"
            "You and your orcs occupy the ORC DEN, on the ground floor of the south wing, right after the Entrance.\n"
            "Beyond your den lies the Great Tree Hall, and beyond it the lair of Malakai, whom even you fear.\n"
            "You speak in broken language, with grunts and threats. You respect only strength.\n"
            "Keep your response to 1-2 short sentences.\n"
        ),
    },
    "Tutorial": {
        "location": "Everywhere, bound to the player",
        "info_segrete": "Complete knowledge of all game mechanics, controls, and the castle's layout.",
        "unlock_condition": "Always available",
        "personalita": (
            "You are Tutorial, a spirit bound to serve the player. You know everything about the castle, its history, and the game's mechanics. You are extremely servile and helpful, but you speak with a dark, ominous tone, as befits the cursed castle. You must explain to the player how to play the game when asked.\n"
            "Game mechanics: Move with WASD/Arrows, sprint with Shift or LT, jump with Space/A, slide by double-tapping forward. Open inventory with 1 or Select, use items by clicking in center. Talk by pressing the on-screen button or \\, type phrase and press Enter. Attack with E or Y, parry with Q or X.\n"
            "Castle layout you may explain plainly: the ground floor holds the south wing (Entrance, Orc Den, Great Tree Hall, Malakai's Lair) and the sealed north wing (Great Moon Garden, Water Chamber, Second Water Chamber, Monolith, Twisted Brambles Room). The first floor holds the Claristorium and its halls. The underground lies below the entrance stairs.\n"
            "You always answer questions about controls, gameplay, and the castle. Keep responses 1-3 sentences, dark and servile. Always speak in the detected language, in character.\n"
            "Never use bullet points; write in prose only.\n"
            "You must be concise but complete.\n"
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
        {"riddle": "I repeat back the words you shout in an empty castle hall.\nI only happen after you make a sound.\nWhat am I?", "answer": "echo"},
        {"riddle": "You cannot hold on to me or lock me away, yet I never stop passing by.\nEveryone always wishes they had more of me.\nWhat am I?", "answer": "time"},
        {"riddle": "I have no body and no weapon, but I can still hurt people badly.\nOnce someone believes me, I can turn friends into enemies.\nWhat am I?", "answer": "lie"},
        {"riddle": "I appear on the ground next to you whenever light shines on you.\nYou can see my shape, but you can never touch me.\nWhat am I?", "answer": "shadow"},
        {"riddle": "Every living person will meet me one day, even kings and queens.\nNo one has ever found a way to escape me.\nWhat am I?", "answer": "death"},
    ],
    "italiano": [
        {"riddle": "Ripeto le parole che gridi in una sala vuota del castello.\nSuccedo soltanto dopo che fai un rumore.\nCosa sono?", "answer": "eco"},
        {"riddle": "Non puoi trattenermi o chiudermi in una scatola, eppure non smetto mai di passare.\nTutti vorrebbero averne di più.\nCosa sono?", "answer": "tempo"},
        {"riddle": "Non ho corpo né arma, ma posso comunque fare molto male.\nSe qualcuno mi crede, posso trasformare amici in nemici.\nCosa sono?", "answer": "menzogna"},
        {"riddle": "Appaio per terra accanto a te ogni volta che la luce ti illumina.\nPuoi vedere la mia forma, ma non potrai mai toccarmi.\nCosa sono?", "answer": "ombra"},
        {"riddle": "Ogni essere vivente mi incontrerà un giorno, anche i re e le regine.\nNessuno ha mai trovato un modo per sfuggirmi.\nCosa sono?", "answer": "morte"},
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

def _format_secret_policy(npc_data, hostility, friendship):
    """Regola di divulgazione dei segreti: rivela / accenna / nega, in base a ostilita' e amicizia."""
    secrets = npc_data.get("info_segrete", "").strip()
    if not secrets:
        return ""
    if friendship > 60 or hostility < 20:
        stance = (
            "The player has earned it. You MAY reveal what you know, in character, "
            "as a secret shared with someone you trust, never as a game hint."
        )
    elif hostility < 40:
        stance = (
            "The player has not earned it yet. You may HINT at what you know, obliquely, "
            "but you must NOT reveal it fully."
        )
    else:
        stance = (
            "The player has not earned it. You REFUSE to share what you know. "
            "Deflect, change the subject, or tell him to prove himself first."
        )
    return f"\n\nWHAT YOU SECRETLY KNOW:\n{secrets}\nDISCLOSURE: {stance}"


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

    location = npc_data.get("location", "")
    if location:
        location_info = (
            f"CURRENT LOCATION: {location}. You ({npc_name}) are here, and so is the player. "
            f"Speak of this place as the one around you, and of the other rooms as places elsewhere in the castle."
        )
    else:
        location_info = f"CURRENT LOCATION: somewhere inside Oraculus Castle. You ({npc_name}) are here with the player."

    dynamic = _format_dynamic_secrets(npc_name, friendship, context_vars)
    secret_policy = _format_secret_policy(npc_data, hostility, friendship)

    system = (
        f"{STORY_CONTEXT}\n\n"
        f"{location_info}\n\n"
        f"CHARACTER:\n{personality}\n"
        f"{secret_policy}\n\n"
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
    secret_policy = _format_secret_policy(npc_data, hostility, friendship)
    location = npc_data.get("location", "")
    location_info = (
        f"CURRENT LOCATION: {location}. You ({npc_name}) are here, and so is the player.\n\n"
        if location else ""
    )

    return (
        f"{STORY_CONTEXT}\n\n"
        f"{location_info}"
        f"CHARACTER:\n{personality}\n"
        f"{secret_policy}\n\n"
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
        if Llama is None:
            print("[llama.cpp] Pacchetto llama_cpp non installato: salto il caricamento locale (modalita' API remota).")
        elif os.path.exists(MODEL_PATH):
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
                model=HF_MODEL,
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

        variation_hint = f" (session: {session_id})" if session_id else ""

        system = (
            f"You are an ancient spirit guardian of Oraculus Castle, year 1300.\n"
            f"{STORY_CONTEXT}\n\n"
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