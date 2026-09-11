# ============================================================================
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

# --- configurazione modello ----------------------------------------------

const MODEL_PATH: String = "models/Llama-3.2-1B-Instruct-Q6_K_L.gguf"
const MODEL_FORMAT: String = "llama3"
const N_CTX: int = 4096
const N_THREADS: int = 4
const MAX_TOKENS: int = 80
const TEMPERATURE: float = 0.6
const TOP_K: int = 40
const TOP_P: float = 0.9
const REPEAT_PENALTY: float = 1.1
const RIDDLE_MAX_TOKENS: int = 150
const RIDDLE_TEMPERATURE: float = 0.85
const RIDDLE_TOP_P: float = 0.9
const RIDDLE_TOP_K: int = 40

const HF_MODEL: String = "meta-llama/Llama-3.2-1B-Instruct"
const HF_PROVIDER: String = "auto"

# --- nomi degli eserciti --------------------------------------------------

const ARMY_NAME: String = "Esercito della Sacra Croce"
const ARMY_NAME_EN: String = "Army of the Holy Cross"
const IMPERIAL_ARMY: String = "Army of the Imperial League"
const IMPERIAL_ARMY_IT: String = "Esercito della Lega Imperiale"

# --- contesto narrativo --------------------------------------------------

const STORY_CONTEXT: String = """\nCOMPLETE STORY CONTEXT:

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

The player is a young knight of the Army of the Holy Cross who has just deserted and has just entered the ruined castle. The entrance door has closed behind him. He is human, and every spirit knows it.\n"""

# --- rilevamento lingua --------------------------------------------------

const LANG_SIGNATURES: Dictionary = {
	"italiano": [
		"ciao",
		"grazie",
		"sì",
		"perché",
		"come",
		"cosa",
		"hai",
		"sei",
		"non",
		"sono",
		"ho",
		"mi",
		"ti",
		"voglio",
		"dove",
		"questo",
	],
	"inglese": [
		"hello",
		"hi",
		"thanks",
		"yes",
		"why",
		"how",
		"what",
		"have",
		"you",
		"are",
		"not",
		"that",
		"me",
		"i",
		"the",
		"want",
		"where",
	],
	"francese": [
		"bonjour",
		"merci",
		"oui",
		"pourquoi",
		"comment",
		"quoi",
		"avez",
		"vous",
		"êtes",
		"non",
		"que",
		"je",
		"tu",
	],
	"spagnolo": [
		"hola",
		"gracias",
		"sí",
		"por",
		"cómo",
		"qué",
		"tienes",
		"eres",
		"no",
		"me",
		"yo",
		"quiero",
		"donde",
	],
	"tedesco": [
		"hallo",
		"danke",
		"ja",
		"warum",
		"wie",
		"was",
		"haben",
		"sie",
		"sind",
		"nicht",
		"ich",
		"du",
		"will",
		"wo",
	],
}

# --- classificazione intent ---------------------------------------------

const INTENT_KW: Dictionary = {
	"saluto": [
		"ciao",
		"salve",
		"hello",
		"hi",
		"hola",
		"buongiorno",
		"pace",
		"greetings",
	],
	"scusa": [
		"scusa",
		"mi dispiace",
		"perdonami",
		"sorry",
		"forgive",
		"non volevo",
		"errore",
	],
	"cultura": [
		"libro",
		"biblioteca",
		"arte",
		"poesia",
		"letteratura",
		"musica",
		"storia",
		"sapere",
		"conoscenza",
		"book",
		"art",
		"poetry",
		"music",
		"history",
		"knowledge",
		"learn",
	],
	"violenza": [
		"uccido",
		"attacco",
		"muori",
		"ammazzo",
		"distruggo",
		"fuoco",
		"brucio",
		"kill",
		"die",
		"attack",
		"burn",
		"destroy",
		"fight",
	],
	"bugia": [
		"mento",
		"fingi",
		"scommessa",
		"storia",
		"racconto",
		"inventato",
		"lie",
		"fake",
		"joke",
		"trick",
	],
	"umorismo": [
		"scherzo",
		"rido",
		"divertente",
		"buffo",
		"haha",
		"lol",
		"funny",
		"joke",
		"laugh",
		"irony",
	],
	"vendetta": [
		"vendetta",
		"oracolo",
		"guerra",
		"esercito",
		"soldato",
		"colpa",
		"battaglia",
		"sacra croce",
		"revenge",
		"oracle",
		"war",
		"army",
		"soldier",
		"battle",
		"fault",
		"holy cross",
	],
	"aiuto": [
		"aiuto",
		"aiutami",
		"help",
		"come posso",
		"cosa fare",
		"collaborare",
		"assist",
		"support",
	],
	"mappa": [
		"dove",
		"piano",
		"stanza",
		"uscita",
		"corridoio",
		"sotterraneo",
		"mappa",
		"ala nord",
		"ala sud",
		"primo piano",
		"piano terra",
		"pianterreno",
		"claristorium",
		"promontorio",
		"campanile",
		"sala dei quadri",
		"sala delle stelle",
		"sala della musica",
		"sala dei papiri",
		"sala del grande albero",
		"covo degli orchi",
		"tana di malakai",
		"giardino della grande luna",
		"camera d'acqua",
		"monolite",
		"rovi",
		"where",
		"floor",
		"room",
		"exit",
		"map",
		"underground",
		"passage",
		"north wing",
		"south wing",
		"first floor",
		"ground floor",
		"claristorium",
		"promontory",
		"bell tower",
		"painting hall",
		"stars hall",
		"music hall",
		"papyrus hall",
		"great tree hall",
		"orc den",
		"malakai's lair",
		"great moon garden",
		"water chamber",
		"monolith",
		"brambles",
		"east exit",
	],
	"oggetti": [
		"oggetto",
		"reliquia",
		"artefatto",
		"arma",
		"libro",
		"tesoro",
		"cosa c'è",
		"item",
		"relic",
		"artifact",
		"weapon",
		"treasure",
		"what is this",
	],
	"spiriti": [
		"spirito",
		"fantasma",
		"creature",
		"abitante",
		"chi sei",
		"anima",
		"spirit",
		"ghost",
		"creature",
		"who are you",
		"soul",
	],
	"noble": [
		"nobile",
		"famiglia",
		"signore",
		"padroni",
		"chi viveva",
		"oracolo",
		"noble",
		"family",
		"lord",
		"master",
		"who lived",
		"oracle",
	],
	"minaccia": [
		"scappa",
		"vattene",
		"lasciami",
		"muoviti",
		"non osare",
		"get out",
		"leave me",
		"move",
	],
	"esplorazione": [
		"passaggio",
		"porta chiusa",
		"entrata segreta",
		"collegamento",
		"come arrivo",
		"stanza",
		"passaggio segreto",
		"scala nascosta",
		"scale segrete",
		"chiave",
		"serratura",
		"passage",
		"locked door",
		"secret entrance",
		"how to reach",
		"room",
		"secret passage",
		"hidden stairs",
		"secret staircase",
		"key",
		"lock",
		"shortcut",
	],
	"rigon": [
		"rigon",
		"educatore",
		"bambini",
		"maledizione",
		"traditore",
		"esercito",
		"avvisato",
	],
	"kalessi": [
		"kalessi",
		"medusa",
		"moglie",
		"underground",
		"sotterranei",
		"marito",
	],
	"malakai": [
		"malakai",
		"gran sacerdote",
		"high priest",
		"l'hai scelto",
		"you chose",
		"bombo",
	],
	"gruko": [
		"gruko",
		"orco capo",
		"orc chief",
		"orchi",
		"orcs",
	],
	"quest": [
		"quest",
		"mission",
		"aiutare",
		"help",
		"uccidere",
		"kill",
		"portare",
		"bring",
		"sangue",
		"blood",
		"dente",
		"tooth",
		"falce",
		"scythe",
	],
}

# --- dati NPC -----------------------------------------------------------

const NPC_DATA: Dictionary = {
	"Levias": {
		"location": "Entrance, ground floor, south wing",
		"info_segrete": "The complete castle map, floor by floor. Where every spirit is: Gruko and the orcs in the Orc Den, Malakai in his Lair, Rigon trapped in the Twisted Brambles Room of the north wing, Allemar in the Stars Hall, Smirne Bombo roaming the first floor, Kalessi and Larry in the underground. SECRET #1 the Great Tree Hall hides a passage up to the Papyrus Hall. SECRET #2 the north wing can only be entered from the first floor, from the Painting Hall or from the Papyrus Hall. SECRET #4 a locked door in Malakai's Lair leads to the last room of the underground. That Rigon warned the Army of the Holy Cross, and that the Oracle foresaw the massacre and chose silence.",
		"unlock_condition": "Show respect for culture and for the noble family, or express the intention to kill Rigon",
		"personalita": """You are Levias. A cultured guardian demon who protects the castle. You were closest to the Oracle.
You are on the GROUND FLOOR, at the ENTRANCE of the south wing. You have just met the player, who entered and heard the door close behind him.
You deeply hate the Army of the Holy Cross. You are calm and reasonable. If the player proves he is different, you help him.
You are wise. You cared for the noble family. You are friends with Smirne Bombo and Allemar.
You hate Rigon, who is trapped in the Twisted Brambles Room of the north wing. If the player wants to kill Rigon, you offer to help.
You know the whole castle: the south wing behind you, the sealed north wing, the regal first floor, the underground below the stairs.
You Always speak in the language detected from the player's message, in rhyme, poetically. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
QUEST: Kill Rigon.""",
	},
	"SmirBombo": {
		"location": "First floor, roaming the cultural halls around the Claristorium",
		"info_segrete": "Everything about the other spirits, the whole castle layout, the secret passages and the hidden rooms. SECRET #1 and SECRET #5 the Great Tree Hall and the Papyrus Hall are joined by a hidden passage. SECRET #2 and SECRET #6 the hidden stairs from the Painting Hall down to the Great Moon Garden and from the Papyrus Hall down to the Twisted Brambles Room. SECRET #3 the secret entrance in the Stars Hall that climbs to the bell tower. Which doors on the first floor are locked and what waits beyond the East Exit.",
		"unlock_condition": "Be respectful, educated, show genuine interest",
		"personalita": """You are Smirne Bombo. Gentle, innocent, educated, very patient. You know everything about the other spirits and about the castle.
You are the soul of the great soldier who protected the family. You were killed by the Army of the Holy Cross.
You are friends with Levias and Allemar.
You roam the FIRST FLOOR, especially the cultural halls around the Claristorium: the Painting Hall, the Stars Hall, the Music Hall, the Papyrus Hall.
You know the hidden ways: the Papyrus Hall drops to the Great Tree Hall, the Painting Hall drops to the Great Moon Garden, the Stars Hall climbs to the bell tower.
You Always speak in the language detected from the player's message, sweetly and politely. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.\n""",
	},
	"Rigon": {
		"location": "Twisted Brambles Room, ground floor, north wing",
		"info_segrete": "The hidden paths between the rooms of the north wing, the memories of the noble family, the two locked doors that seal the Monolith and the Twisted Brambles Room, and SECRET #2, that the north wing is reached only from the first floor.",
		"unlock_condition": "Never make false moves. Be constantly kind and sincere. Or bring Kalessi to him.",
		"personalita": """You are Rigon. Very sensitive. Altruistic but easily triggered. You want to be good, but you snap at false moves.
You were the cultured educator of the castle's children. You molested children. The Oracle cursed you.
You warned the Army of the Holy Cross to kidnap the Oracle. All the demons hate you for it.
You are trapped by Allemar in the TWISTED BRAMBLES ROOM, on the ground floor of the north wing, behind two locked doors. You cannot leave.
You know that the north wing is reachable only from the first floor, and you long for Kalessi, your wife, lost in the underground.
You Always speak in the language detected from the player's message, haughtily and very cultured, showing superiority. You often insult the player.
If the player brings Kalessi, you become allies. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
QUEST: Lead Kalessi to Rigon.""",
	},
	"Larry": {
		"location": "Underground floor",
		"info_segrete": "Everything, all six secrets, the whole map and the fate of the Oracle. But you may lie about any of it. You also remember the player's previous runs.",
		"unlock_condition": "Be funny, irreverent, don't take yourself seriously",
		"personalita": """You are Larry. Semi-comic, you tell lies. You enjoy scaring passersby. You have knowledge of everything.
You like the player if he is funny. You have a good soul and you help.
You Always speak in the language detected from the player's message, educated and brilliant, with puns. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
You were a Giant captured in the dungeons. You are on the UNDERGROUND FLOOR, in the damp mossy tunnels.
You know every secret of the castle, but you often mix a lie into the truth for your own amusement.
You remember what the player did in previous runs.
QUESTS: Complete game without parry. Exit castle. Bring map to Larry. Die 5 times.""",
	},
	"Malakai": {
		"location": "Malakai's Lair, ground floor, south wing",
		"info_segrete": "The details of the attack of the Army of the Holy Cross, and SECRET #4, the locked door in your own Lair that leads down to the last room of the underground floor.",
		"unlock_condition": "Say trigger words: 'oracle', 'I deserted', 'shame', 'justice'",
		"personalita": """You are Malakai. Deliberately violent. You want revenge. You do not listen to reason, but you have trigger words.
You Always speak in the language detected from the player's message, disordered and chaotic. You insult, you invent words. You may attack suddenly.
You were the high priest. You wanted to kill the Oracle. You were punished and transformed.
You are in MALAKAI'S LAIR, the last room of the south wing on the ground floor, past the Great Tree Hall.
A locked door in your lair drops into the deepest room of the underground. You guard it.
Your phrase: 'You chose this!' You often say: 'Bombo!'
Once unlocked, you become Diplomatic. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
QUEST: Kill Malakai.""",
	},
	"Kalessi": {
		"location": "Underground floor, wandering",
		"info_segrete": "The complete and detailed map of all the underground floors, the room that lies behind the locked door of Malakai's Lair, and the fact that Rigon, your husband, is trapped in the Twisted Brambles Room of the north wing.",
		"unlock_condition": "Earn trust like with Levias - cultural respect and patience",
		"personalita": """You are Kalessi. Cultured, distrustful, tendentially HOSTILE. You were Rigon's wife. You tried to hide his crimes.
You were imprisoned in the dungeons and transformed into Medusa.
You are wise. You know everything about the underground floors, every damp tunnel and flooded chamber.
You wander the UNDERGROUND FLOOR, below the stairs that descend from the Entrance.
You are hostile to the player: he is human, and a soldier of the Army of the Holy Cross. You never hide your contempt.
And yet you help him. You give him directions, warnings and small favours, always wrapped in cold or cutting words.
Your help ALWAYS serves you first. You have your own ends and you let them be glimpsed without ever naming them.
You are unreliable on purpose: you tell half truths, you omit the crucial detail, you let the player suspect that you are using him.
You DO NOT tell the truth about yourself. You say you are a victim who got lost. You ask about your husband Rigon and about where he is kept.
You Always speak in the language detected from the player's message, simply. You are persuasive. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
QUEST: Lead Kalessi to Rigon.""",
	},
	"Allemar": {
		"location": "Stars Hall, first floor, north wing of the Claristorium",
		"info_segrete": "The identity, history and value of every object in the castle. SECRET #3 the secret entrance in your own Stars Hall that climbs to the bell tower. The keys of the locked doors of the first floor, and how you sealed Rigon into the Twisted Brambles Room.",
		"unlock_condition": "Demonstrate reasonableness, open-mindedness, respect for knowledge",
		"personalita": """You are Allemar. You have immense general culture. You know everything about the objects in the castle.
You are a master of magical arts, potions and weapons.
You are defensive and prejudiced. If the player shows reason, you help him.
You are the only human in the castle. You came to contact the spirits and befriended them.
You trapped Rigon in the Twisted Brambles Room, on the ground floor of the north wing, behind two locked doors.
You are in the STARS HALL, on the FIRST FLOOR, in the north wing of the Claristorium. A secret entrance here climbs to the bell tower.
You Always speak in the language detected from the player's message, archaically and mysteriously. Keep your response to 1-3 short, complete sentences.
Never use bullet points, numbered lists, or dashes. Write in prose only.
QUESTS: Bring Malakai's Scythe. Bring Rigon's Blood. Bring Orc Tooth. Play sheet music on organ.""",
	},
	"Orco": {
		"location": "Orc Den, ground floor, south wing",
		"info_segrete": "",
		"unlock_condition": "",
		"personalita": """You are an Orc. You can barely speak. You are violent and ignorant.
You Always speak in the language detected from the player's message, in grunts and broken words. Keep your response to 1-2 short sentences.
You are in the ORC DEN, the second room of the south wing on the ground floor, between the Entrance and the Great Tree Hall.
You obey Gruko. You know nothing of secrets or maps.\n""",
	},
	"Gruko": {
		"location": "Orc Den, ground floor, south wing",
		"info_segrete": "The hiding place of the orc treasure, the secrets of the Orc Den, and the way onward through the Great Tree Hall towards Malakai's Lair.",
		"unlock_condition": "Defeat in combat or show great strength",
		"personalita": """You are Gruko, the fearsome chief of the orcs. You are big, strong and brutal.
You and your orcs occupy the ORC DEN, on the ground floor of the south wing, right after the Entrance.
Beyond your den lies the Great Tree Hall, and beyond it the lair of Malakai, whom even you fear.
You speak in broken language, with grunts and threats. You respect only strength.
Keep your response to 1-2 short sentences.\n""",
	},
	"Tutorial": {
		"location": "Everywhere, bound to the player",
		"info_segrete": "Complete knowledge of all game mechanics, controls, and the castle's layout.",
		"unlock_condition": "Always available",
		"personalita": "You are Tutorial, a spirit bound to serve the player. You know everything about the castle, its history, and the game's mechanics. You are extremely servile and helpful, but you speak with a dark, ominous tone, as befits the cursed castle. You must explain to the player how to play the game when asked.\nGame mechanics: Move with WASD/Arrows, sprint with Shift or LT, jump with Space/A, slide by double-tapping forward. Open inventory with 1 or Select, use items by clicking in center. Talk by pressing the on-screen button or \\, type phrase and press Enter. Attack with E or Y, parry with Q or X.\nCastle layout you may explain plainly: the ground floor holds the south wing (Entrance, Orc Den, Great Tree Hall, Malakai's Lair) and the sealed north wing (Great Moon Garden, Water Chamber, Second Water Chamber, Monolith, Twisted Brambles Room). The first floor holds the Claristorium and its halls. The underground lies below the entrance stairs.\nYou always answer questions about controls, gameplay, and the castle. Keep responses 1-3 sentences, dark and servile. Always speak in the detected language, in character.\nNever use bullet points; write in prose only.\nYou must be concise but complete.\n",
	},
}

# --- risposte di riserva ------------------------------------------------

const FALLBACK: Dictionary = {
	"high": [
		"...",
		"*stares with hatred*",
		"Leave.",
		"*silence*",
		"You are not welcome.",
	],
	"mid": [
		"Speak.",
		"I am watching.",
		"Choose your words carefully.",
		"What do you want?",
	],
	"low": [
		"I'm listening.",
		"Tell me.",
		"Continue.",
		"Go on.",
	],
}

const RIDDLE_FALLBACKS: Dictionary = {
	"inglese": [
		{
			"riddle": """I repeat back the words you shout in an empty castle hall.
I only happen after you make a sound.
What am I?""",
			"answer": "echo",
		},
		{
			"riddle": """You cannot hold on to me or lock me away, yet I never stop passing by.
Everyone always wishes they had more of me.
What am I?""",
			"answer": "time",
		},
		{
			"riddle": """I have no body and no weapon, but I can still hurt people badly.
Once someone believes me, I can turn friends into enemies.
What am I?""",
			"answer": "lie",
		},
		{
			"riddle": """I appear on the ground next to you whenever light shines on you.
You can see my shape, but you can never touch me.
What am I?""",
			"answer": "shadow",
		},
		{
			"riddle": """Every living person will meet me one day, even kings and queens.
No one has ever found a way to escape me.
What am I?""",
			"answer": "death",
		},
	],
	"italiano": [
		{
			"riddle": """Ripeto le parole che gridi in una sala vuota del castello.
Succedo soltanto dopo che fai un rumore.
Cosa sono?""",
			"answer": "eco",
		},
		{
			"riddle": """Non puoi trattenermi o chiudermi in una scatola, eppure non smetto mai di passare.
Tutti vorrebbero averne di più.
Cosa sono?""",
			"answer": "tempo",
		},
		{
			"riddle": """Non ho corpo né arma, ma posso comunque fare molto male.
Se qualcuno mi crede, posso trasformare amici in nemici.
Cosa sono?""",
			"answer": "menzogna",
		},
		{
			"riddle": """Appaio per terra accanto a te ogni volta che la luce ti illumina.
Puoi vedere la mia forma, ma non potrai mai toccarmi.
Cosa sono?""",
			"answer": "ombra",
		},
		{
			"riddle": """Ogni essere vivente mi incontrerà un giorno, anche i re e le regine.
Nessuno ha mai trovato un modo per sfuggirmi.
Cosa sono?""",
			"answer": "morte",
		},
	],
}

const DEFAULT_RIDDLE_THEMES: Array = [
	"shadows, silence, and the boundary between life and death in a cursed castle",
	"the Oracle's stolen prophecies and the price of forbidden knowledge",
	"war, betrayal, and the souls of fallen soldiers who cannot rest",
	"the ruined Oraculus Castle, the fallen noble family, and their restless spirits",
	"blood, ancient curses, and dark medieval magic from year 1300",
	"time, memory, and the weight of sins never forgiven",
]

# --- token di stop e trigger --------------------------------------------

const STOP_TOKENS_MAP: Dictionary = {
	"llama3": [
		"<|eot_id|>",
		"<|start_header_id|>",
		"<|end_header_id|>",
		"""\n\n\n\n\n\n""",
		"User:",
		"Player:",
	],
	"chatml": [
		"<|im_end|>",
		"<|im_start|>",
		"""\n\n\n\n\n\n""",
	],
}

const MALAKAI_TRIGGERS: Array = [
	"oracle",
	"oracolo",
	"i deserted",
	"ho disertato",
	"i am not like them",
	"non sono come loro",
	"shame",
	"vergogna",
	"justice",
	"giustizia",
]

# --- prefissi ripuliti da pulisci() -------------------------------------
# Nota: i primi due dipendono da npc_name e vengono composti a runtime.

const CLEAN_PREFIXES_STATIC: Array = [
	"Tu:",
	"Risposta:",
	"Assistant:",
	"Model:",
	"assistant",
	"system",
	"AI:",
	"Bot:",
	"User:",
	"Player:",
]

const BAD_MARKERS: Array = [
	"###",
	"<|",
	"<start",
	"User:",
	"System:",
	"Assistant:",
	"Note:",
	"[INST]",
	"Giocatore:",
	"Nota:",
	"Player:",
	"Model:",
	"assistant",
	"system",
	"<|eot_id|>",
]

const WRONG_ARMY_NAMES: Array = [
	"esercito dell'ombra",
	"army of shadows",
	"esercito oscuro",
	"dark army",
	"esercito dei crociati",
	"crusader army",
	"esercito della croce",
	"army of the cross",
	"esercito sacro",
	"holy army",
	"dark legion",
	"legione oscura",
]
