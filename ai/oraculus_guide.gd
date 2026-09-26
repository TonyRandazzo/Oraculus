# ============================================================================
# La guida del menu: risposte chiare e immediate su lore, comandi, obiettivi,
# struttura del castello e cosa fare.
#
# Una trentina di SCHEDE scritte a mano, in tutte e cinque le lingue del
# menu, scelte riconoscendo le parole chiave della domanda: la risposta e'
# pronta in meno di un millisecondo, anche prima che il modello si carichi,
# ed e' sempre corretta. Se nessuna scheda corrisponde, il menu lo dice
# (NON_SO) ed elenca cosa si puo' chiedere.
#
# Il modello qui non c'e', di proposito. Misurato sul 1B locale: lasciato
# rispondere con le schede come unici fatti, inventava ("il gioco dura circa
# 6-8 ore", "yes, there is a final boss"); usato solo per scegliere la scheda
# giusta, ne azzeccava 2-4 su 24. Vedi ai/README.md, "La guida del menu".
#
# Le schede non svelano i segreti del castello (passaggi nascosti, parole che
# calmano Malakai, colpe di Rigon): quelli restano agli spiriti.
#
# Solo GDScript: non ha un corrispettivo in inference.py.
# ============================================================================
class_name OraculusGuide
extends RefCounted

## Ogni scheda: "id", "peso" (a parita' di parole trovate vince il piu'
## pesante: le schede generiche pesano meno di quelle specifiche), "chiavi" e
## la risposta per ciascuna lingua di GameState.LANGUAGES.
##
## Le chiavi sono gia' normalizzate (minuscole, senza accenti né apostrofi):
##  - "salt"   una parola che comincia cosi' (salto, saltare, saltar);
##  - "=hi"    esattamente quella parola;
##  - "come si gioca"  con uno spazio: quella sequenza di parole.
const SCHEDE: Array = [
	{
		"id": "saluto", "peso": 0.3,
		"chiavi": ["=ciao", "=salve", "=hello", "=hi", "=hey", "=bonjour", "=salut", "=hola", "=hallo",
			"=buongiorno", "=buonasera", "=aiuto", "=help", "=aide", "=ayuda", "=hilfe",
			"cosa posso chiederti", "cosa posso chiedere", "cosa sai", "what can i ask", "what do you know",
			"que puis je", "que sais tu", "que puedo preguntar", "que sabes", "was kann ich fragen", "was weisst du"],
		"italiano": "Benvenuto, cavaliere. Chiedimi della storia, degli spiriti, dei comandi, dell'obiettivo, della mappa del castello, delle porte o di cosa fare per iniziare.",
		"inglese": "Welcome, knight. Ask me about the story, the spirits, the controls, your goal, the castle map, the doors, or what to do first.",
		"francese": "Bienvenue, chevalier. Demande-moi l'histoire, les esprits, les commandes, ton objectif, le plan du château, les portes ou par où commencer.",
		"spagnolo": "Bienvenido, caballero. Pregúntame por la historia, los espíritus, los controles, tu objetivo, el mapa del castillo, las puertas o qué hacer primero.",
		"tedesco": "Willkommen, Ritter. Frag mich nach der Geschichte, den Geistern, der Steuerung, deinem Ziel, der Karte der Burg, den Türen oder womit du anfangen sollst.",
	},
	{
		"id": "grazie", "peso": 0.3,
		"chiavi": ["=grazie", "=thanks", "=thank", "=thx", "=ty", "=merci", "=gracias", "=danke"],
		"italiano": "Di nulla. Chiedimi pure altro sul castello.",
		"inglese": "You're welcome. Ask me anything else about the castle.",
		"francese": "De rien. Pose-moi d'autres questions sur le château.",
		"spagnolo": "De nada. Pregúntame lo que quieras sobre el castillo.",
		"tedesco": "Gern geschehen. Frag mich ruhig mehr über die Burg.",
	},
	{
		"id": "gioco", "peso": 0.5,
		"chiavi": ["di cosa parla", "what is it about", "what s it about", "de quoi parle", "de que trata", "worum geht", "che gioco", "che tipo di gioco", "cos e questo gioco", "cos e oraculus", "cosa e oraculus",
			"what is this game", "what is oraculus", "what kind of game", "what type of game",
			"=genere", "=genre", "=genero", "quel jeu", "quel type de jeu", "qu est ce que oraculus",
			"que juego", "que tipo de juego", "que es oraculus", "que es este juego",
			"was fur ein spiel", "was ist oraculus", "was ist das fur ein spiel"],
		"italiano": "Oraculus è un'avventura d'azione in 2D ambientata nel 1300, in un castello in rovina abitato da spiriti. Esplori, combatti, risolvi indovinelli e minigiochi e parli liberamente con gli spiriti: scrivi quello che vuoi, e il modo in cui li tratti decide la tua storia.",
		"inglese": "Oraculus is a 2D action-adventure set in the year 1300, in a ruined castle haunted by spirits. You explore, fight, solve riddles and minigames, and talk freely with the spirits: type whatever you want, and the way you treat them shapes your story.",
		"francese": "Oraculus est un jeu d'action-aventure en 2D qui se déroule en 1300, dans un château en ruine hanté par des esprits. Tu explores, tu combats, tu résous énigmes et mini-jeux et tu parles librement aux esprits : écris ce que tu veux, et ta façon de les traiter façonne ton histoire.",
		"spagnolo": "Oraculus es una aventura de acción en 2D ambientada en el año 1300, en un castillo en ruinas habitado por espíritus. Exploras, luchas, resuelves acertijos y minijuegos y hablas libremente con los espíritus: escribe lo que quieras, y la forma en que los tratas decide tu historia.",
		"tedesco": "Oraculus ist ein 2D-Action-Adventure im Jahr 1300, in einer verfallenen Burg voller Geister. Du erkundest, kämpfst, löst Rätsel und Minispiele und sprichst frei mit den Geistern: Schreib, was du willst, und wie du sie behandelst, bestimmt deine Geschichte.",
	},
	{
		"id": "storia", "peso": 0.6,
		"chiavi": ["chi abitava", "chi viveva", "who lived", "qui vivait", "quien vivia", "wer lebte", "succed", "=accaduto", "ruin", "rovin", "going on", "happening", "se passe", "pasa aqui", "passiert hier", "stori", "=story", "=lore", "=trama", "=plot", "histoire", "histori", "geschicht",
			"background", "ambientaz", "=setting", "=1300", "antefatt", "prologo", "prolog", "vorgeschicht",
			"cosa e successo", "what happened", "que s est il passe", "que paso", "was ist passiert",
			"famigli", "=family", "famille", "familia", "nobil", "=noble", "=nobles", "=adel", "adlig"],
		"italiano": "Anno 1300. Il castello di Oraculus era la casa di una ricca famiglia nobile guidata dall'Oracolo, un veggente di 127 anni legato agli spiriti. Durante la guerra fra la Lega Imperiale e la Sacra Croce, l'esercito della Sacra Croce rapì l'Oracolo, sterminò i nobili e saccheggiò il castello. Tre anni dopo tu, giovane cavaliere disertore di quell'esercito, ti rifugi fra le rovine: la porta si chiude alle tue spalle, e gli spiriti odiano gli umani.",
		"inglese": "The year is 1300. Oraculus Castle was home to a rich noble family led by the Oracle, a 127-year-old seer bound to the spirits. During the war between the Imperial League and the Holy Cross, the Army of the Holy Cross kidnapped the Oracle, slaughtered the nobles and looted the castle. Three years later you, a young knight who deserted that army, take refuge in the ruins: the door shuts behind you, and the spirits hate humans.",
		"francese": "Nous sommes en 1300. Le château d'Oraculus abritait une riche famille noble menée par l'Oracle, un voyant de 127 ans lié aux esprits. Pendant la guerre entre la Ligue Impériale et la Sainte Croix, l'armée de la Sainte Croix a enlevé l'Oracle, massacré les nobles et pillé le château. Trois ans plus tard, toi, jeune chevalier déserteur de cette armée, tu te réfugies dans les ruines : la porte se referme derrière toi, et les esprits haïssent les humains.",
		"spagnolo": "Año 1300. El castillo de Oraculus era el hogar de una rica familia noble guiada por el Oráculo, un vidente de 127 años unido a los espíritus. Durante la guerra entre la Liga Imperial y la Santa Cruz, el ejército de la Santa Cruz secuestró al Oráculo, exterminó a los nobles y saqueó el castillo. Tres años después tú, un joven caballero desertor de ese ejército, te refugias en las ruinas: la puerta se cierra a tu espalda, y los espíritus odian a los humanos.",
		"tedesco": "Wir schreiben das Jahr 1300. Die Burg Oraculus war das Heim einer reichen Adelsfamilie, angeführt vom Orakel, einem 127-jährigen Seher im Bund mit den Geistern. Im Krieg zwischen der Kaiserlichen Liga und dem Heiligen Kreuz entführte das Heer des Heiligen Kreuzes das Orakel, tötete die Adligen und plünderte die Burg. Drei Jahre später suchst du, ein junger Ritter, der aus diesem Heer desertiert ist, Zuflucht in den Ruinen: Die Tür fällt hinter dir zu, und die Geister hassen die Menschen.",
	},
	{
		"id": "oracolo", "peso": 1.0,
		"chiavi": ["old man", "vecchio", "viejo", "vieil", "alte mann", "alter mann", "alten mann", "oracol", "oracle", "oraculo", "orakel", "veggent", "=seer", "voyant", "vident", "seher",
			"profez", "prophe", "profec", "prophez", "rapit", "kidnap", "enlev", "secuestr", "entfuhr"],
		"italiano": "L'Oracolo era il capofamiglia: 127 anni, poteri spirituali e profetici. Con le sue visioni rese ricca la famiglia e la legò agli spiriti del castello. Malato, previde il proprio rapimento ma scelse di tacere e ordinò agli spiriti di nascondersi. L'esercito della Sacra Croce lo portò via per usare le sue profezie in guerra.",
		"inglese": "The Oracle was the head of the family: 127 years old, with spiritual and prophetic powers. His visions made the family rich and bound it to the castle's spirits. Ill and weakened, he foresaw his own kidnapping but chose silence and ordered the spirits to hide. The Army of the Holy Cross took him away to use his prophecies in the war.",
		"francese": "L'Oracle était le chef de la famille : 127 ans, des pouvoirs spirituels et prophétiques. Ses visions ont enrichi la famille et l'ont liée aux esprits du château. Malade, il a prévu son propre enlèvement mais a choisi de se taire et a ordonné aux esprits de se cacher. L'armée de la Sainte Croix l'a emmené pour utiliser ses prophéties dans la guerre.",
		"spagnolo": "El Oráculo era el cabeza de familia: 127 años, con poderes espirituales y proféticos. Sus visiones enriquecieron a la familia y la unieron a los espíritus del castillo. Enfermo, previó su propio secuestro, pero eligió callar y ordenó a los espíritus que se escondieran. El ejército de la Santa Cruz se lo llevó para usar sus profecías en la guerra.",
		"tedesco": "Das Orakel war das Familienoberhaupt: 127 Jahre alt, mit geistigen und prophetischen Kräften. Seine Visionen machten die Familie reich und verbanden sie mit den Geistern der Burg. Krank sah es die eigene Entführung voraus, schwieg aber und befahl den Geistern, sich zu verstecken. Das Heer des Heiligen Kreuzes verschleppte es, um seine Prophezeiungen im Krieg zu nutzen.",
	},
	{
		"id": "guerra", "peso": 1.0,
		"chiavi": ["guerr", "=war", "=wars", "krieg", "eserc", "=army", "armies", "armee", "ejercit", "=heer",
			"=lega", "league", "ligue", "=liga", "croce", "=cross", "croix", "=cruz", "kreuz", "imperial",
			"battagl", "battle", "bataille", "batalla", "schlacht", "comandant", "commander", "commandant", "befehlshaber"],
		"italiano": "Una lunga guerra oppone l'Esercito della Lega Imperiale all'Esercito della Sacra Croce. Il comandante della Sacra Croce rapì l'Oracolo per sfruttarne le profezie e vincere. Tu vieni da quell'esercito, ma hai disertato: per gli spiriti resti comunque un nemico.",
		"inglese": "A long war pits the Army of the Imperial League against the Army of the Holy Cross. The commander of the Holy Cross kidnapped the Oracle to use his prophecies to win. You come from that army, but you deserted: to the spirits you are still an enemy.",
		"francese": "Une longue guerre oppose l'armée de la Ligue Impériale à l'armée de la Sainte Croix. Le commandant de la Sainte Croix a enlevé l'Oracle pour se servir de ses prophéties et gagner. Tu viens de cette armée, mais tu as déserté : pour les esprits, tu restes un ennemi.",
		"spagnolo": "Una larga guerra enfrenta al ejército de la Liga Imperial con el ejército de la Santa Cruz. El comandante de la Santa Cruz secuestró al Oráculo para usar sus profecías y ganar. Tú vienes de ese ejército, pero desertaste: para los espíritus sigues siendo un enemigo.",
		"tedesco": "Ein langer Krieg stellt das Heer der Kaiserlichen Liga gegen das Heer des Heiligen Kreuzes. Der Befehlshaber des Heiligen Kreuzes entführte das Orakel, um mit seinen Prophezeiungen zu siegen. Du stammst aus diesem Heer, bist aber desertiert: Für die Geister bleibst du ein Feind.",
	},
	{
		"id": "protagonista", "peso": 1.0,
		"chiavi": ["perche sono qui", "why am i here", "pourquoi suis je", "por que estoy aqui", "warum bin ich", "chi sono", "who am i", "qui suis je", "quien soy", "wer bin ich", "protagon",
			"cavalier", "knight", "chevalier", "caballer", "=ritter", "personaggio principale", "main character",
			"personnage principal", "personaje principal", "hauptfigur", "disert", "desert"],
		"italiano": "Sei un giovane cavaliere dell'Esercito della Sacra Croce, con ideali molto diversi da quelli dei tuoi compagni: per questo hai disertato. In fuga, hai trovato rifugio nel castello in rovina senza conoscerne la storia. Sei umano, e ogni spirito lo sa.",
		"inglese": "You are a young knight of the Army of the Holy Cross whose ideals are very different from your comrades': that is why you deserted. On the run, you took shelter in the ruined castle without knowing its story. You are human, and every spirit knows it.",
		"francese": "Tu es un jeune chevalier de l'armée de la Sainte Croix, aux idéaux très différents de ceux de tes compagnons : c'est pour cela que tu as déserté. En fuite, tu t'es réfugié dans le château en ruine sans connaître son histoire. Tu es humain, et chaque esprit le sait.",
		"spagnolo": "Eres un joven caballero del ejército de la Santa Cruz con ideales muy distintos a los de tus compañeros: por eso desertaste. En plena huida, te refugiaste en el castillo en ruinas sin conocer su historia. Eres humano, y todos los espíritus lo saben.",
		"tedesco": "Du bist ein junger Ritter des Heeres des Heiligen Kreuzes, mit ganz anderen Idealen als deine Kameraden: Deshalb bist du desertiert. Auf der Flucht hast du in der verfallenen Burg Zuflucht gesucht, ohne ihre Geschichte zu kennen. Du bist ein Mensch, und jeder Geist weiß das.",
	},
	{
		"id": "spiriti", "peso": 0.6,
		"chiavi": ["=odia", "=odiano", "=hate", "=hates", "hassen", "=hasst", "detest", "odian", "spirit", "esprit", "espirit", "=geist", "geister", "fantasm", "ghost", "fantom", "gespenst",
			"personagg", "character", "personnag", "personaj", "figur", "abitant", "inhabit", "habitant",
			"=npc", "=png", "creatur", "kreatur", "chi vive", "who lives", "qui vit", "quien vive", "wer lebt"],
		"italiano": "Nel castello incontrerai: Levias, demone guardiano all'ingresso; Smirne Bombo, fantasma gentile del primo piano; Rigon, prigioniero nell'ala nord; Larry, gigante burlone dei sotterranei; Malakai, ex sommo sacerdote violento; Kalessi, la medusa dei sotterranei; Allemar, mago umano nella Sala delle Stelle; Gruko e i suoi orchi. Chiedimi di uno di loro.",
		"inglese": "In the castle you will meet: Levias, the guardian demon at the entrance; Smirne Bombo, a gentle ghost on the first floor; Rigon, a prisoner in the north wing; Larry, a joking giant in the underground; Malakai, a violent former high priest; Kalessi, the medusa of the underground; Allemar, a human mage in the Stars Hall; Gruko and his orcs. Ask me about any of them.",
		"francese": "Dans le château tu rencontreras : Levias, le démon gardien de l'entrée ; Smirne Bombo, un fantôme bienveillant du premier étage ; Rigon, prisonnier de l'aile nord ; Larry, un géant farceur des souterrains ; Malakai, un ancien grand prêtre violent ; Kalessi, la méduse des souterrains ; Allemar, un mage humain dans la Salle des Étoiles ; Gruko et ses orques. Demande-moi l'un d'eux.",
		"spagnolo": "En el castillo conocerás a: Levias, el demonio guardián de la entrada; Smirne Bombo, un fantasma amable del primer piso; Rigon, prisionero en el ala norte; Larry, un gigante bromista de los subterráneos; Malakai, un violento ex sumo sacerdote; Kalessi, la medusa de los subterráneos; Allemar, un mago humano en la Sala de las Estrellas; Gruko y sus orcos. Pregúntame por cualquiera.",
		"tedesco": "In der Burg triffst du: Levias, den Wächterdämon am Eingang; Smirne Bombo, einen sanften Geist im ersten Stock; Rigon, einen Gefangenen im Nordflügel; Larry, einen scherzenden Riesen im Untergeschoss; Malakai, einen gewalttätigen ehemaligen Hohepriester; Kalessi, die Medusa im Untergeschoss; Allemar, einen menschlichen Magier im Sternensaal; Gruko und seine Orks. Frag mich nach einem von ihnen.",
	},
	{
		"id": "levias", "peso": 1.0,
		"chiavi": ["demon", "damon", "guardian", "guardiano", "gardien", "wachter", "levias"],
		"italiano": "Levias è un demone guardiano colto, il più vicino all'Oracolo: lo incontri subito, all'ingresso. È calmo, ragionevole e parla in rima; odia la Sacra Croce, ma aiuta chi dimostra di essere diverso. Conosce la risposta all'indovinello della porta d'ingresso e te la dirà solo se si fida di te: mostra rispetto per la cultura e per la famiglia nobile.",
		"inglese": "Levias is a cultured guardian demon, the one closest to the Oracle: you meet him right at the entrance. He is calm, reasonable and speaks in rhyme; he hates the Holy Cross but helps those who prove they are different. He knows the answer to the entrance door's riddle and will tell you only if he trusts you: show respect for culture and for the noble family.",
		"francese": "Levias est un démon gardien cultivé, le plus proche de l'Oracle : tu le rencontres dès l'entrée. Calme et raisonnable, il parle en rimes ; il hait la Sainte Croix mais aide ceux qui prouvent être différents. Il connaît la réponse à l'énigme de la porte d'entrée et ne te la dira que s'il te fait confiance : montre du respect pour la culture et pour la famille noble.",
		"spagnolo": "Levias es un demonio guardián culto, el más cercano al Oráculo: lo encuentras nada más entrar. Es tranquilo, razonable y habla en rima; odia a la Santa Cruz, pero ayuda a quien demuestra ser distinto. Conoce la respuesta al acertijo de la puerta de entrada y solo te la dirá si confía en ti: muestra respeto por la cultura y por la familia noble.",
		"tedesco": "Levias ist ein gebildeter Wächterdämon, der dem Orakel am nächsten stand: Du triffst ihn gleich am Eingang. Er ist ruhig, vernünftig und spricht in Reimen; er hasst das Heilige Kreuz, hilft aber jedem, der beweist, dass er anders ist. Er kennt die Lösung des Rätsels am Eingangstor und verrät sie nur, wenn er dir vertraut: Zeig Respekt vor Kultur und Adelsfamilie.",
	},
	{
		"id": "smirne", "peso": 1.0,
		"chiavi": ["smirne", "smirn", "bombo"],
		"italiano": "Smirne Bombo è l'anima del grande soldato che proteggeva la famiglia, ucciso dalla Sacra Croce. Gentile, paziente e istruito, vaga per le sale culturali del primo piano attorno al Claristorium. Sa moltissimo sugli altri spiriti e sul castello: sii educato e mostra interesse sincero.",
		"inglese": "Smirne Bombo is the soul of the great soldier who protected the family, killed by the Holy Cross. Gentle, patient and educated, he roams the cultural halls of the first floor around the Claristorium. He knows a great deal about the other spirits and the castle: be polite and show genuine interest.",
		"francese": "Smirne Bombo est l'âme du grand soldat qui protégeait la famille, tué par la Sainte Croix. Doux, patient et instruit, il erre dans les salles culturelles du premier étage autour du Claristorium. Il en sait beaucoup sur les autres esprits et sur le château : sois poli et montre un intérêt sincère.",
		"spagnolo": "Smirne Bombo es el alma del gran soldado que protegía a la familia, asesinado por la Santa Cruz. Amable, paciente e instruido, recorre las salas culturales del primer piso alrededor del Claristorium. Sabe muchísimo sobre los demás espíritus y el castillo: sé educado y muestra un interés sincero.",
		"tedesco": "Smirne Bombo ist die Seele des großen Soldaten, der die Familie beschützte und vom Heiligen Kreuz getötet wurde. Sanft, geduldig und gebildet streift er durch die Kultursäle im ersten Stock rund um das Claristorium. Er weiß sehr viel über die anderen Geister und die Burg: Sei höflich und zeig echtes Interesse.",
	},
	{
		"id": "rigon", "peso": 1.0,
		"chiavi": ["prigion", "prisoner", "prisonnier", "prisionero", "gefangen", "educator", "educatore", "bambin", "children", "enfant", "nino", "kinder", "rigon"],
		"italiano": "Rigon era l'educatore dei bambini del castello; l'Oracolo lo maledisse, e gli altri spiriti lo odiano. È sensibile, altezzoso e scatta al primo passo falso. Allemar lo tiene prigioniero nella Stanza dei Rovi Intrecciati, nell'ala nord del piano terra, e lui sogna di ritrovare la moglie Kalessi. Con lui sii sempre gentile e sincero.",
		"inglese": "Rigon was the educator of the castle's children; the Oracle cursed him, and the other spirits hate him. He is sensitive, haughty and snaps at the first false move. Allemar keeps him imprisoned in the Twisted Brambles Room, in the north wing of the ground floor, and he longs to find his wife Kalessi. Always be kind and sincere with him.",
		"francese": "Rigon était l'éducateur des enfants du château ; l'Oracle l'a maudit et les autres esprits le haïssent. Sensible et hautain, il s'emporte au moindre faux pas. Allemar le retient prisonnier dans la Salle des Ronces Entrelacées, dans l'aile nord du rez-de-chaussée, et il rêve de retrouver sa femme Kalessi. Sois toujours gentil et sincère avec lui.",
		"spagnolo": "Rigon era el educador de los niños del castillo; el Oráculo lo maldijo y los demás espíritus lo odian. Es sensible, altivo y estalla al primer paso en falso. Allemar lo tiene prisionero en la Sala de las Zarzas Retorcidas, en el ala norte de la planta baja, y él anhela reencontrarse con su esposa Kalessi. Sé siempre amable y sincero con él.",
		"tedesco": "Rigon war der Erzieher der Kinder der Burg; das Orakel verfluchte ihn, und die anderen Geister hassen ihn. Er ist empfindlich, hochmütig und braust beim ersten Fehltritt auf. Allemar hält ihn im Raum der verschlungenen Dornen im Nordflügel des Erdgeschosses gefangen, und er sehnt sich nach seiner Frau Kalessi. Sei immer freundlich und aufrichtig zu ihm.",
	},
	{
		"id": "larry", "peso": 1.0,
		"chiavi": ["funny", "divertent", "buffo", "scherz", "=joke", "=jokes", "blague", "broma", "=witz", "witzig", "larry", "gigant", "giant", "geant", "=riese", "riesen"],
		"italiano": "Larry è un gigante che un tempo fu prigioniero nelle segrete, e ora vive nei sotterranei umidi. Mezzo comico, adora spaventare i passanti, fare giochi di parole e mescolare bugie e verità. Sa tutto del castello e ha un buon cuore: con lui funziona essere spiritosi e non prendersi troppo sul serio.",
		"inglese": "Larry is a giant who was once a prisoner in the dungeons and now lives in the damp underground. Half comic, he loves scaring passers-by, making puns and mixing lies with the truth. He knows everything about the castle and has a good heart: being funny and not taking yourself too seriously works with him.",
		"francese": "Larry est un géant autrefois prisonnier des cachots, qui vit maintenant dans les souterrains humides. À moitié comique, il adore effrayer les passants, faire des jeux de mots et mêler mensonges et vérité. Il sait tout du château et a bon coeur : avec lui, sois drôle et ne te prends pas trop au sérieux.",
		"spagnolo": "Larry es un gigante que fue prisionero en las mazmorras y ahora vive en los húmedos subterráneos. Medio cómico, le encanta asustar a los que pasan, hacer juegos de palabras y mezclar mentiras con verdades. Lo sabe todo del castillo y tiene buen corazón: con él funciona ser gracioso y no tomarse demasiado en serio.",
		"tedesco": "Larry ist ein Riese, der einst in den Verliesen gefangen war und jetzt im feuchten Untergeschoss lebt. Halb komisch liebt er es, Vorbeigehende zu erschrecken, Wortspiele zu machen und Lügen mit Wahrheit zu mischen. Er weiß alles über die Burg und hat ein gutes Herz: Bei ihm hilft es, witzig zu sein und sich nicht zu ernst zu nehmen.",
	},
	{
		"id": "malakai", "peso": 1.0,
		"chiavi": ["malakai", "sacerdot", "priest", "pretre", "priester", "=falce", "scythe"],
		"italiano": "Malakai era il sommo sacerdote: voleva uccidere l'Oracolo e per questo fu punito e trasformato. Violento, caotico e assetato di vendetta, non ascolta la ragione e può attaccarti all'improvviso. Vive nella sua tana, l'ultima stanza dell'ala sud del piano terra. Si dice che certe parole, dette al momento giusto, possano calmarlo.",
		"inglese": "Malakai was the high priest: he wanted to kill the Oracle, and for that he was punished and transformed. Violent, chaotic and thirsty for revenge, he does not listen to reason and may attack you without warning. He lives in his lair, the last room of the south wing on the ground floor. They say certain words, spoken at the right moment, can calm him.",
		"francese": "Malakai était le grand prêtre : il voulait tuer l'Oracle et, pour cela, il a été puni et transformé. Violent, chaotique et assoiffé de vengeance, il n'écoute pas la raison et peut t'attaquer sans prévenir. Il vit dans son antre, la dernière salle de l'aile sud du rez-de-chaussée. On dit que certains mots, prononcés au bon moment, peuvent le calmer.",
		"spagnolo": "Malakai era el sumo sacerdote: quería matar al Oráculo y por ello fue castigado y transformado. Violento, caótico y sediento de venganza, no escucha a la razón y puede atacarte sin aviso. Vive en su madriguera, la última sala del ala sur de la planta baja. Dicen que ciertas palabras, dichas en el momento justo, pueden calmarlo.",
		"tedesco": "Malakai war der Hohepriester: Er wollte das Orakel töten und wurde dafür bestraft und verwandelt. Gewalttätig, chaotisch und rachsüchtig hört er nicht auf Vernunft und kann dich ohne Vorwarnung angreifen. Er haust in seinem Unterschlupf, dem letzten Raum des Südflügels im Erdgeschoss. Man sagt, bestimmte Worte im richtigen Moment könnten ihn beruhigen.",
	},
	{
		"id": "kalessi", "peso": 1.0,
		"chiavi": ["serpent", "snake", "schlang", "moglie", "=wife", "=femme", "esposa", "ehefrau", "=donna", "=woman", "=mujer", "=frau", "kalessi", "medus", "meduse", "gorgon"],
		"italiano": "Kalessi era la moglie di Rigon: imprigionata nelle segrete, è stata trasformata in medusa. Vaga per i sotterranei, che conosce come nessun altro. È ostile e sprezzante, eppure ti aiuta con indicazioni e avvertimenti; attento, però, perché il suo aiuto serve sempre prima i suoi scopi.",
		"inglese": "Kalessi was Rigon's wife: imprisoned in the dungeons, she was turned into a medusa. She wanders the underground, which she knows better than anyone. She is hostile and scornful, yet she helps you with directions and warnings; be careful, though, because her help always serves her own ends first.",
		"francese": "Kalessi était la femme de Rigon : emprisonnée dans les cachots, elle a été transformée en méduse. Elle erre dans les souterrains, qu'elle connaît mieux que personne. Hostile et méprisante, elle t'aide pourtant avec des indications et des avertissements ; méfie-toi, car son aide sert toujours d'abord ses propres fins.",
		"spagnolo": "Kalessi era la esposa de Rigon: encerrada en las mazmorras, fue convertida en medusa. Vaga por los subterráneos, que conoce mejor que nadie. Es hostil y despectiva, pero te ayuda con indicaciones y advertencias; ten cuidado, porque su ayuda siempre sirve primero a sus propios fines.",
		"tedesco": "Kalessi war Rigons Frau: In den Verliesen eingesperrt, wurde sie in eine Medusa verwandelt. Sie streift durch das Untergeschoss, das sie besser kennt als jeder andere. Sie ist feindselig und verächtlich, hilft dir aber mit Wegweisungen und Warnungen; sei trotzdem vorsichtig, denn ihre Hilfe dient immer zuerst ihren eigenen Zielen.",
	},
	{
		"id": "allemar", "peso": 1.0,
		"chiavi": ["unico umano", "only human", "seul humain", "unico humano", "einzige mensch", "magia", "=magic", "=magie", "hechiz", "allemar", "=mago", "=wizard", "magician", "=mage", "magier", "zauber", "hechicer", "sorcier"],
		"italiano": "Allemar è l'unico umano del castello: è venuto per contattare gli spiriti e ne è diventato amico. Maestro di magia, pozioni e armi, conosce la storia e il valore di ogni oggetto. Diffidente e pieno di pregiudizi, aiuta chi si mostra ragionevole e aperto. Si trova nella Sala delle Stelle, al primo piano; è lui ad aver imprigionato Rigon.",
		"inglese": "Allemar is the only human in the castle: he came to contact the spirits and became their friend. A master of magic, potions and weapons, he knows the history and value of every object. Defensive and prejudiced, he helps those who show reason and an open mind. He is in the Stars Hall on the first floor; he is the one who imprisoned Rigon.",
		"francese": "Allemar est le seul humain du château : il est venu contacter les esprits et est devenu leur ami. Maître de la magie, des potions et des armes, il connaît l'histoire et la valeur de chaque objet. Méfiant et plein de préjugés, il aide ceux qui se montrent raisonnables et ouverts. Il se trouve dans la Salle des Étoiles, au premier étage ; c'est lui qui a emprisonné Rigon.",
		"spagnolo": "Allemar es el único humano del castillo: vino a contactar con los espíritus y se hizo su amigo. Maestro de la magia, las pociones y las armas, conoce la historia y el valor de cada objeto. Desconfiado y lleno de prejuicios, ayuda a quien se muestra razonable y abierto. Está en la Sala de las Estrellas, en el primer piso; fue él quien encerró a Rigon.",
		"tedesco": "Allemar ist der einzige Mensch in der Burg: Er kam, um mit den Geistern in Kontakt zu treten, und wurde ihr Freund. Als Meister der Magie, der Tränke und der Waffen kennt er Geschichte und Wert jedes Gegenstands. Misstrauisch und voller Vorurteile hilft er denen, die Vernunft und Offenheit zeigen. Er ist im Sternensaal im ersten Stock; er hat Rigon eingesperrt.",
	},
	{
		"id": "orchi", "peso": 1.0,
		"chiavi": ["brut", "=capo", "chief", "=chef", "=jefe", "anfuhrer", "hauptling", "gruko", "=orc", "=orcs", "=orco", "=orchi", "orque", "=ork", "=orks", "ogre", "=orcos", "orkhohl"],
		"italiano": "Gruko è il temibile capo degli orchi: grosso, brutale, rispetta solo la forza. Lui e i suoi orchi occupano il Covo degli Orchi, subito dopo l'ingresso nell'ala sud. Gli orchi parlano a grugniti, non sanno nulla di segreti e ti attaccano: combattili o evitali.",
		"inglese": "Gruko is the fearsome chief of the orcs: big, brutal, respecting only strength. He and his orcs hold the Orc Den, right after the entrance in the south wing. Orcs speak in grunts, know nothing about secrets and will attack you: fight them or avoid them.",
		"francese": "Gruko est le redoutable chef des orques : grand, brutal, il ne respecte que la force. Lui et ses orques occupent le Repaire des Orques, juste après l'entrée dans l'aile sud. Les orques parlent par grognements, ne savent rien des secrets et t'attaquent : combats-les ou évite-les.",
		"spagnolo": "Gruko es el temible jefe de los orcos: grande, brutal, solo respeta la fuerza. Él y sus orcos ocupan la Guarida de los Orcos, justo después de la entrada en el ala sur. Los orcos hablan con gruñidos, no saben nada de secretos y te atacan: lucha contra ellos o evítalos.",
		"tedesco": "Gruko ist der gefürchtete Anführer der Orks: groß, brutal, er respektiert nur Stärke. Er und seine Orks halten die Orkhöhle direkt hinter dem Eingang im Südflügel. Orks sprechen in Grunzlauten, wissen nichts von Geheimnissen und greifen dich an: Kämpfe gegen sie oder weiche ihnen aus.",
	},
	{
		"id": "obiettivo", "peso": 1.0,
		"chiavi": ["senso del gioco", "point of the game", "sens du jeu", "sentido del juego", "sinn des spiels", "come finisce", "how does it end", "comment ca finit", "como termina", "wie endet", "obiettiv", "=scopo", "=goal", "=goals", "objectif", "objetivo", "=ziel", "=ziele",
			"vincer", "=win", "winning", "gagner", "ganar", "gewinn", "come si vince", "how to win", "how do i win",
			"=finale", "=finali", "=ending", "endings", "fine del gioco", "final del juego", "fin du jeu",
			"=aim", "purpose", "but du jeu", "=uscire", "=escape", "=exit", "sortir", "echapper", "escapar",
			"=salir", "=flucht", "entkommen", "uscita", "uscir", "=esco", "=esci", "ausgang", "salida", "=sortie"],
		"italiano": "Il tuo obiettivo è uscire vivo dal castello: esploralo, supera le porte chiuse e trova una via d'uscita. Lungo la strada conta come tratti gli spiriti: il tuo comportamento decide quale delle tre strade percorri (egoista, redenzione o aiuto) e quanto ti riveleranno.",
		"inglese": "Your goal is to get out of the castle alive: explore it, get past the locked doors and find a way out. Along the way, how you treat the spirits matters: your behaviour decides which of the three paths you walk (egoistic, redemption or helping) and how much they will reveal to you.",
		"francese": "Ton objectif est de sortir vivant du château : explore-le, franchis les portes verrouillées et trouve une issue. En chemin, ta façon de traiter les esprits compte : ton comportement décide lequel des trois chemins tu suis (égoïste, rédemption ou aide) et ce qu'ils te révéleront.",
		"spagnolo": "Tu objetivo es salir vivo del castillo: explóralo, supera las puertas cerradas y encuentra una salida. Por el camino importa cómo tratas a los espíritus: tu comportamiento decide cuál de los tres caminos recorres (egoísta, redención o ayuda) y cuánto te revelarán.",
		"tedesco": "Dein Ziel ist es, lebend aus der Burg zu entkommen: Erkunde sie, überwinde die verschlossenen Türen und finde einen Ausgang. Unterwegs zählt, wie du die Geister behandelst: Dein Verhalten entscheidet, welchen der drei Wege du gehst (egoistisch, Erlösung oder Hilfe) und wie viel sie dir verraten.",
	},
	{
		"id": "percorsi", "peso": 1.0,
		"chiavi": ["percors", "=strada", "=strade", "=path", "=paths", "chemin", "=camino", "=caminos",
			"=weg", "=wege", "egois", "redenz", "redempt", "redemption", "redencion", "erlosung", "scelt",
			"choice", "choix", "eleccion", "entscheid", "comportament", "behavio", "comport", "=morale",
			"=morality", "karma", "tre vie", "three ways", "tre strade", "three paths"],
		"italiano": "Ci sono tre strade, e gli spiriti ti giudicano dalle azioni, non dalle parole. Egoista: distruggi, uccidi, scappi; gli spiriti diventano più ostili e non rivelano nulla. Redenzione: ti mostri un umano decente senza aiutare davvero; ti tollerano e accennano ai segreti. Aiuto: aiuti davvero gli spiriti; si aprono, rivelano i segreti e ti offrono alleanza.",
		"inglese": "There are three paths, and the spirits judge you by your deeds, not your words. Egoistic: destroy, kill, escape; the spirits grow more hostile and reveal nothing. Redemption: show you are a decent human without truly helping; they tolerate you and hint at secrets. Helping: truly help the spirits; they open up, reveal their secrets and offer an alliance.",
		"francese": "Il y a trois chemins, et les esprits te jugent sur tes actes, pas sur tes paroles. Égoïste : détruire, tuer, fuir ; les esprits deviennent plus hostiles et ne révèlent rien. Rédemption : te montrer humain et correct sans vraiment aider ; ils te tolèrent et évoquent leurs secrets. Aide : aider vraiment les esprits ; ils s'ouvrent, révèlent leurs secrets et t'offrent leur alliance.",
		"spagnolo": "Hay tres caminos, y los espíritus te juzgan por tus actos, no por tus palabras. Egoísta: destruir, matar, huir; los espíritus se vuelven más hostiles y no revelan nada. Redención: mostrarte como un humano decente sin ayudar de verdad; te toleran e insinúan sus secretos. Ayuda: ayudar de verdad a los espíritus; se abren, revelan sus secretos y te ofrecen su alianza.",
		"tedesco": "Es gibt drei Wege, und die Geister beurteilen dich nach deinen Taten, nicht nach deinen Worten. Egoistisch: zerstören, töten, fliehen; die Geister werden feindseliger und verraten nichts. Erlösung: dich als anständiger Mensch zeigen, ohne wirklich zu helfen; sie dulden dich und deuten Geheimnisse an. Hilfe: den Geistern wirklich helfen; sie öffnen sich, verraten ihre Geheimnisse und bieten dir ein Bündnis an.",
	},
	{
		"id": "missioni", "peso": 1.0,
		"chiavi": ["mission", "mision", "=quest", "=quests", "compit", "=task", "=tasks", "incaric", "=tache",
			"=taches", "=tarea", "=tareas", "aufgab", "richiest", "request", "cosa vogliono", "what do they want",
			"que veulent", "que quieren", "was wollen"],
		"italiano": "Alcuni spiriti ti chiederanno qualcosa. Levias vuole la morte di Rigon; Kalessi e Rigon vogliono ritrovarsi; Allemar cerca la falce di Malakai, il sangue di Rigon, un dente d'orco e qualcuno che suoni lo spartito sull'organo; Larry ti sfida a finire il gioco senza parare, a uscire dal castello, a portargli la mappa e a morire cinque volte. Anche sconfiggere Malakai è una missione.",
		"inglese": "Some spirits will ask something of you. Levias wants Rigon dead; Kalessi and Rigon want to be reunited; Allemar seeks Malakai's scythe, Rigon's blood, an orc tooth and someone to play the sheet music on the organ; Larry dares you to finish the game without parrying, leave the castle, bring him the map and die five times. Defeating Malakai is a quest too.",
		"francese": "Certains esprits te demanderont quelque chose. Levias veut la mort de Rigon ; Kalessi et Rigon veulent se retrouver ; Allemar cherche la faux de Malakai, le sang de Rigon, une dent d'orque et quelqu'un pour jouer la partition à l'orgue ; Larry te défie de finir le jeu sans parer, de sortir du château, de lui rapporter la carte et de mourir cinq fois. Vaincre Malakai est aussi une quête.",
		"spagnolo": "Algunos espíritus te pedirán algo. Levias quiere a Rigon muerto; Kalessi y Rigon quieren reencontrarse; Allemar busca la guadaña de Malakai, la sangre de Rigon, un diente de orco y alguien que toque la partitura en el órgano; Larry te reta a terminar el juego sin bloquear, salir del castillo, llevarle el mapa y morir cinco veces. Derrotar a Malakai también es una misión.",
		"tedesco": "Manche Geister werden etwas von dir verlangen. Levias will Rigons Tod; Kalessi und Rigon wollen wieder zusammenfinden; Allemar sucht Malakais Sense, Rigons Blut, einen Orkzahn und jemanden, der die Noten auf der Orgel spielt; Larry fordert dich heraus, das Spiel ohne Parieren zu beenden, die Burg zu verlassen, ihm die Karte zu bringen und fünfmal zu sterben. Auch Malakai zu besiegen ist eine Aufgabe.",
	},
	{
		"id": "cosa_fare", "peso": 1.0,
		"chiavi": ["dove vado", "dove devo andare", "where should i go", "where do i go", "ou dois je aller", "ou aller", "adonde", "a donde", "wohin", "sono perso", "mi sono perso", "=lost", "=perdu", "=perdido", "verlaufen", "next step", "prossimo passo", "cosa devo fare", "cosa faccio", "cosa fare", "che devo fare", "come inizio", "come comincio",
			"da dove", "primi passi", "what do i do", "what should i do", "what to do", "how do i start",
			"how to start", "where do i start", "where to start", "first steps", "que dois je faire", "que faire",
			"par ou commencer", "comment commencer", "que hago", "que debo hacer", "como empiezo", "por donde",
			"was soll ich", "was muss ich", "wie fange", "wo fange", "consigl", "suggeriment", "=tip", "=tips",
			"=hint", "=hints", "astuce", "conseil", "consejo", "=tipp", "tipps", "hinweis", "bloccat", "=stuck",
			"coince", "atascad", "feststeck", "=aiutami", "inizi", "comincia", "=begin", "commenc", "empez",
			"anfang", "beginn"],
		"italiano": "Parti dall'ingresso: parla con Levias, che è lì, e mostrati rispettoso. Per passare la prima porta risolvi il suo indovinello scrivendo la risposta (Levias la conosce, e te la dice se si fida di te) oppure supera il suo minigioco. Poi esplora, raccogli pozioni, chiavi e pergamene, combatti o evita gli orchi e parla con gli spiriti. Se una porta ti blocca, una pergamena la apre.",
		"inglese": "Start at the entrance: talk to Levias, who is right there, and be respectful. To get through the first door, solve its riddle by typing the answer (Levias knows it and tells you if he trusts you) or beat its minigame. Then explore, collect potions, keys and scrolls, fight or avoid the orcs and talk to the spirits. If a door blocks you, a scroll opens it.",
		"francese": "Commence à l'entrée : parle à Levias, qui s'y trouve, et montre-toi respectueux. Pour franchir la première porte, résous son énigme en écrivant la réponse (Levias la connaît et te la dira s'il te fait confiance) ou réussis son mini-jeu. Ensuite explore, ramasse potions, clés et parchemins, combats ou évite les orques et parle aux esprits. Si une porte te bloque, un parchemin l'ouvre.",
		"spagnolo": "Empieza en la entrada: habla con Levias, que está allí, y muéstrate respetuoso. Para cruzar la primera puerta, resuelve su acertijo escribiendo la respuesta (Levias la conoce y te la dirá si confía en ti) o supera su minijuego. Después explora, recoge pociones, llaves y pergaminos, lucha contra los orcos o evítalos y habla con los espíritus. Si una puerta te bloquea, un pergamino la abre.",
		"tedesco": "Beginne am Eingang: Sprich mit Levias, der dort steht, und sei respektvoll. Um durch die erste Tür zu kommen, löse ihr Rätsel, indem du die Antwort schreibst (Levias kennt sie und verrät sie dir, wenn er dir vertraut), oder schaffe ihr Minispiel. Dann erkunde, sammle Tränke, Schlüssel und Schriftrollen, kämpfe gegen die Orks oder weiche ihnen aus und sprich mit den Geistern. Hält dich eine Tür auf, öffnet sie eine Schriftrolle.",
	},
	{
		"id": "mappa", "peso": 0.8,
		"chiavi": ["=sotto", "below", "beneath", "sous le", "debajo", "unterhalb", "mappa", "=map", "=maps", "=carte", "=mapa", "=karte", "struttur", "structur", "estructur",
			"=aufbau", "=piani", "=piano", "=floor", "=floors", "etage", "=planta", "=plantas", "stockwerk",
			"stanz", "=room", "=rooms", "=salle", "=salles", "=sala", "=sale", "=raum", "=raume", "zimmer",
			"=ala", "=ali", "=wing", "=wings", "=aile", "=ailes", "flugel", "sotterran", "underground",
			"souterrain", "subterran", "=keller", "untergeschoss", "primo piano", "first floor", "premier etage",
			"primer piso", "erster stock", "ersten stock", "piano terra", "pianterreno", "ground floor",
			"rez de chaussee", "planta baja", "erdgeschoss", "claristorium", "=luoghi", "=places", "=lieux",
			"=lugares", "=orte", "com e fatto", "come e fatto", "layout", "dove si trova", "dove sono",
			"where is", "where are", "ou est", "ou sont", "donde esta", "donde estan", "wo ist", "wo sind",
			"dungeon", "fogne", "sewer", "egout", "cloaca", "kanalisation", "campanil", "bell tower", "clocher",
			"campanario", "glockenturm", "giardin", "garden", "jardin", "garten", "monolit", "monolith", "promontor"],
		"italiano": "Il castello ha tre livelli. Piano terra: l'ala sud (Ingresso, Covo degli Orchi, Sala del Grande Albero, Tana di Malakai) e l'ala nord (Giardino della Grande Luna, Camere d'Acqua, Monolite, Stanza dei Rovi Intrecciati), che dall'ingresso non si raggiunge. Primo piano: il Claristorium con le sale dei Quadri, delle Stelle, della Musica e dei Papiri, il Promontorio e l'Uscita Est. Dall'ingresso, delle scale scendono ai sotterranei.",
		"inglese": "The castle has three levels. Ground floor: the south wing (Entrance, Orc Den, Great Tree Hall, Malakai's Lair) and the north wing (Great Moon Garden, Water Chambers, Monolith, Twisted Brambles Room), which you cannot reach from the entrance. First floor: the Claristorium with the Painting, Stars, Music and Papyrus Halls, the Promontory and the East Exit. From the entrance, stairs lead down to the underground.",
		"francese": "Le château a trois niveaux. Rez-de-chaussée : l'aile sud (Entrée, Repaire des Orques, Salle du Grand Arbre, Antre de Malakai) et l'aile nord (Jardin de la Grande Lune, Chambres d'Eau, Monolithe, Salle des Ronces Entrelacées), inaccessible depuis l'entrée. Premier étage : le Claristorium avec les salles des Tableaux, des Étoiles, de la Musique et des Papyrus, le Promontoire et la Sortie Est. Depuis l'entrée, un escalier descend aux souterrains.",
		"spagnolo": "El castillo tiene tres niveles. Planta baja: el ala sur (Entrada, Guarida de los Orcos, Sala del Gran Árbol, Madriguera de Malakai) y el ala norte (Jardín de la Gran Luna, Cámaras de Agua, Monolito, Sala de las Zarzas Retorcidas), a la que no se llega desde la entrada. Primer piso: el Claristorium con las salas de los Cuadros, las Estrellas, la Música y los Papiros, el Promontorio y la Salida Este. Desde la entrada, unas escaleras bajan a los subterráneos.",
		"tedesco": "Die Burg hat drei Ebenen. Erdgeschoss: der Südflügel (Eingang, Orkhöhle, Saal des Großen Baums, Malakais Unterschlupf) und der Nordflügel (Garten des Großen Mondes, Wasserkammern, Monolith, Raum der verschlungenen Dornen), den du vom Eingang aus nicht erreichst. Erster Stock: das Claristorium mit Gemälde-, Sternen-, Musik- und Papyrussaal, dem Vorgebirge und dem Ostausgang. Vom Eingang führen Treppen hinab ins Untergeschoss.",
	},
	{
		"id": "porte", "peso": 1.0,
		"chiavi": ["=porta", "=porte", "portone", "portoni", "=door", "=doors", "=gate", "=gates", "cancell",
			"indovinel", "riddle", "enigm", "acertij", "ratsel", "=tur", "=turen", "=tor", "=tore", "=puerta",
			"=puertas", "serratur", "=lock", "locked", "verrouill", "cerrad", "verschloss", "chius"],
		"italiano": "Le porte chiuse si aprono in due modi. Indovinello: il testo compare sopra la porta; avvicinati, premi il tasto di dialogo e scrivi la risposta. Minigioco: premi il tasto di dialogo vicino alla porta per iniziare la prova. Una pergamena apre qualsiasi porta: apri l'inventario e usala vicino alla porta.",
		"inglese": "Locked doors open in two ways. Riddle: the text appears above the door; get close, press the talk button and type the answer. Minigame: press the talk button next to the door to start the trial. A scroll opens any door: open your inventory and use it near the door.",
		"francese": "Les portes verrouillées s'ouvrent de deux façons. Énigme : le texte apparaît au-dessus de la porte ; approche-toi, appuie sur la touche de dialogue et écris la réponse. Mini-jeu : appuie sur la touche de dialogue près de la porte pour lancer l'épreuve. Un parchemin ouvre n'importe quelle porte : ouvre l'inventaire et utilise-le près de la porte.",
		"spagnolo": "Las puertas cerradas se abren de dos formas. Acertijo: el texto aparece sobre la puerta; acércate, pulsa el botón de diálogo y escribe la respuesta. Minijuego: pulsa el botón de diálogo junto a la puerta para empezar la prueba. Un pergamino abre cualquier puerta: abre el inventario y úsalo cerca de la puerta.",
		"tedesco": "Verschlossene Türen öffnen sich auf zwei Arten. Rätsel: Der Text erscheint über der Tür; geh näher, drück die Sprechtaste und schreib die Antwort. Minispiel: Drück neben der Tür die Sprechtaste, um die Prüfung zu starten. Eine Schriftrolle öffnet jede Tür: Öffne das Inventar und benutze sie in der Nähe der Tür.",
	},
	{
		"id": "minigiochi", "peso": 1.0,
		"chiavi": ["minigioc", "minigame", "mini game", "mini jeu", "minijueg", "minispiel", "=puzzle",
			"rompicap", "=luce", "=light", "lumiere", "=luz", "=licht", "specch", "mirror", "miroir", "espejo",
			"spiegel", "=prova", "=prove", "=trial", "=trials", "epreuve", "prueba", "=pezzi", "=pieces",
			"=piezas", "raggio", "=beam", "rayon", "=rayo", "=strahl", "chiave nascost", "hidden key",
			"cle cachee", "llave escondida", "versteckten schlussel"],
		"italiano": "Ci sono due minigiochi. Luce: muovi il mouse per orientare la sorgente e fai rimbalzare il raggio sugli specchi fino al bersaglio. Puzzle: trascina i pezzi al loro posto prima che scada il tempo; per completarlo ti serve anche la chiave nascosta nel castello. Con il pulsante di chiusura esci e puoi riprovare più tardi.",
		"inglese": "There are two minigames. Light: move the mouse to aim the source and bounce the beam off the mirrors until it hits the target. Puzzle: drag the pieces into place before time runs out; to complete it you also need the key hidden in the castle. The close button lets you leave and try again later.",
		"francese": "Il y a deux mini-jeux. Lumière : bouge la souris pour orienter la source et fais rebondir le rayon sur les miroirs jusqu'à la cible. Puzzle : fais glisser les pièces à leur place avant la fin du temps ; pour le terminer, il te faut aussi la clé cachée dans le château. Le bouton de fermeture te permet de sortir et de réessayer plus tard.",
		"spagnolo": "Hay dos minijuegos. Luz: mueve el ratón para orientar la fuente y haz rebotar el rayo en los espejos hasta el objetivo. Puzzle: arrastra las piezas a su sitio antes de que se acabe el tiempo; para completarlo también necesitas la llave escondida en el castillo. Con el botón de cerrar sales y puedes volver a intentarlo más tarde.",
		"tedesco": "Es gibt zwei Minispiele. Licht: Bewege die Maus, um die Quelle auszurichten, und lenke den Strahl über die Spiegel ins Ziel. Puzzle: Zieh die Teile an ihren Platz, bevor die Zeit abläuft; zum Abschließen brauchst du außerdem den in der Burg versteckten Schlüssel. Mit der Schließen-Taste verlässt du es und kannst es später erneut versuchen.",
	},
	{
		"id": "comandi", "peso": 0.5,
		"chiavi": ["comand", "command", "control", "=tasto", "=tasti", "keyboard", "tastier", "gamepad", "joystick",
			"joypad", "=pad", "=touche", "=touches", "clavier", "manette", "=mando", "teclad", "=tecla",
			"=teclas", "steuer", "tastatur", "=taste", "=tasten", "come si gioca", "how to play", "how do i play",
			"comment jouer", "como se juega", "como jugar", "wie spielt", "wie spiele", "=mouse", "souris",
			"=raton", "=maus", "=touch", "=mobile", "telefon", "smartphone", "=phone", "tablet", "cellular"],
		"italiano": "Tastiera: A/D o frecce per muoverti, Shift per correre, Spazio/W per saltare (ripremi in aria per il doppio salto), doppio tocco di A/D per scivolare, Ctrl per accovacciarti, W/S per arrampicarti, E attacca, Q para, il tasto sotto Esc (\\) apre e chiude il dialogo, Invio invia, 1 apre l'inventario, Esc mette in pausa. Gamepad: A salta, Y attacca, X para, B dialogo, LB corre, Select inventario, Start pausa. Su telefono: tieni premuto un lato per camminare, tap per attaccare, swipe in su per saltare.",
		"inglese": "Keyboard: A/D or arrows to move, Shift to run, Space/W to jump (press again in mid-air for a double jump), double-tap A/D to slide, Ctrl to crouch, W/S to climb, E attacks, Q parries, the key under Esc (`) opens and closes the dialogue, Enter sends, 1 opens the inventory, Esc pauses. Gamepad: A jump, Y attack, X parry, B talk, LB run, Select inventory, Start pause. On phones: hold one side to walk, tap to attack, swipe up to jump.",
		"francese": "Clavier : Q/D ou flèches pour bouger, Maj pour courir, Espace/Z pour sauter (rappuie en l'air pour un double saut), double appui sur Q/D pour glisser, Ctrl pour t'accroupir, Z/S pour grimper, E attaque, A pare, la touche sous Échap (²) ouvre et ferme le dialogue, Entrée envoie, la touche 1 (&) ouvre l'inventaire, Échap met en pause. Manette : A saut, Y attaque, X parade, B dialogue, LB course, Select inventaire, Start pause. Sur téléphone : maintiens un côté pour marcher, touche pour attaquer, glisse vers le haut pour sauter.",
		"spagnolo": "Teclado: A/D o flechas para moverte, Mayús para correr, Espacio/W para saltar (vuelve a pulsar en el aire para un doble salto), doble toque en A/D para deslizarte, Ctrl para agacharte, W/S para trepar, E ataca, Q bloquea, la tecla bajo Esc (º) abre y cierra el diálogo, Intro envía, 1 abre el inventario, Esc pausa. Mando: A salta, Y ataca, X bloquea, B diálogo, LB corre, Select inventario, Start pausa. En el móvil: mantén pulsado un lado para caminar, toca para atacar, desliza hacia arriba para saltar.",
		"tedesco": "Tastatur: A/D oder Pfeiltasten zum Bewegen, Umschalt zum Rennen, Leertaste/W zum Springen (in der Luft erneut drücken für einen Doppelsprung), zweimal A/D tippen zum Rutschen, Strg zum Ducken, W/S zum Klettern, E greift an, Q pariert, die Taste unter Esc (^) öffnet und schließt den Dialog, Enter sendet, 1 öffnet das Inventar, Esc pausiert. Gamepad: A Sprung, Y Angriff, X Parade, B Dialog, LB Rennen, Select Inventar, Start Pause. Am Handy: eine Seite gedrückt halten zum Gehen, tippen zum Angreifen, nach oben wischen zum Springen.",
	},
	{
		"id": "movimento", "peso": 1.0,
		"chiavi": ["stair", "escalier", "treppe", "scender", "go down", "go up", "salire", "monter", "descendre", "=subir", "=bajar", "hinauf", "hinunter", "veloc", "faster", "=fast", "rapid", "schnell", "higher", "piu in alto", "plus haut", "mas alto", "hoher", "muov", "mover", "=move", "=moving", "bouger", "deplac", "beweg", "cammin", "=walk", "walking",
			"marcher", "=caminar", "=laufen", "=gehen", "correr", "=corro", "=corri", "=corsa", "=run", "=running",
			"courir", "sprint", "=rennen", "scivol", "=slide", "sliding", "gliss", "desliz", "rutsch",
			"accovacc", "abbass", "crouch", "accroup", "agach", "=duck", "ducken", "hocke", "arrampic", "=climb",
			"climbing", "=scale", "=scala", "scalare", "ladder", "grimp", "echelle", "trepa", "escaler",
			"kletter", "leiter", "liana", "liane", "=vine", "=vines", "salt", "=jump", "jumping", "jumps",
			"=saut", "sauter", "sprung", "springen", "doppio salto", "double jump", "=muro", "=wall", "=mur",
			"=pared", "=wand", "wall jump"],
		"italiano": "Muoviti con A/D o le frecce (stick sinistro) e tieni Shift (LB) per correre. Salta con Spazio o W (A sul gamepad) e ripremi in aria per il doppio salto; se salti mentre sei contro un muro, fai un salto dal muro. Tocca due volte A o D per scivolare, premi Ctrl (L3) per accovacciarti o rialzarti e usa W/S per salire e scendere da scale e liane.",
		"inglese": "Move with A/D or the arrows (left stick) and hold Shift (LB) to run. Jump with Space or W (A on gamepad) and press again in mid-air for a double jump; jumping while against a wall gives a wall jump. Double-tap A or D to slide, press Ctrl (L3) to crouch or stand up, and use W/S to climb up and down stairs and vines.",
		"francese": "Déplace-toi avec Q/D ou les flèches (stick gauche) et maintiens Maj (LB) pour courir. Saute avec Espace ou Z (A à la manette) et rappuie en l'air pour un double saut ; si tu sautes contre un mur, tu fais un saut mural. Appuie deux fois sur Q ou D pour glisser, sur Ctrl (L3) pour t'accroupir ou te relever, et utilise Z/S pour monter et descendre escaliers et lianes.",
		"spagnolo": "Muévete con A/D o las flechas (stick izquierdo) y mantén Mayús (LB) para correr. Salta con Espacio o W (A en el mando) y vuelve a pulsar en el aire para un doble salto; si saltas pegado a una pared, haces un salto de pared. Toca dos veces A o D para deslizarte, pulsa Ctrl (L3) para agacharte o levantarte y usa W/S para subir y bajar escaleras y lianas.",
		"tedesco": "Beweg dich mit A/D oder den Pfeiltasten (linker Stick) und halte Umschalt (LB) zum Rennen. Spring mit Leertaste oder W (A am Gamepad) und drück in der Luft erneut für einen Doppelsprung; springst du an einer Wand, machst du einen Wandsprung. Tippe zweimal A oder D zum Rutschen, drück Strg (L3) zum Ducken oder Aufstehen und nutze W/S, um Treppen und Lianen hinauf- und hinabzuklettern.",
	},
	{
		"id": "combattimento", "peso": 1.0,
		"chiavi": ["greif", "kampfe", "difend", "defend", "protegg", "protect", "protege", "schutz", "schutze", "combatt", "attac", "=fight", "fighting", "attack", "=combat", "combattr", "attaqu", "pelea",
			"ataca", "=kampf", "kampfen", "angreif", "=parry", "parrying", "=parare", "=parata", "=paro", "parar",
			"=parade", "=parer", "parier", "=block", "blocking", "bloquear", "blocc", "=spada", "=sword", "=epee",
			"=espada", "schwert", "nemic", "=enemy", "enemies", "ennemi", "enemig", "=feind", "=feinde",
			"=colpo", "=colpi", "colpire", "=hit", "=hits", "frapp", "golpe", "golpear", "schlag", "uccid",
			"=kill", "killing", "=tuer", "=matar", "toten", "scheletr", "skelet", "squelet", "esquelet",
			"=mostro", "=mostri", "monster", "monstre", "monstruo", "danno", "damage", "degat", "schaden", "=boss"],
		"italiano": "Attacca con E (Y sul gamepad) e para con Q (X): una parata al momento giusto blocca il colpo. Orchi, scheletri e altre creature ti attaccano; la barra rossa in basso a sinistra è la tua salute. Anche gli spiriti si possono colpire, ma ogni colpo li rende più ostili e li fa reagire: la violenza ti porta sulla strada egoista.",
		"inglese": "Attack with E (Y on gamepad) and parry with Q (X): a well-timed parry blocks the blow. Orcs, skeletons and other creatures will attack you; the red bar at the bottom left is your health. You can hit the spirits too, but every blow makes them more hostile and makes them strike back: violence leads you down the egoistic path.",
		"francese": "Attaque avec E (Y à la manette) et pare avec A (X) : une parade au bon moment bloque le coup. Orques, squelettes et autres créatures t'attaquent ; la barre rouge en bas à gauche est ta santé. Tu peux aussi frapper les esprits, mais chaque coup les rend plus hostiles et les fait riposter : la violence te mène sur le chemin égoïste.",
		"spagnolo": "Ataca con E (Y en el mando) y bloquea con Q (X): un bloqueo en el momento justo detiene el golpe. Orcos, esqueletos y otras criaturas te atacarán; la barra roja abajo a la izquierda es tu salud. También puedes golpear a los espíritus, pero cada golpe los vuelve más hostiles y hace que respondan: la violencia te lleva por el camino egoísta.",
		"tedesco": "Greif mit E an (Y am Gamepad) und pariere mit Q (X): Eine gut getimte Parade blockt den Schlag. Orks, Skelette und andere Kreaturen greifen dich an; der rote Balken unten links ist deine Gesundheit. Du kannst auch die Geister schlagen, aber jeder Treffer macht sie feindseliger und lässt sie zurückschlagen: Gewalt führt dich auf den egoistischen Weg.",
	},
	{
		"id": "dialogo", "peso": 1.0,
		"chiavi": ["=parlo", "parlare", "parla con", "parlarci", "parlargli", "parlarle", "parler", "=rede", "reden", "unterhalt", "farmi aiutare", "mi aiutino", "their help", "leur aide", "su ayuda", "ihre hilfe", "=talk", "talking", "=speak", "dialog", "convers", "=chat", "scriv", "=write", "=type",
			"ecrir", "escrib", "schreib", "sprech", "habl", "parler", "interag", "interact",
			"fiducia", "=trust", "confianc", "vertrau", "amicizi", "friend", "amiti", "amistad", "freund",
			"ostil", "hostil", "feindselig", "segret", "secret", "=secreto", "secretos", "geheim", "rivel",
			"reveal", "revel", "enthull", "convinc", "persuad", "alleat", "=ally", "allies", "allie", "aliado",
			"verbundet"],
		"italiano": "Avvicinati a uno spirito finché compare Interact, premi il tasto sotto Esc (B sul gamepad o il pulsante a schermo), scrivi la frase e premi Invio; ripremi lo stesso tasto per chiudere. Rispetto, interesse per la cultura, scuse e offerte d'aiuto abbassano la loro ostilità; minacce, violenza e bugie la alzano. Solo chi si fida di te ti rivela i segreti.",
		"inglese": "Walk up to a spirit until Interact appears, press the key under Esc (B on gamepad, or the on-screen button), type your line and press Enter; press the same key again to close. Respect, interest in culture, apologies and offers of help lower their hostility; threats, violence and lies raise it. Only those who trust you reveal their secrets.",
		"francese": "Approche-toi d'un esprit jusqu'à voir Interact, appuie sur la touche sous Échap (B à la manette, ou le bouton à l'écran), écris ta phrase et appuie sur Entrée ; rappuie sur la même touche pour fermer. Le respect, l'intérêt pour la culture, les excuses et les offres d'aide baissent leur hostilité ; menaces, violence et mensonges l'augmentent. Seuls ceux qui te font confiance révèlent leurs secrets.",
		"spagnolo": "Acércate a un espíritu hasta que aparezca Interact, pulsa la tecla bajo Esc (B en el mando o el botón en pantalla), escribe tu frase y pulsa Intro; vuelve a pulsar la misma tecla para cerrar. El respeto, el interés por la cultura, las disculpas y las ofertas de ayuda reducen su hostilidad; las amenazas, la violencia y las mentiras la aumentan. Solo quien confía en ti te revela sus secretos.",
		"tedesco": "Geh zu einem Geist, bis Interact erscheint, drück die Taste unter Esc (B am Gamepad oder die Schaltfläche am Bildschirm), schreib deinen Satz und drück Enter; drück dieselbe Taste erneut zum Schließen. Respekt, Interesse an Kultur, Entschuldigungen und Hilfsangebote senken ihre Feindseligkeit; Drohungen, Gewalt und Lügen erhöhen sie. Nur wer dir vertraut, verrät dir seine Geheimnisse.",
	},
	{
		"id": "inventario", "peso": 1.0,
		"chiavi": ["inventar", "inventory", "inventair", "oggett", "=item", "=items", "=objet", "=objets",
			"=objeto", "=objetos", "gegenstand", "gegenstande", "pozion", "potion", "pocion", "=trank", "=tranke",
			"heiltrank", "=olio", "=oil", "=huile", "aceite", "=ol", "chiave", "=key", "=keys", "=clef", "=cle",
			"=llave", "schlussel", "pergamen", "=scroll", "=scrolls", "parchemin", "pergamino", "schriftroll",
			"=usare", "=uso", "=use", "=using", "utilis", "=usar", "benutz", "raccogl", "pick up", "ramass",
			"recog", "aufheb", "=zaino", "=bag"],
		"italiano": "Apri l'inventario con 1 (Select sul gamepad): tocca un oggetto per selezionarlo, poi tocca quello al centro per usarlo. Pozione: ti ridà tutta la salute. Olio di difesa: aumenta la difesa. Chiave: serve a completare il puzzle. Pergamena: apre qualsiasi porta, se la usi vicino alla porta. Gli oggetti si raccolgono passandoci sopra.",
		"inglese": "Open the inventory with 1 (Select on gamepad): tap an item to select it, then tap the one in the centre to use it. Potion: restores all your health. Defense oil: boosts your defense. Key: needed to complete the puzzle. Scroll: opens any door when used near it. You pick up items by walking over them.",
		"francese": "Ouvre l'inventaire avec la touche 1 (&) (Select à la manette) : touche un objet pour le sélectionner, puis celui du centre pour l'utiliser. Potion : rend toute ta santé. Huile de défense : augmente ta défense. Clé : nécessaire pour terminer le puzzle. Parchemin : ouvre n'importe quelle porte si tu l'utilises à côté. On ramasse les objets en passant dessus.",
		"spagnolo": "Abre el inventario con 1 (Select en el mando): toca un objeto para seleccionarlo y luego el del centro para usarlo. Poción: te devuelve toda la salud. Aceite de defensa: aumenta tu defensa. Llave: necesaria para completar el puzzle. Pergamino: abre cualquier puerta si lo usas junto a ella. Los objetos se recogen pasando por encima.",
		"tedesco": "Öffne das Inventar mit 1 (Select am Gamepad): Tippe einen Gegenstand an, um ihn auszuwählen, dann den in der Mitte, um ihn zu benutzen. Trank: stellt deine ganze Gesundheit wieder her. Verteidigungsöl: stärkt deine Verteidigung. Schlüssel: nötig, um das Puzzle abzuschließen. Schriftrolle: öffnet jede Tür, wenn du sie daneben benutzt. Gegenstände sammelst du ein, indem du darüber läufst.",
	},
	{
		"id": "salute", "peso": 1.0,
		"chiavi": ["=salute", "=health", "=hp", "=sante", "=salud", "gesundheit", "=vita", "=vite", "=life",
			"=lives", "=vie", "=vida", "=leben", "=morte", "=morire", "=muoio", "=muori", "=morto", "i die",
			"you die", "=died", "=dying", "=death", "=dead", "mourir", "=mort", "=meurs", "morir", "=muero", "sterb",
			"=tod", "=tot", "game over", "sconfitt", "defeat", "defait", "derrota", "niederlag", "=cura", "=curo", "=curi",
			"curarmi", "curar", "=heal", "healing", "soign", "=heil", "heilen", "ricomin", "restart", "recommenc",
			"reinici", "neustart", "neu starten", "salvatagg", "salvare", "=save", "saving", "sauvegard",
			"=guardar", "guardado", "speicher", "checkpoint", "barra rossa", "red bar"],
		"italiano": "La barra rossa in basso a sinistra è la tua salute: i colpi nemici la consumano e le pozioni la ricaricano. Alcune trappole uccidono all'istante. Se muori compare la schermata di sconfitta, e il suo pulsante fa ricominciare la partita dall'inizio: non ci sono salvataggi.",
		"inglese": "The red bar at the bottom left is your health: enemy blows drain it and potions refill it. Some traps kill instantly. If you die, the defeat screen appears and its button restarts the game from the beginning: there are no saves.",
		"francese": "La barre rouge en bas à gauche est ta santé : les coups ennemis la vident et les potions la remplissent. Certains pièges tuent sur le coup. Si tu meurs, l'écran de défaite apparaît et son bouton relance la partie depuis le début : il n'y a pas de sauvegarde.",
		"spagnolo": "La barra roja abajo a la izquierda es tu salud: los golpes enemigos la gastan y las pociones la rellenan. Algunas trampas matan al instante. Si mueres aparece la pantalla de derrota, y su botón reinicia la partida desde el principio: no hay guardado.",
		"tedesco": "Der rote Balken unten links ist deine Gesundheit: Feindliche Treffer leeren ihn, Tränke füllen ihn wieder auf. Manche Fallen töten sofort. Wenn du stirbst, erscheint der Niederlagebildschirm, und seine Schaltfläche startet das Spiel von vorn: Es gibt keine Speicherstände.",
	},
	{
		"id": "opzioni", "peso": 1.0,
		"chiavi": ["=pausa", "=pause", "opzion", "option", "opcion", "einstellung", "volum", "=audio", "=suono",
			"=suoni", "=sound", "=sounds", "=sons", "sonore", "sonido", "lautstark", "=musica", "=music", "musique",
			"=musik", "lingua", "language", "langue", "idioma", "sprache", "tradu", "translat", "=italiano",
			"=english", "=ingles", "=inglese", "=francese", "=spagnolo", "=tedesco", "=esc", "impostazion",
			"settings", "parametr", "ajustes", "configura"],
		"italiano": "Premi Esc (Start sul gamepad) o il pulsante di pausa per aprire le opzioni, dove regoli il volume della musica e degli effetti. La lingua in cui parlano gli spiriti si sceglie dalla tendina in alto a destra nel menu: EN, IT, FR, ES o DE.",
		"inglese": "Press Esc (Start on gamepad) or the pause button to open the options, where you set the music and effects volume. The language the spirits speak is chosen from the drop-down at the top right of the menu: EN, IT, FR, ES or DE.",
		"francese": "Appuie sur Échap (Start à la manette) ou sur le bouton pause pour ouvrir les options, où tu règles le volume de la musique et des effets. La langue des esprits se choisit dans la liste en haut à droite du menu : EN, IT, FR, ES ou DE.",
		"spagnolo": "Pulsa Esc (Start en el mando) o el botón de pausa para abrir las opciones, donde ajustas el volumen de la música y de los efectos. El idioma en que hablan los espíritus se elige en el desplegable arriba a la derecha del menú: EN, IT, FR, ES o DE.",
		"tedesco": "Drück Esc (Start am Gamepad) oder die Pausentaste, um die Optionen zu öffnen, wo du die Lautstärke von Musik und Effekten einstellst. Die Sprache der Geister wählst du in der Liste oben rechts im Hauptmenü: EN, IT, FR, ES oder DE.",
	},
]

## Quando nessuna scheda corrisponde alla domanda.
const NON_SO := {
	"italiano": "Su questo non ho una risposta certa. Chiedimi della storia, degli spiriti, dei comandi, dell'obiettivo, della mappa, delle porte o di cosa fare per iniziare.",
	"inglese": "I don't have a sure answer to that. Ask me about the story, the spirits, the controls, your goal, the map, the doors or what to do first.",
	"francese": "Je n'ai pas de réponse sûre à cela. Demande-moi l'histoire, les esprits, les commandes, ton objectif, le plan, les portes ou par où commencer.",
	"spagnolo": "No tengo una respuesta segura a eso. Pregúntame por la historia, los espíritus, los controles, tu objetivo, el mapa, las puertas o qué hacer primero.",
	"tedesco": "Darauf habe ich keine sichere Antwort. Frag mich nach der Geschichte, den Geistern, der Steuerung, deinem Ziel, der Karte, den Türen oder womit du anfangen sollst.",
}

## Al massimo quante schede unire in una risposta, quando la domanda ne tocca
## piu' d'una con lo stesso punteggio ("come salto e come attacco?").
const MAX_SCHEDE := 2
# --- schede ---------------------------------------------------------------

## La risposta scritta a mano per la domanda, nella lingua data, oppure "" se
## nessuna scheda la copre (il menu mostra allora non_so()).
static func risposta(domanda: String, lingua: String) -> String:
	var testi := PackedStringArray()
	for id in argomenti(domanda):
		testi.append(_testo(_scheda(id), lingua))
	return " ".join(testi)


## Gli id delle schede che rispondono alla domanda, dal piu' pertinente: una
## sola di solito, fino a MAX_SCHEDE se hanno lo stesso punteggio.
static func argomenti(domanda: String) -> PackedStringArray:
	var testo := normalizza(domanda)
	var out := PackedStringArray()
	if testo.strip_edges().is_empty():
		return out
	var parole := testo.strip_edges().split(" ", false)
	var migliore := 0.0
	var punteggi := []
	for scheda in SCHEDE:
		var trovate := 0
		for chiave in scheda["chiavi"]:
			if _trova(String(chiave), testo, parole):
				trovate += 1
		if trovate > 0:
			var p: float = trovate * float(scheda["peso"])
			punteggi.append([p, String(scheda["id"])])
			migliore = maxf(migliore, p)
	# Ordine stabile: a parita' di punteggio vale l'ordine di SCHEDE.
	for coppia in punteggi:
		if is_equal_approx(float(coppia[0]), migliore) and out.size() < MAX_SCHEDE:
			out.append(String(coppia[1]))
	return out


static func non_so(lingua: String) -> String:
	return String(NON_SO.get(lingua, NON_SO["inglese"]))


## Il messaggio con cui si apre il menu: dice cosa si puo' chiedere.
static func benvenuto(lingua: String) -> String:
	return _testo(_scheda("saluto"), lingua)


## Minuscole, niente accenti, apostrofi e punteggiatura diventano spazi, e uno
## spazio in testa e in coda: cosi' " cosa devo fare" si cerca con contains()
## senza pescare meta' parola.
static func normalizza(t: String) -> String:
	var s := t.to_lower()
	for coppia in [["àáâäãå", "a"], ["èéêë", "e"], ["ìíîï", "i"], ["òóôöõ", "o"], ["ùúûü", "u"],
			["ç", "c"], ["ñ", "n"], ["ý", "y"]]:
		for c in String(coppia[0]):
			s = s.replace(c, coppia[1])
	s = s.replace("ß", "ss").replace("œ", "oe").replace("æ", "ae")
	var out := ""
	for c in s:
		var u := c.unicode_at(0)
		var lettera := (u >= 97 and u <= 122) or (u >= 48 and u <= 57)
		out += c if lettera else " "
	return " " + " ".join(out.split(" ", false)) + " "


static func _trova(chiave: String, testo: String, parole: PackedStringArray) -> bool:
	if chiave.contains(" "):
		return testo.contains(" " + chiave)
	if chiave.begins_with("="):
		return (" " + chiave.substr(1) + " ") in testo
	for p in parole:
		if p.begins_with(chiave):
			return true
	return false


static func _scheda(id: String) -> Dictionary:
	for s in SCHEDE:
		if s["id"] == id:
			return s
	return {}


static func _testo(scheda: Dictionary, lingua: String) -> String:
	return String(scheda.get(lingua, scheda.get("inglese", "")))
