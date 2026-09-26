# Motore di dialogo Oraculus — da Python a GDScript

Il motore di dialogo degli NPC girava in un processo Python separato
(`ai/inference.py` + `ai/ai_server.py`, server HTTP su `localhost:5000`). Ora
vive dentro il gioco, in GDScript. Il codice Python resta nel repo perche'
serve ancora al proxy su Render.

## Cos'e' sparito

- il `venv` creato a runtime e il `pip install` all'avvio;
- `OS.create_process` per lanciare il server;
- il `taskkill` / `fuser -k` sulla porta 5000;
- i 90 secondi di `MAX_STARTUP_WAIT` prima di poter parlare;
- la dipendenza da Python installato sulla macchina del giocatore;
- gli `HTTPClient` aperti a mano dentro un `Thread` in ogni NPC.

## I file

| File | Ruolo |
| --- | --- |
| `oraculus_data.gd` | **Generato.** Costanti: `STORY_CONTEXT`, `NPC_DATA`, `INTENT_KW`, `FALLBACK`, `RIDDLE_FALLBACKS`, `DEFAULT_RIDDLE_THEMES`. |
| `oraculus_logic.gd` | Funzioni pure, porting 1:1 di `inference.py`: `detect_language`, `classify_intent`, `hostility_tier`, `adjust_hostility`, `pulisci`, `build_prompt`, `build_system_msg`, `enforce_army_name`, `parse_riddle_response`. |
| `oraculus_engine.gd` | `NPCDialogueEngine`: memoria per NPC, scelta del backend, fallback, sblocco di Malakai, indovinelli. |
| `oraculus_backend_local.gd` | Inferenza locale via NobodyWho (llama.cpp). Sostituisce `llama_cpp.Llama`. |
| `oraculus_backend_remote.gd` | Inferenza remota via `HTTPRequest`, o via `HTTPClient` quando la risposta arriva in streaming. Sostituisce `InferenceClient.chat_completion`. |
| `tests/remote_check.gd` | Collaudo del proxy su Render visto da GDScript. |
| `tests/stream_check.gd` | Collaudo dello streaming: pulizia parziale, lettura SSE, percorso completo. |
| `tests/persona_check.gd` | Collaudo delle battute in personaggio: filtro, note di regia, modello locale vero. |
| `oraculus_guide.gd` | La guida del menu: schede scritte a mano in 5 lingue su lore, comandi, obiettivi, mappa e cosa fare. Solo GDScript, senza modello. |
| `tests/guide_check.gd` | Collaudo della guida del menu e dei suoni dell'interfaccia. |
| `../AIServerManager.gd` | Facciata sottile. Firma pubblica invariata: `make_request`, `is_server_ready`, `is_using_remote`, `server_started`, `server_failed`. |
| `inference.py`, `ai_server.py` | Restano per il proxy su Render, piu' l'endpoint `POST /v1/chat/completions`. |

`oraculus_data.gd` **non va modificato a mano**: si rigenera da `inference.py` con

```
python3 tools/gen_oraculus_data.py
```

Le stringhe sono emesse come literal GDScript byte-per-byte identici a quelli
Python, e l'ordine delle chiavi dei dizionari e' preservato — conta, perche'
`classify_intent` restituisce il *primo* intent che matcha e `detect_language`
prende il *primo* massimo.

## Verificare che la logica sia identica, non solo simile

```
python3 tools/parity_dump.py                                   # genera i casi
godot --headless --path . res://ai/tests/parity_check.tscn      # confronta
```

`parity_dump.py` importa `inference.py`, genera qualche migliaio di casi
(frasi in 5 lingue × NPC × ostilita'/amicizia × storico × context_vars) e
salva gli output attesi in `ai/tests/parity_cases.json`. La scena Godot
rilegge quel file e confronta stringa per stringa; per i prompt completi, che
contengono i 9 KB di `STORY_CONTEXT`, il confronto e' su lunghezza + sha256.
Esce con codice 0 se tutto combacia, 1 altrimenti.

Stato attuale: **3877/3877 confronti superati**, inclusi 1012 `build_prompt` e
1012 `build_system_msg`. Se `build_prompt` combacia, il modello riceve lo
stesso input di prima.

Il cablaggio (facciata → motore → backend) e' coperto da uno smoke test
separato, che verifica forma delle risposte, accumulo e reset della memoria,
la regola speciale di Rigon, lo sblocco di Malakai e che gli indovinelli
tornino sempre completi anche quando il backend non risponde:

```
godot --headless --path . res://ai/tests/smoke_check.tscn
```

Stato attuale: **33/33 controlli superati**.

Il terzo test e' l'unico che carica davvero il `.gguf` e genera: dimostra che
i nomi di proprieta', metodi e segnali dell'addon sono quelli che
`oraculus_backend_local.gd` si aspetta, che il system prompt viene davvero
sostituito a ogni richiesta e che la catena di sampling viene accettata.

```
ORACULUS_BACKEND=locale godot --headless --path . res://ai/tests/local_check.tscn
```

Stato attuale: **19/19 controlli superati** (~1 minuto su CPU: carica un
modello da 1 GB e fa sette generazioni vere, l'ultima in streaming). Senza addon o senza modello si
dichiara saltato invece di fallire.

Il quarto test e' l'unico che esercita il **proxy su Render da GDScript**:
`probe()`, `chat_completion()` e la catena completa `build_system_msg` → HTTP
→ `pulisci()` / `parse_riddle_response()`. Si costruisce un `OraculusEngine`
suo e lo forza sul ramo remoto, perche' la gara dell'autoload potrebbe
chiuderlo (vedi "Quale ramo: la gara").

```
godot --headless --path . res://ai/tests/remote_check.tscn
```

Stato attuale: **12/12 controlli superati**, incluso il caso italiano (lingua
rilevata, risposta in italiano, nome dell'esercito corretto da
`enforce_army_name`). Senza rete o con il proxy senza inferenza si dichiara
saltato invece di fallire — e in quel caso stampa il `last_error` del proxy,
che e' il posto dove guardare per primo.

Il quinto test copre lo **streaming** (vedi sotto): che il testo mostrato
mentre arriva non faccia mai comparire cio' che `pulisci()` togliera', che
un flusso SSE spezzato a caso — anche a meta' di una lettera accentata — si
ricomponga identico, e il percorso completo contro il proxy.

```
godot --headless --path . res://ai/tests/stream_check.tscn
```

Stato attuale: **20/20** contro un proxy che fa streaming, **18/18** contro
un deploy che non lo fa ancora (verifica che il client ricada sul JSON).

Il sesto test verifica che al giocatore arrivi **il personaggio, non il
modello** (vedi "Battute in personaggio" sotto): il filtro su un corpus di
frasi da assistente e di battute legittime, le note di regia, e il modello
locale vero su istruzioni di regia e domande in italiano, giudicate da un
rilevatore indipendente dal filtro.

```
ORACULUS_BACKEND=locale godot --headless --path . res://ai/tests/persona_check.tscn
```

Stato attuale: **29/29 con il 1B attuale**, compreso il controllo dal vivo, da
quando il turno del giocatore e' una battuta citata (vedi "Battute in
personaggio", punto 4). Prima era 17/18: il controllo dal vivo trovava rifiuti
da assistente.

Il settimo test copre la **guida del menu** (vedi sotto) e i suoni
dell'interfaccia: schede complete nelle cinque lingue e scritte solo con
caratteri del font del menu, 126 domande in cinque lingue riconosciute, 24
riformulate, la risposta piu' lunga che sta nel riquadro senza coprire il campo
di testo, il clic dei pulsanti e il suono d'invio. Non carica il modello.

```
godot --headless --path . res://ai/tests/guide_check.tscn
```

Stato attuale: **27/27 controlli superati**.

L'ottavo test copre la **voce degli NPC** (`oraculus/NPC/voce_sintetica.gd` e
`voce_parlante.gd`): il testo delle caselle compare una lettera alla volta e
ogni lettera si sente con un suono sintetico, come in Animal Crossing, con un
tono per NPC (e per il Tutorial nel menu). Controlla i campioni delle 26
lettere, i profili, la comparsa graduale, il silenzio per azioni fra
asterischi e puntini, lo streaming che prosegue senza ripetere, un NPC vero e
il menu.

```
godot --headless --path . res://ai/tests/voce_check.tscn
```

Stato attuale: **25/25 controlli superati**.

Per controllare che tutti gli script del progetto compilino:

```
python3 tools/check_scripts.py /percorso/di/godot
```

Nota: `--check-only --script` da solo non registra gli autoload, quindi
segnala come errore ogni riferimento a `FeedbackPopup`, `GameState` o
`AIServerManager`. `check_scripts.py` filtra esattamente quel rumore.

## Inferenza locale: NobodyWho

L'addon e' gia' in `addons/nobodywho/` (**v11.0.0**), ma **non e' nel git**:
sono binari da 262 MB, e `.gitignore` li esclude. Su una macchina nuova si
reinstalla da AssetLib (cerca "NobodyWho") oppure scaricando la release:

```
curl -L -o nobodywho.zip \
  https://github.com/nobodywho-ooo/nobodywho/releases/download/nobodywho-godot-v11.0.0/nobodywho-godot-nobodywho-godot-v11.0.0.zip
unzip -j nobodywho.zip 'bin/addons/nobodywho/*' -d addons/nobodywho/
```

Qui dentro ci sono solo i binari **Linux x86_64 e Windows x86_64**: lo zip
della release contiene anche macOS, iOS e Android (arm64), che vanno estratti
a parte se ti servono — la preset di export Android li richiede.

Senza l'addon il progetto compila e gira comunque: il backend locale si
dichiara non disponibile e la gara la vince il remoto. I nomi delle
proprieta' di NobodyWho sono cambiati tra le versioni, quindi
`oraculus_backend_local.gd` accede all'addon per riflessione con una lista di
candidati per ogni proprieta', invece di riferirsi ai tipi per nome.

### Cosa e' cambiato in v11 (verificato, non dedotto)

Sono le tre cose che facevano fallire il ramo locale in silenzio:

- la proprieta' che collega il modello alla chat si chiama **`model_node`**,
  non `model`. Con il nome sbagliato `start_worker()` stampa
  `Model node was not set` e il worker muore, ma niente solleva un errore:
  ora se la proprieta' non esiste `setup()` fallisce e si passa al remoto;
- **`NobodyWhoSampler` non esiste piu'**. La catena di sampling
  (`penalties` → `top_k` → `top_p` → `temperature` → `seed` → `dist`, gli
  stessi valori che `inference.py` passava a `llama_cpp`) si costruisce con
  `NobodyWhoSamplerBuilder` e si passa a `set_sampler_config()`;
- il sampler va configurato **dopo** `start_worker()`: a worker fermo l'addon
  lo scarta con un warning e usa i suoi default. `_apply_sampler()` adesso si
  rifiuta di girare prima dell'avvio, cosi' un riordino futuro rompe il test
  invece delle risposte.

### Il seed fisso (la trappola meno visibile)

Se non glielo si dice, l'addon usa **seed 1234**, sempre. Il ramo locale era
quindi completamente deterministico: lo stesso NPC, alla stessa domanda,
ripeteva la battuta parola per parola anche in partite diverse, e un
indovinello che usciva senza la riga `ANSWER:` usciva senza quella riga per
sempre — `parse_riddle_response()` tornava `null` e il giocatore vedeva un
indovinello di `RIDDLE_FALLBACKS` **con il modello acceso e funzionante**. Era
riproducibile: `local_check` falliva l'indovinello di `door_entrance` a ogni
esecuzione.

`llama_cpp`, in `inference.py`, usava il proprio default (seed casuale).
`_apply_sampler()` adesso ne riceve uno nuovo a ogni generazione: le risposte
tornano a variare, e un secondo tentativo ha senso perche' esplora un'uscita
diversa invece di ricalcolare la stessa.

In piu' `say()` e' deprecato in favore di `ask()` (proviamo prima `ask`), e
`setup()` aspetta il segnale `worker_started`: il `.gguf` viene caricato in un
thread dell'addon, quindi senza quell'attesa dichiareremmo il backend pronto
mentre llama.cpp sta ancora leggendo — o ha gia' fallito.

### Dov'e' il modello

`llama.cpp` vuole un file vero sul filesystem: **un `.gguf` dentro il `.pck`
non e' leggibile**. `_resolve_model_path()` cerca, in ordine:

1. `$ORACULUS_MODEL_PATH`;
2. `user://models/<nome>.gguf` (copia gia' estratta);
3. `<cartella dell'eseguibile>/models/<nome>.gguf`, oppure la cartella di
   progetto quando si gira dall'editor;
4. `res://models/<nome>.gguf` dentro il `.pck` — in questo caso viene copiato
   una volta in `user://models/` e si usa quello.

Oggi in `models/` c'e' `Llama-3.2-1B-Instruct-Q6_K_L.gguf` (1,08 GB), che e'
il percorso 3 quando si gira dall'editor: la cartella e' in `.gitignore`, va
copiata a mano su una macchina nuova.

Il percorso 4 funziona ma costa 1 GB nel `.pck` **piu'** 1 GB in `user://`.
Per gli export conviene togliere `models/*.gguf` da `include_filter` in
`export_presets.cfg` e spedire il `.gguf` accanto all'eseguibile (percorso 3).
`ai/*.py` e' gia' stato tolto dal filtro: il gioco non lancia piu' Python.

## Quando un NPC interpella il modello

Tre momenti, e solo quelli:

| Momento | Da dove parte |
| --- | --- |
| caricamento della scena | `say_launch_message()` / `_on_server_started()` |
| l'NPC viene colpito | `take_damage()` → `_react_to_hit()` |
| il giocatore gli scrive | `receive_player_answer()` |

I primi due sono battute ambientali: se il modello e' gia' al lavoro non
aspettano e usano `FALLBACK` (vedi "La coda al caricamento della scena").

**Entrare nell'area non genera piu' nulla.** Prima ne generava due volte:

- `_on_body_entered()` faceva partire una battuta appena il giocatore entrava
  nel raggio di rilevamento (sei NPC su nove: `ask_riddle()` per demon,
  falciatore, gorgon e wizard; un ringhio a vista per ogre e skeletons);
- peggio, `_process()` chiamava `execute_ai_decision()` ogni
  `ai_update_interval` secondi **finche' il giocatore restava a portata**, e il
  ramo `"talk"` generava. Era la fonte principale: un NPC vicino produceva una
  richiesta ogni pochi secondi, per sempre, e con piu' NPC nella stanza si
  sommavano.

Essere colpiti, invece, prima **non** generava: mostrava una battuta presa da
`aggressive_hit_responses`. Ora passa dal modello, e quella lista resta come
ripiego — serve anche a bocce ferme, perche' `_react_to_hit()` non parte se una
richiesta e' gia' in volo (`is_waiting_for_response`): una raffica di colpi non
accoda una raffica di generazioni, ma una reazione si vede sempre.

Due dettagli che valgono la pena:

- `_on_body_entered()` non mette piu' lo stato a `"riddle"`. Quello stato non
  era fra quelli che `receive_player_answer()` accetta, quindi se la
  generazione non arrivava l'NPC restava muto **e sordo**;
- `receive_player_answer()` ora accetta anche lo stato `"idle"`. Lo stato
  passava a `"ready"` solo quando tornava una battuta generata: un NPC che non
  aveva ancora parlato (server lento, messaggio di caricamento fallito) non
  sentiva il giocatore. Farsi scrivere deve funzionare sempre.

`ask_riddle()`, `initiate_random_dialogue()` e `share_castle_knowledge()`
restano definite ma non sono collegate a niente: sono il testo dei prompt, se
un giorno si vuole rimettere il dialogo ambientale dietro a un innesco
esplicito (un tasto "parla").

La regola e' verificata da un controllo statico:

```
python3 tools/check_npc_triggers.py
```

Non cerca le stringhe: costruisce il grafo delle chiamate di ogni file e
verifica che da `_on_body_entered` e dal ciclo periodico non si arrivi a una
generazione **per nessun cammino**, e che i tre inneschi previsti ci arrivino.
Cosi' una funzione scollegata che contiene ancora i prompt non conta come
violazione, mentre una riconnessa domani viene segnalata con il cammino
esatto (`demon.gd: _on_body_entered -> ask_riddle`).

## La lingua degli spiriti

La tendina in alto a destra nel menu (`LanguageSelect` in `menu.tscn`) sceglie
la lingua in cui gli NPC rispondono: **EN, IT, FR, ES, DE** — le cinque chiavi
di `LANG_SIGNATURES`. La sigla e' solo per il menu; quello che viaggia fino al
prompt e' il nome esteso (`"italiano"`, ...), perche' e' la stringa che finisce
in `Always speak in <lingua>`.

La scelta vive in `GameState.ai_language`, si salva in `user://settings.cfg` e
sopravvive al cambio scena e alla chiusura del gioco. Prima ogni NPC aveva
`"language": "inglese"` scritto nel payload: quei dieci punti (nove NPC piu'
`door.gd`) ora leggono `GameState.ai_language`.

Cambiare lingua a partita in corso **azzera la memoria degli NPC**
(`AIServerManager._on_language_changed`): lo storico e' nella lingua di prima,
e il modello tende a proseguire in quella.

### Perche' non basta dirlo nelle RULES

La regola 1 diceva gia' `Always speak in <lingua>`, e non funzionava: e'
scritta in inglese, in cima a 9 KB di contesto anch'esso in inglese, e **il
modello segue la lingua della domanda**. Con la tendina su IT e la domanda
"Who guards this place?", la risposta arrivava in inglese. Verificato su
entrambi i rami, 1B locale e 8B remoto.

Servono due cose, entrambe in `build_system_msg()` / `decorate_user_msg()`:

- una riga finale **nella lingua richiesta** (`LANG_DIRECTIVE`: "Rispondi in
  italiano.", "Réponds en français.", ...). In inglese non basta;
- la stessa riga in coda al **turno del giocatore**, che e' l'ultima cosa che
  il modello legge prima di rispondere. E' la posizione decisiva: senza,
  l'8B remoto continuava a rispondere in inglese a tutte e cinque le lingue.

### Quanto regge, in pratica

| | dialoghi | indovinelli |
| --- | --- | --- |
| remoto, Llama-3.1-8B | tutte e 5 | tutte e 5 |
| locale, Llama-3.2-1B | tutte e 5 | EN e IT buoni; FR/ES/DE incerti |

Il ramo remoto e' affidabile in tutte e cinque. Il 1B locale ormai risponde
nella lingua giusta, ma sugli indovinelli non inglesi produce a volte parole
inventate come risposta — e la risposta e' quella che il giocatore deve
digitare per aprire la porta. E' il tetto di un modello da 1 miliardo di
parametri, non un problema di prompt: la posizione piu' forte e' gia' usata.
Se serve il multilingua affidabile offline, la strada e' un `.gguf` piu'
grande in `models/`, non un prompt diverso.

`RIDDLE_FALLBACKS` ha voci solo per `inglese` e `italiano`: nelle altre lingue
il ripiego e' in inglese.

## Velocita' delle risposte

`inference.py` passava `max_tokens` a `llama_cpp`; il ramo locale in GDScript
aveva perso quel limite, e **NobodyWho non ha un'opzione equivalente**. Il
modello tirava dritto fino all'EOS: misurato **4702 caratteri in 11,7 s**, di
cui `pulisci()` ne teneva 240. Il resto era tempo buttato.

Il limite si applica ora in streaming: `response_updated` emette un token per
evento, `oraculus_backend_local.gd` li conta e ferma il worker al budget
(`MAX_TOKENS` per i dialoghi, `RIDDLE_MAX_TOKENS` per gli indovinelli — gli
stessi numeri del Python).

| | prima | dopo |
| --- | --- | --- |
| domanda che fa divagare il modello | 11 737 ms | 1 787 ms |
| media su quattro domande | — | **1 574 ms** |
| indovinello | — | ~1 300 ms |

Un dettaglio che costa caro se lo si sbaglia: dopo `stop_generation()` bisogna
**aspettare comunque `response_finished`**. Lasciarlo pendente lo fa arrivare
durante la richiesta successiva, che si chiude all'istante con il testo di
quella prima — misurato: 14 ms e la risposta sbagliata. Il ciclo di attesa lo
drena con una finestra breve (`STOP_GRACE`).

Per confronto, il ramo remoto sta sui **2,5-2,9 s** a richiesta (rete piu'
latenza HF), piu' il risveglio di Render se il servizio era fermo. Il ramo
locale e' ora il piu' veloce dei due.

### La coda al caricamento della scena

Il tempo per battuta non era il problema piu' grosso. Al caricamento di
`main.tscn` **ogni NPC chiede la sua presentazione al modello**, e gli NPC sono
~40 (16 orchi, 14 fantasmi, 4 scheletri, piu' i personaggi): 40 generazioni in
fila sull'unico worker locale. Nel log di gioco vanno dalle 12:52:37 alle
12:53:24, **~47 s**, e la prima frase del giocatore a Levias e' partita solo
dopo. Sul ramo remoto sarebbero 40 richieste insieme al proxy su Render.

Ora una battuta **ambientale** — senza frase del cavaliere: la presentazione e
la reazione a un colpo — non si mette in coda: se una generazione e' gia' in
corso (`OraculusEngine._in_volo`, dialoghi e indovinelli), l'NPC riceve subito
una battuta di `FALLBACK` e la risposta ha `"source": "occupato"`. La frase del
giocatore invece va sempre al modello, e aspetta al massimo la generazione in
corso.

Simulato con 40 presentazioni insieme e poi "thanks" a Levias, 1B locale:
39 presentazioni ripiegano subito, 1 va al modello, e il giocatore legge la
risposta completa a **~3,2 s** (prima: ~47 s di coda piu' la sua). Senza coda
la risposta resta sul secondo e mezzo.

### Dove va il tempo di una battuta

Quel che resta del secondo e' diviso fra ~850 ms per rileggere gli 11 KB di
system prompt a ogni richiesta e ~500 ms di generazione vera. Il prompt si
rilegge perche' `reset_context()` butta la cache, e si deve buttare perche'
`_mood_line()` scrive l'ostilita' esatta nel prompt, che cambia a ogni turno.
Chi volesse scendere sotto il secondo deve partire da li'.

## Streaming delle risposte

Lo streaming non accorcia la risposta, accorcia l'attesa: l'NPC mostra le
prime parole appena il modello le scrive, al posto dei puntini, e la battuta
cresce sotto gli occhi del giocatore. Col proxy su Render la risposta
intera arriva in 3-4 s; con lo streaming si comincia a leggere al primo
token. Quanto presto arrivi dipende dal provider HF: va misurato dopo il
deploy (`stream_check` stampa i tempi).

Il percorso:

| Livello | Cosa fa |
| --- | --- |
| `ai_server.py` | Con `"stream": true` su `/v1/chat/completions` risponde in Server-Sent Events, nel formato di OpenAI (`choices[0].delta.content`, poi `data: [DONE]`). |
| `inference.py` | `raw_chat_stream()`: un generatore di frammenti, dal router HF o da `llama_cpp`. |
| `oraculus_backend_remote.gd` | `chat_completion_stream()`: legge il flusso a pezzi con `HTTPClient` su desktop e con `fetch()` + `ReadableStream` su Web. |
| `oraculus_backend_local.gd` | `generate(..., on_text)`: NobodyWho emetteva gia' un token per evento, per contarli. |
| `oraculus_engine.gd` | Passa il testo da `pulisci_parziale()` + `enforce_army_name()`, e lo inoltra solo quando cambia. |
| `AIServerManager.gd` | `make_request("chat", payload, on_partial)`. Il terzo argomento e' opzionale: senza, niente streaming. |
| NPC e menu | `_show_partial()` ferma i puntini e scrive la battuta parziale. Quella definitiva arriva come prima. |

Cose da sapere:

- **Il testo finale puo' cambiare di poco nella coda.** Durante lo streaming
  si mostra `pulisci_parziale()`, che toglie le stesse cose di `pulisci()` ma
  non chiude la frase; alla fine `pulisci()` sul testo intero aggiunge il
  punto o taglia all'ultima punteggiatura. Mostrare il punto a meta' lo
  farebbe comparire e sparire a ogni token.
- **Cio' che `pulisci()` togliera' non compare mai.** Un prefisso ancora a
  meta' ("Lev" di "Levias:") o una parentesi / un `<|` non ancora chiusi
  vengono trattenuti finche' non si sa come finiscono.
- **Gli indovinelli non vanno in streaming**: servono interi per estrarre la
  riga `ANSWER:`, e senza quella la porta non si apre.
- **Il proxy va ridistribuito** (`ai_server.py` e `inference.py`). Finche' non
  lo e', il client riceve il JSON di sempre e lo legge come prima, senza
  parziali: niente si rompe. Il deploy nuovo si riconosce da `"stream": true`
  in `/health`.
- In `ai_server.py` il primo frammento si chiede **prima** di mandare gli
  header: se il provider rifiuta la richiesta (modello ritirato, credito
  finito) l'errore torna come JSON con il suo codice, come senza streaming.
- Il flusso si chiude con `Connection: close`, senza `Content-Length`. Senza
  quell'header `HTTPClient` di Godot presume keep-alive e tratta la risposta
  come **priva di corpo** — verificato, era il primo fallimento del test.
- Ogni flusso remoto usa un `InferenceClient` suo, chiuso a fine risposta:
  quello condiviso tiene aperta ogni risposta nel suo `ExitStack`, e un flusso
  interrotto (il giocatore cambia scena) non restituirebbe mai la connessione.
- In locale il guadagno e' piccolo: il primo testo arriva dopo ~900 ms su
  ~1000, perche' quasi tutto il tempo e' la rilettura del system prompt, non
  la generazione.

## Battute in personaggio

Ogni NPC deve rispondere come il suo `personalita` in `NPC_DATA`, e al
giocatore non deve arrivare niente del modello: ne' il prompt ripetuto, ne'
l'assistente che rifiuta o commenta. Succedeva, per tre cause diverse.

**1. Le istruzioni di regia arrivavano come frasi del cavaliere.** Gli
script mandavano "Announce presence in ONE short sentence (max 10 words)" o
"The knight just struck you. Snarl ONE short furious line" come
`player_input`. Il modello le leggeva come dette dal cavaliere: ci rispondeva
("Grazie per il messaggio!"), le ripeteva ("devi rispondere con 12 parole o
meno"), e finivano nella memoria dell'NPC come battute del giocatore. Ora
viaggiano in un campo a parte:

```gdscript
_send_to_ai_server("", "The knight just struck you. Snarl ONE short furious line (max 10 words).")
_send_to_ai_server(answer, "Respond with ONE short angry growl (max 8 words).")  # ogre, skeletons
```

`direction` arriva al modello come nota fra parentesi quadre dentro il turno
(`build_direction_msg()`), non entra nella memoria, non passa da intent e
sblocco di Malakai, e non cambia l'ostilita'. Misurato sul 1B, 24 generazioni
per variante: come nota nel turno **0** uscite fuori personaggio; nel system
prompt il modello rifiutava spesso ("Non posso fornire una risposta che
contenga contenuti espliciti"), quindi e' stata scartata.

**2. `pulisci()` non vede le frasi da assistente.** Toglie prefissi e righe
sporche, non frasi come "Mi dispiace, ma non posso continuare la storia" o
"Posso aiutarti con qualcos'altro?". `filtra_fuori_personaggio()` le toglie
frase per frase, prima e dopo `pulisci()` (che resta identica al Python), con
regole strette: "Mi dispiace, ma non posso aiutarti, cavaliere" detto da un
NPC ostile resta. Se non rimane niente la battuta si rifa' una volta
(`CHAT_ATTEMPTS`), poi si ripiega su `FALLBACK`. In streaming un rifiuto a
meta' non compare: le frasi che cominciano come quelle da assistente si
mostrano solo finite.

**3. Il modello da 1B non regge l'italiano con questo prompt.** E' la causa
piu' grossa, e nessun filtro la chiude davvero: il 1B inventa ogni volta una
forma nuova di rifiuto ("non posso continuare a giocare", "sono stato
tradotto in italiano", "personaggi di fumetti"). Misurato su 27 generazioni
(6 domande e 3 regie, NPC diversi), con un rilevatore indipendente dal filtro:

| Modello locale | Battute sospette in italiano | in inglese | Primo testo | Risposta completa |
| --- | --- | --- | --- | --- |
| Llama-3.2-1B Q6_K_L (1,08 GB) | 12/27 | 1/27 | ~1,0 s | ~1,3 s |
| Llama-3.2-3B Q4_K_M (2,02 GB) | 0/27 (1 falso allarme) | — | ~2,0 s | ~2,6 s |

Tempi su RTX 3050 6 GB, tutti i layer in GPU. Il 1B in inglese regge: e' la
combinazione di 11 KB di contesto in inglese con la risposta in italiano che
lo manda in modalita' assistente. Una cornice di finzione nel prompt ("stai
dando voce a un personaggio di un videogioco") e' stata provata e aiuta poco
(12/27 -> 9/27): non e' stata adottata.

Il 3B si prova senza toccare niente:
`ORACULUS_MODEL_PATH=/percorso/Llama-3.2-3B-Instruct-Q4_K_M.gguf`. Per
adottarlo: `MODEL_PATH` in `inference.py`, poi `python3 tools/gen_oraculus_data.py`.

**4. Il turno del giocatore sembrava una richiesta all'assistente.** Il
giocatore scrive "thanks" a Levias, e al giocatore arriva: "I cannot fulfill
your request. I am just an AI model, it is not within my programming or
ethical guidelines to describe scene involving romantic relationship between
adult and minor." Il turno arrivava nudo ("thanks\n\nAnswer in English."), e
il 1B lo leggeva come un messaggio rivolto a lui. Ora `decorate_user_msg()` lo
scrive con la stessa cornice delle note di regia, che non uscivano mai fuori
personaggio:

```
The knight says: "thanks"
Reply with Levias's spoken words only, in character.

Answer in English.
```

Misurato sul 1B, Levias e Rigon, 7 domande ("thanks", "grazie", "Chi sei?",
"What did you do to the children?", ...) × 3 generazioni, rilevatore
indipendente dal filtro, falsi allarmi ricontrollati a mano:

| Turno del giocatore | Battute da assistente | Tempo medio |
| --- | --- | --- |
| nudo (prima) | 27/42 | ~1,6 s |
| battuta citata (ora) | 3/42 | ~1,7 s |

Anche i turni di storico del ramo remoto passano da `knight_line()`, per non
mescolare due formati nella stessa conversazione. Con la cornice nuova il 1B
risponde quasi sempre fra virgolette: `_ripulisci_segni()` toglie quelle che
racchiudono l'intera battuta.

Le 3 rimaste le prende il filtro: `FUORI_PERSONAGGIO` ha ora le forme del
rifiuto di sicurezza dei Llama uscite nelle misure ("I cannot fulfill your
request", "I can't help you with that", "content that promotes...", "Is there
anything else I can help you with?", "linee guida", ...), e confronta le frasi
con l'apostrofo dritto: il 1B scrive spesso `can’t`, e le regole non lo
vedevano. `persona_check` le verifica una per una in `RIFIUTI_MISURATI`, e
pretende che spariscano per intero.

Provate e scartate, perche' le misure non le sostengono:

- **Doppio BOS.** Il log di llama.cpp avvisa `check_double_bos_eos: ... the
  final prompt starts with 2 BOS tokens`: il template di Llama 3.2 comincia con
  `{{- bos_token }}` e il `.gguf` non ha `tokenizer.ggml.add_bos_token`, quindi
  NobodyWho ne aggiunge un secondo. Una copia del modello con il flag a
  `false` toglie l'avviso ma non i rifiuti (39 contro 31 su 63, nel rumore).
  L'avviso si puo' ignorare.
- **Personaggio di Rigon riscritto** senza l'abuso esplicito: stessi rifiuti
  (1 e 2 su 32, con la cornice nuova).
- **"You REFUSE to share what you know" ammorbidito**: nessun guadagno sopra la
  cornice. Con in piu' lo `STORY_CONTEXT` spostato dopo il personaggio i
  rifiuti sono scesi a 0/42, ma e' stata la variante piu' lenta (~2,2 s contro
  ~1,7 s a battuta) e le 3 che restano senza la prende gia' il filtro.

## La guida del menu

Il menu risponde alle domande del giocatore su lore, comandi, obiettivi,
struttura del castello e cosa fare. Prima era il personaggio `Tutorial`
attraverso il modello: lento (tutto `STORY_CONTEXT` a ogni domanda), con i
comandi sbagliati nel prompt ("sprint with Shift or LT", ma e' LB), con
l'ostilita' di default a 70 (il menu non la passava), che nel prompt gli
diceva di non rivelare quello che sa, e con il filtro delle battute fuori
personaggio che avrebbe tolto proprio le frasi da guida ("come giocare",
"nuova partita").

Ora `oraculus_guide.gd` ha una trentina di **schede scritte a mano**, in tutte
e cinque le lingue del menu, scelte dalle parole chiave della domanda (in
qualunque lingua sia scritta): risposta in meno di un millisecondo, anche
prima che il modello finisca di caricarsi. Se nessuna scheda corrisponde, il
menu lo dice ed elenca cosa si puo' chiedere. Le schede non svelano i segreti
del castello: quelli restano agli spiriti.

**Il modello qui non c'e', di proposito.** Misurato sul 1B locale:

| Ruolo del modello | Risultato |
| --- | --- |
| rispondere con le schede come unici fatti | inventa quasi sempre ("il gioco dura circa 6-8 ore", "yes, there is a final boss"); ~1,9 s |
| solo scegliere la scheda giusta (id in italiano) | 3/24 giuste, ~0,3 s |
| id in inglese | 2/24 |
| id in inglese + esempi nel prompt | 4/24 |
| parole chiave, nessun modello | 24/24 sulle stesse domande; 32/40 su 40 domande nuove prima di ritoccare le chiavi |

Una risposta sbagliata detta con sicurezza e' peggio di un "non lo so" che
elenca cosa chiedere. Con un modello piu' grande (il 3B, o l'8B remoto) la
scelta della scheda potrebbe tornare utile: va rimisurata prima.

Per aggiungere o correggere una risposta basta modificare `SCHEDE` e rilanciare
`guide_check`: il test controlla le cinque lingue, i caratteri e che le
domande note trovino ancora la scheda giusta.

## Quale ramo: la gara

All'avvio `OraculusEngine.setup()` fa partire insieme i due rami, ciascuno
con una generazione vera e minima: il locale carica il modello e genera una
parola, il remoto chiede 4 token al proxy (`verifica()`). **Il primo che
risponde diventa il ramo della partita, e l'altro viene chiuso**: il modello
locale liberato da RAM e VRAM (a caricamento finito, se era ancora a meta'),
oppure il remoto che non riceve piu' richieste.

Un errore non e' una risposta: 402 (credito HF finito), 404, 500, rete giu',
10 s senza risposta (`REMOTE_RACE_TIMEOUT`) fanno vincere il locale. Per
questo la prova e' una generazione e non `/health`, che risponde `"ok"`
anche a credito finito.

| Situazione | Vince | Pronto in |
| --- | --- | --- |
| proxy sveglio, credito ok | testa a testa: il primo token via HF e' arrivato in ~1 s nelle misure, il 1B e' pronto in ~0,9 s | ~1 s |
| credito HF finito (402) | locale | ~0,9 s |
| proxy irraggiungibile | locale | ~0,9 s |
| Render in sleep | locale (il remoto ci mette 30-60 s a svegliarsi) | ~0,9 s |
| Web | remoto, l'unico che c'e' | — |

Misurato sul PC di sviluppo. Il caso "credito ok" non si e' potuto provare
dal vivo (credito finito): con il proxy finto, che risponde in 22 ms, vince
sempre il remoto; con quello vero i due tempi sono vicini, quindi il ramo
puo' cambiare da un avvio all'altro.

Se non risponde nessuno si tiene il remoto non verificato, come prima: le
richieste falliscono una per una con le battute di `FALLBACK`.

La scelta non si rifa' durante la partita: se il ramo vincente smette di
rispondere dopo (Render che torna in sleep dopo 15 minuti senza richieste, il
credito che finisce a meta'), gli NPC ripiegano su `FALLBACK` fino al
prossimo avvio.

`ORACULUS_BACKEND=locale` o `=remoto` salta la gara e usa quel ramo: serve ai
collaudi che vogliono esercitarne uno preciso.

## Inferenza remota

`oraculus_backend_remote.gd` fa un POST su
`https://oraculus-ai-api.onrender.com/v1/chat/completions` (sovrascrivibile
con la variabile d'ambiente `ORACULUS_API_URL`). E' un endpoint compatibile
OpenAI, senza logica di gioco: prompt, memoria, intent e pulizia sono tutti
lato Godot.

**Il proxy va ridistribuito** perche' quell'endpoint esista: e' stato aggiunto
in `ai_server.py` in questo cambiamento. Le rotte vecchie (`/chat`, `/riddle`,
`/reset`, `/set_context`, `/health`) sono intatte, quindi il deploy attuale
continua a funzionare per qualunque client vecchio.

Il proxy serve anche a qualcosa che non e' pigrizia: tiene `HF_TOKEN` lato
server. Messo nel client sarebbe estraibile dal `.pck`.

### Quale modello usa il proxy

Hugging Face ha smesso di servire `meta-llama/Llama-3.2-1B-Instruct` (il
gemello del `.gguf` locale) e `Qwen/Qwen2.5-7B-Instruct`, i due candidati che
`inference.py` aveva cablati. Il router rispondeva:

```
The requested model '...' is not supported by any provider you have enabled.
```

Il risultato era silenzioso e fuorviante: `/health` diceva `"status": "ok"`
(il processo HTTP era vivo), ma ogni POST su `/v1/chat/completions` tornava
**503**, quindi `chat_completion()` in GDScript restituiva `""` e il motore
ripiegava su `FALLBACK` — dialoghi di riserva con il server "acceso".

Ora i candidati sono modelli vivi sul router, e quando finiscono **il proxy
chiede al router quali modelli sta servendo adesso** e prova quelli
(`discover_router_models()`, solo `urllib`, nessuna dipendenza in piu'). Cosi'
il prossimo modello ritirato non spegne di nuovo i dialoghi.

I modelli scoperti vengono ordinati: prima quelli istruiti (a un modello base
il formato `RIDDLE:`/`ANSWER:` non lo strappi), poi i piu' piccoli (le battute
sono di 80 token e il giocatore aspetta davanti alla casella di dialogo);
`coder`, `thinking`, `guard`, `vl` restano in fondo — scrivono codice, o
antepongono il ragionamento alla risposta, che `pulisci()` poi taglia a meta'.

Le variabili d'ambiente, tutte opzionali tranne la prima:

| Variabile | Default | A cosa serve |
| --- | --- | --- |
| `HF_TOKEN` | — | **Obbligatoria.** Senza, il proxy non ha inferenza. |
| `HF_MODEL` | `meta-llama/Llama-3.1-8B-Instruct` | Primo candidato. |
| `HF_MODEL_FALLBACKS` | tre modelli, separati da virgola | Candidati successivi. |
| `HF_AUTODISCOVER` | `1` | `0` disattiva la scoperta dal router. |
| `HF_DISCOVER_LIMIT` | `6` | Quanti modelli scoperti provare. |
| `HF_PROVIDER` | `auto` | Provider di inferenza HF. |
| `HF_RETRY_COOLDOWN` | `60` | Secondi fra due tentativi di ricaricamento. |
| `RIDDLE_ATTEMPTS` | `3` | Tentativi prima di `RIDDLE_FALLBACKS`. |

Nota sui costi: HF non ha piu' un piano di inferenza gratuito illimitato
(nella lista del router non c'e' piu' nessun modello con `is_free: true`), per
cui il token deve appartenere a un account con credito. Se il credito finisce,
`/health` lo dice in `last_error` e il gioco continua con i fallback.

### Cosa serve nel `requirements.txt`

Una sola riga: `huggingface_hub>=0.34,<2`.

Tutto il resto del proxy e' libreria standard — `http.server` per il server,
`json`, `urllib` per la scoperta dei modelli. Il limite inferiore serve perche'
`inference.py` passa `provider=` a `InferenceClient` (esiste dalla 0.28); il
limite superiore evita che una major non annunciata rompa il deploy senza che
nessuno abbia toccato il codice — la 1.0 ha gia' cambiato il motore HTTP da
`requests` a `httpx`. Verificato con la 1.31.0.

**`llama-cpp-python` non va nel `requirements.txt` di Render**: su Render non
c'e' il `.gguf` da 1 GB e la compilazione farebbe fallire la build. Sta in
`requirements-local.txt`, che serve solo a far girare `inference.py` con il
modello sul proprio PC — cosa che il gioco non fa piu' comunque.

## Export Web

Le GDExtension native non girano in wasm, quindi su Web il ramo locale non
esiste e resta necessario quello remoto. `oraculus_backend_remote.gd` su Web
passa da `fetch()` via `JavaScriptBridge` invece di `HTTPRequest`, per via del
CORS. In pratica: nativo su desktop, remoto su web.

## Differenze deliberate rispetto a `inference.py`

Sono due, entrambe documentate anche nel codice.

**`hash()`.** In Python l'hash delle stringhe e' randomizzato a ogni processo,
quindi lo stesso `door_id` dava un indovinello di riserva diverso a ogni
riavvio. `String.hash()` in Godot e' deterministico. Per non perdere la
varieta' la chiave e' `door_id + session_id`: `GameState.session_id` cambia a
ogni partita, quindi gli indovinelli variano come prima, ma in modo
riproducibile a sessione fissa. Lo stesso vale per la scelta del tema, dove
Python usava `hash(door_id)` da solo.

**Il template del prompt locale.** NobodyWho applica da se' il template della
chat del modello e non permette di iniettare turni dell'assistente, quindi il
ramo locale usa `build_system_msg()` piu' il blocco di storico e lascia i
token all'addon, invece del prompt grezzo `<|start_header_id|>...` costruito a
mano da `build_prompt()`. Il modello e' lo stesso (Llama-3.2-1B-Instruct) e il
template che NobodyWho applica e' quello, ma i token non sono garantiti
identici byte per byte. `build_prompt()` resta portato e verificato, pronto se
un giorno il backend esporra' il completamento grezzo.

## Cosa e' rimasto indietro, di proposito

- `python_venv/` (1007 file, 159 MB) e' stato tolto dall'indice git
  (`git rm -r --cached`) e aggiunto al `.gitignore`: i file restano sul disco,
  ma dal prossimo commit il repo non li porta piu'. Cancellarli e' sicuro.
- `ai/tinyllama-v0.q2_k.gguf` (5 MB) non e' usato da nessuno.
- `door2.gd`, `door3.gd`, `door4.gd` non compilano: fanno riferimento a un tipo
  `Player2AINPC` che non esiste in nessun file. E' cosi' dal primo commit e non
  ha niente a che vedere con questo cambiamento.
